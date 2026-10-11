import Foundation

/// Strict inbound HTTP validation for the iOS 16 loopback listener. The caller
/// still checks the unpredictable OAuth `state` with OAuthCallbackSafety.
/// This code is portable and tested independently of Network.framework.
enum OAuthLoopbackHTTP {
    static func callbackURL(requestText: String, port: UInt16) -> URL? {
        guard requestText.utf8.count <= 16384,
              let headerEnd = requestText.range(of: "\r\n\r\n") else { return nil }
        let header = requestText[..<headerEnd.lowerBound]
        let lines = header.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let pieces = first.split(separator: " ", omittingEmptySubsequences: false)
        guard pieces.count == 3, pieces[0] == "GET",
              pieces[2] == "HTTP/1.1" || pieces[2] == "HTTP/1.0" else { return nil }
        let hostHeaders = lines.dropFirst().compactMap { line -> String? in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            guard line[..<colon].lowercased() == "host" else { return nil }
            return String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        guard hostHeaders.count == 1,
              hostHeaders[0] == "127.0.0.1:\(port)" else { return nil }
        let requestTarget = String(pieces[1])
        guard requestTarget.hasPrefix("/auth/callback?"),
              !requestTarget.contains("#"), !requestTarget.contains("\\"),
              requestTarget.utf8.count <= 8192,
              let url = URL(string: "http://127.0.0.1:\(port)" + requestTarget),
              url.host == "127.0.0.1", url.port == Int(port),
              url.path == "/auth/callback", url.user == nil, url.password == nil else {
            return nil
        }
        return url
    }
}
