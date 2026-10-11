import Foundation

/// Streaming event framing per Server-Sent Events: blank lines terminate
/// events; data fields may occur more than once.  A final unterminated event
/// is flushed at EOF. Keep protocol framing independent of the API parser.
struct SSEFrameCollector {
    private(set) var dataLines: [String] = []
    private var currentBytes = 0
    private var rejected = false
    private var receivedAnyLine = false
    static let maxEventBytes = 2 * 1024 * 1024

    mutating func consume(_ line: String) throws -> String? {
        // URLSession.AsyncBytes.lines strips newlines, including CRLF delimiters.
        var line = line.hasSuffix("\r") ? String(line.dropLast()) : line
        // A UTF-8 BOM is allowed only at the start of an SSE stream.
        if !receivedAnyLine {
            receivedAnyLine = true
            if line.hasPrefix("\u{FEFF}") { line.removeFirst() }
        }
        guard line.utf8.count <= Self.maxEventBytes else { throw SSEFrameError.frameTooLarge }
        if line.isEmpty {
            return takeFrame()
        }
        if line.hasPrefix(":") { return nil } // heartbeat/comment
        // SSE field names are exact: `data` or `data:...`.
        guard line == "data" || line.hasPrefix("data:") else { return nil }
        let field = line == "data" ? "" : String(line.dropFirst(5))
        let content = field.hasPrefix(" ") ? String(field.dropFirst()) : field
        currentBytes += content.utf8.count + 1
        guard currentBytes <= Self.maxEventBytes else {
            rejected = true
            dataLines.removeAll()
            throw SSEFrameError.frameTooLarge
        }
        dataLines.append(content)
        return nil
    }

    mutating func finish() -> String? { takeFrame() }

    private mutating func takeFrame() -> String? {
        guard !rejected, !dataLines.isEmpty else { return nil }
        let frame = dataLines.joined(separator: "\n")
        dataLines.removeAll(keepingCapacity: true)
        currentBytes = 0
        return frame
    }
}

enum SSEFrameError: LocalizedError {
    case frameTooLarge
    var errorDescription: String? { "Server sent an oversized streaming event." }
}
