import Foundation

/// An HTTP response's request/token rate limits. These are NOT the user's
/// ChatGPT plan usage, shared five-hour quota, weekly allowance, or credits.
struct RateLimitHeaders: Codable, Equatable {
    struct Resource: Codable, Equatable {
        let limit: Int
        let remaining: Int
        let resetText: String?
        var fractionRemaining: Double {
            guard limit > 0 else { return 0 }
            return min(1, max(0, Double(remaining) / Double(limit)))
        }
    }
    let requests: Resource?
    let tokens: Resource?
    let observedAt: Date

    static func parse(_ raw: [String: String], now: Date = Date()) -> RateLimitHeaders? {
        var headers = [String: String]()
        for (key, value) in raw {
            headers[key.lowercased()] = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func resource(_ key: String) -> Resource? {
            guard let limitText = headers["x-ratelimit-limit-\(key)"],
                  let remainingText = headers["x-ratelimit-remaining-\(key)"],
                  let limit = Int(limitText), let remaining = Int(remainingText),
                  limit > 0, remaining >= 0 else { return nil }
            return Resource(limit: limit, remaining: remaining,
                            resetText: headers["x-ratelimit-reset-\(key)"])
        }
        let requestLimit = resource("requests")
        let tokenLimit = resource("tokens")
        guard requestLimit != nil || tokenLimit != nil else { return nil }
        return RateLimitHeaders(requests: requestLimit, tokens: tokenLimit,
                                observedAt: now)
    }
}
