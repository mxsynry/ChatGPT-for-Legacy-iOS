import Foundation

// User-directed import of their own ChatGPT data export's conversations.json.
// No ChatGPT session cookie, private endpoint or account token is consumed here.
enum HistoryImportError: LocalizedError {
    case tooLarge, invalidFormat, noConversations
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "The file exceeds the 64 MB import limit. Split the export on a computer first."
        case .invalidFormat: return "Select the conversations.json file from your ChatGPT data export."
        case .noConversations: return "No supported text conversations were found in the file."
        }
    }
}

struct ImportedChatRecord {
    let sourceID: String
    let title: String
    let messages: [ChatMessage]
    let updatedAt: Date
}

enum ChatGPTHistoryImporter {
    static let maxBytes = 64 * 1024 * 1024
    static func parse(_ data: Data) throws -> [ImportedChatRecord] {
        guard data.count <= maxBytes else { throw HistoryImportError.tooLarge }
        guard let conversations = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw HistoryImportError.invalidFormat
        }
        var records = [ImportedChatRecord]()
        for item in conversations.prefix(10000) {
            guard let mapping = item["mapping"] as? [String: [String: Any]] else { continue }
            let rawID = item["id"] as? String ?? ""
            guard !rawID.isEmpty else { continue }
            let title = (item["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Imported conversation"
            let lastModified = (item["update_time"] as? NSNumber)?.doubleValue
                ?? (item["create_time"] as? NSNumber)?.doubleValue ?? 0
            let updatedAt = lastModified > 0 ? Date(timeIntervalSince1970: lastModified) : Date()

            // Follow the selected conversation branch, not every alternate edit/regeneration.
            var nodes: [[String: Any]] = []
            if let tail = item["current_node"] as? String, !tail.isEmpty, mapping[tail] != nil {
                var current: String? = tail
                var seen = Set<String>()
                while let key = current, !seen.contains(key), let node = mapping[key], nodes.count < 20000 {
                    seen.insert(key)
                    nodes.append(node)
                    current = node["parent"] as? String
                }
                nodes.reverse()
            } else {
                // Older exports may omit current_node; show the chronological textual path.
                nodes = mapping.values.sorted {
                    timestamp($0) < timestamp($1)
                }
            }
            var messages = [ChatMessage]()
            for node in nodes {
                guard let message = node["message"] as? [String: Any],
                      let author = message["author"] as? [String: Any],
                      let role = author["role"] as? String,
                      role == "user" || role == "assistant",
                      let content = message["content"] as? [String: Any] else { continue }
                let parts = content["parts"] as? [Any] ?? []
                let text = parts.compactMap { $0 as? String }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                messages.append(ChatMessage(role: role, text: String(text.prefix(200000))))
            }
            guard !messages.isEmpty else { continue }
            records.append(ImportedChatRecord(sourceID: rawID,
                                              title: String(title.prefix(100)),
                                              messages: messages,
                                              updatedAt: updatedAt))
        }
        guard !records.isEmpty else { throw HistoryImportError.noConversations }
        return records
    }
    private static func timestamp(_ node: [String: Any]) -> Double {
        guard let message = node["message"] as? [String: Any] else { return 0 }
        return (message["create_time"] as? NSNumber)?.doubleValue ?? 0
    }
}
