import Foundation

/// Coalesce fine-grained SSE text deltas before updating a large SwiftUI list.
/// First characters appear immediately; subsequent fragments are grouped for
/// ~70 ms or 4096 bytes. This affects UI update frequency, not token order.
/// No opacity, typewriter or other text animation is introduced.
struct StreamingTextBatcher {
    private var pending = ""
    private var lastEmission: Date?
    static let interval: TimeInterval = 0.07
    static let maxBytes = 4096

    mutating func push(_ delta: String, now: Date = Date()) -> String? {
        guard !delta.isEmpty else { return nil }
        pending += delta
        if let last = lastEmission,
           now.timeIntervalSince(last) < Self.interval,
           pending.utf8.count < Self.maxBytes { return nil }
        return flush(now: now)
    }

    mutating func flush(now: Date = Date()) -> String? {
        guard !pending.isEmpty else { return nil }
        let next = pending
        pending = ""
        lastEmission = now
        return next
    }
}
