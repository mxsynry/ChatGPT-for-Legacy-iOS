import Foundation

enum CitationURLPolicy {
    static func allow(_ url: URLComponents) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              let host = url.host?.lowercased(), !host.isEmpty, host.count < 254 else { return false }
        let blocked = ["localhost", "localhost.localdomain", "metadata.google.internal"]
        if blocked.contains(host) || host.hasSuffix(".localhost") || host.hasSuffix(".local") ||
           host.hasSuffix(".internal") || host.hasSuffix(".lan") { return false }
        if host.contains(":") { return false } // IPv6 literals are not needed for citations.
        let pieces = host.split(separator: ".")
        if pieces.count == 4, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isNumber }) }) {
            guard let o = Int(pieces[0]), let n = Int(pieces[1]),
                  pieces.allSatisfy({ Int($0) != nil && Int($0)! <= 255 }) else { return false }
            if o == 0 || o == 10 || o == 127 || o >= 224 ||
               (o == 100 && (64...127).contains(n)) ||
               (o == 169 && n == 254) ||
               (o == 172 && (16...31).contains(n)) ||
               (o == 192 && (n == 0 || n == 168)) ||
               (o == 198 && (n == 18 || n == 19)) { return false }
            // Reject all raw IP links; authenticated web citation previews
            // should navigate to named HTTPS public hosts only.
            return false
        }
        return host.contains(".") && !host.hasSuffix(".")
    }
}
