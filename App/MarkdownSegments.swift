import Foundation

/// Small portable parser for fenced code blocks. Narrative text remains
/// Markdown; fenced code is literal, with independent copy and scrolling.
/// This is intentionally not an HTML renderer.
enum MarkdownSegment: Equatable {
    case prose(String)
    case code(language: String, text: String)
}

enum MarkdownSegments {
    static func split(_ text: String) -> [MarkdownSegment] {
        guard !text.isEmpty else { return [] }
        let lines = text.components(separatedBy: "\n")
        var segments = [MarkdownSegment]()
        var buffer = [String]()
        var code = [String]()
        var fence: String?
        var language = ""
        func emitProse() {
            guard !buffer.isEmpty else { return }
            segments.append(.prose(buffer.joined(separator: "\n")))
            buffer.removeAll()
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let opened = fence {
                if trimmed.hasPrefix(opened) && trimmed.dropFirst(opened.count).allSatisfy({ $0 == "`" || $0 == "~" }) {
                    segments.append(.code(language: language, text: code.joined(separator: "\n")))
                    code.removeAll()
                    language = ""
                    fence = nil
                } else { code.append(line) }
            } else if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                // The common Markdown fenced-code form; no indentation-based
                // parser state, so old iPhones avoid heavy Markdown WebViews.
                emitProse()
                let delimiter = trimmed.hasPrefix("```") ? "```" : "~~~"
                language = String(trimmed.dropFirst(3).prefix(32)).trimmingCharacters(in: .whitespaces)
                fence = delimiter
            } else { buffer.append(line) }
        }
        if fence != nil {
            // An incomplete streaming code block stays visibly monospaced.
            segments.append(.code(language: language, text: code.joined(separator: "\n")))
        }
        emitProse()
        return segments
    }
}

/// Reuse parsed immutable Markdown between unrelated SwiftUI state changes.
/// Keep a strict memory budget and clear on app inactivity for local privacy.
private final class MarkdownSegmentsBox: NSObject {
    let value: [MarkdownSegment]
    init(_ value: [MarkdownSegment]) { self.value = value }
}

enum MarkdownRenderCache {
    private static let cache: NSCache<NSString, MarkdownSegmentsBox> = {
        let cache = NSCache<NSString, MarkdownSegmentsBox>()
        cache.countLimit = 64
        cache.totalCostLimit = 6 * 1024 * 1024
        return cache
    }()

    static func split(_ text: String) -> [MarkdownSegment] {
        // Very large replies are parsed once per appearance but not retained.
        guard text.utf8.count <= 180_000 else { return MarkdownSegments.split(text) }
        let key = text as NSString
        if let cached = cache.object(forKey: key) { return cached.value }
        let parsed = MarkdownSegments.split(text)
        cache.setObject(MarkdownSegmentsBox(parsed), forKey: key,
                        cost: min(360_000, text.utf8.count * 2 + parsed.count * 40))
        return parsed
    }
    static func clear() { cache.removeAllObjects() }
}
