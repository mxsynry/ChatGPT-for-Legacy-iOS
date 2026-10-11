import Foundation

/// Metadata only. Never retain credentials, request payloads or response text
/// in a diagnostic shown to users or in crash reports.
struct StreamInterruption: LocalizedError, Equatable {
    enum Cause: Equatable { case serverIncomplete, connectionClosed, connectionError }
    let cause: Cause
    let reason: String?
    let requestID: String?
    let eventsReceived: Int
    let receivedText: Bool

    var errorDescription: String? {
        let label: String
        switch cause {
        case .serverIncomplete: label = "The server marked this response incomplete."
        case .connectionClosed: label = "The connection closed before response.completed."
        case .connectionError: label = "The response stream was interrupted."
        }
        let info = reason.map { " Reason: \(String($0.prefix(120)))." } ?? ""
        let partial = receivedText ? " Partial text was retained." : ""
        let request = requestID.map { " Request ID: \($0)" } ?? ""
        return label + info + partial + request
    }
}

/// Use only a Retry-After delay announced by the server. The public Responses
/// API does not guarantee that a new POST will continue an earlier response.
enum RetryAfterPolicy {
    static func deadline(headers: [String: String], now: Date = Date()) -> Date? {
        let fields = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, last in last })
        guard let raw = fields["retry-after"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        if let seconds = TimeInterval(raw), seconds.isFinite,
           seconds >= 0, seconds <= 7 * 24 * 3600 {
            return now.addingTimeInterval(seconds)
        }
        // RFC 7231 IMF-fixdate, used by some API gateways.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        guard let date = formatter.date(from: raw),
              date >= now && date.timeIntervalSince(now) <= 7 * 24 * 3600 else { return nil }
        return date
    }
}

