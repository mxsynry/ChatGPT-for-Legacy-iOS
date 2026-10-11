import Foundation

/// Protects existing user history from being overwritten when decoding fails.
/// This intentionally has no UIKit dependency so its behavior is testable on Linux.
enum ConversationFileRecovery {
    static let maxOnDeviceJSONBytes: Int64 = 96 * 1024 * 1024

    enum Load<Value> {
        case missing
        case loaded(Value)
        case quarantined(recoveryURL: URL, explanation: String)
        case readOnly(explanation: String)
    }

    static func load<Value: Decodable>(_ type: Value.Type,
                                       at fileURL: URL,
                                       decoder: JSONDecoder = JSONDecoder()) -> Load<Value> {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return .missing }
        let data: Data
        do {
            let attributes = try fm.attributesOfItem(atPath: fileURL.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            if size > maxOnDeviceJSONBytes {
                return .readOnly(explanation: "History exceeds the safe loading limit. " +
                    "Existing data was not modified; free memory or export it before retrying.")
            }
            if size == 0 { return quarantine(fileURL, reason: "Saved history file was empty") }
            data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        } catch {
            // Transient iOS file-protection failure is NOT corrupted data.
            // Never rename or replace the original when it cannot be read.
            return .readOnly(explanation: "Saved history could not be read. " +
                "The original is unchanged and local writes have been disabled.")
        }
        do {
            return .loaded(try decoder.decode(type, from: data))
        } catch {
            // Only a successfully read but invalid file is quarantined.
            return quarantine(fileURL, reason: "Saved history could not be decoded")
        }
    }


    /// Keep recovery copies discoverable after subsequent launches. Recovery
    /// must not depend on an in-memory URL from the failure session.
    static func mostRecentRecovery(for fileURL: URL) -> URL? {
        let fm = FileManager.default
        let folder = fileURL.deletingLastPathComponent()
        let prefix = fileURL.lastPathComponent + ".recovery-"

        // Enumerate *names* instead of URL objects with attached resource
        // values; Apple filesystems can represent the same path differently.
        guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else {
            return nil
        }
        var matches: [(url: URL, modified: Date)] = []
        for name in names {
            guard name.hasPrefix(prefix), name.hasSuffix(".json") else { continue }
            let token = String(name.dropFirst(prefix.count).dropLast(5))
            guard UUID(uuidString: token) != nil else { continue }
            let url = folder.appendingPathComponent(name, isDirectory: false)
            guard let attributes = try? fm.attributesOfItem(atPath: url.path),
                  (attributes[.type] as? FileAttributeType) == .typeRegular else { continue }
            let modified = (attributes[.modificationDate] as? Date) ?? .distantPast
            matches.append((url, modified))
        }
        return matches.max {
            $0.modified == $1.modified
              ? $0.url.lastPathComponent < $1.url.lastPathComponent
              : $0.modified < $1.modified
        }?.url
    }

    private static func quarantine<Value>(_ fileURL: URL, reason: String) -> Load<Value> {
        let recoveryURL = fileURL.deletingLastPathComponent().appendingPathComponent(
            fileURL.lastPathComponent + ".recovery-" + UUID().uuidString + ".json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: recoveryURL)
            // The backup belongs to the user; don't sync it into unrelated backups.
            var protectedURL = recoveryURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? protectedURL.setResourceValues(values)
            return .quarantined(recoveryURL: recoveryURL,
                                explanation: reason + ". Original bytes were preserved.")
        } catch {
            // Never write a replacement over the unreadable original.
            return .readOnly(explanation: reason +
                ". Could not preserve the original, so local writes are disabled.")
        }
    }
}
