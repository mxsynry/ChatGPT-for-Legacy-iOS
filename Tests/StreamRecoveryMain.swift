import Foundation

@main struct StreamRecoveryMain {
    static func main() throws {
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            if !condition() { fatalError("Stream recovery regression: \(label)") }
        }
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        check(RetryAfterPolicy.deadline(headers: ["Retry-After": "60"], now: now) == now.addingTimeInterval(60),
              "Retry-After seconds parsed without arbitrary guess")
        check(RetryAfterPolicy.deadline(headers: ["rEtRy-AfTeR": "5"], now: now) == now.addingTimeInterval(5),
              "case-insensitive Retry-After")
        check(RetryAfterPolicy.deadline(headers: ["retry-after": "-1"], now: now) == nil,
              "negative retry is rejected")
        check(RetryAfterPolicy.deadline(headers: ["retry-after": "900000"], now: now) == nil,
              "extreme backoff cannot block retry forever")
        check(RetryAfterPolicy.deadline(headers: [:], now: now) == nil,
              "no fake countdown without server data")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        let dateText = formatter.string(from: now.addingTimeInterval(120))
        check(RetryAfterPolicy.deadline(headers: ["Retry-After": dateText], now: now) == now.addingTimeInterval(120),
              "HTTP-date retry parsed")
        let diagnostic = BackendDiagnostic.parse(
            Data(#"{"error":{"message":"quota","code":"rate_limit_exceeded"}}"#.utf8),
            status: 429, requestID: "req_test", headers: ["Retry-After": "42"])
        check(diagnostic.retryAfter != nil && abs(diagnostic.retryAfter!.timeIntervalSinceNow - 42) < 3,
              "HTTP 429 has an actionable deadline")
        check(BackendDiagnostic.parse(Data(), status: 401, requestID: nil).retryAfter == nil,
              "401 never pretends to be a temporary rate limit")
        let user = ChatMessage(role: "user", text: "Explain motion")
        let partial = ChatMessage(role: "assistant", text: "First,")
        let ctx = ResponseRetryContext(
            conversationID: UUID(), triggeringUserID: user.id,
            failedAssistantID: partial.id, modelID: "gpt-test", webSearchEnabled: false,
            retryAfter: nil, isRateLimited: false,
            reason: "Connection closed", receivedPartialText: true)
        check(ctx.inputForManualRetry([user, partial])?.map(\.id) == [user.id],
              "retry excludes partial assistant from request payload")
        check(ctx.inputForManualRetry([user])?.map(\.id) == [user.id],
              "retry works if blank assistant placeholder was removed")
        check(ctx.inputForManualRetry([user, partial, ChatMessage(role: "user", text: "new turn")]) == nil,
              "stale retry cannot follow a new user turn")
        check(ctx.inputForManualRetry([user, ChatMessage(role: "assistant", text: "different")]) == nil,
              "stale retry cannot replace a different assistant")
        let eof = StreamInterruption(cause: .connectionClosed, reason: nil, requestID: "req_public",
                                     eventsReceived: 5, receivedText: true)
        let incomplete = StreamInterruption(cause: .serverIncomplete, reason: "max_output_tokens",
                                           requestID: nil, eventsReceived: 5, receivedText: true)
        check(eof.errorDescription!.contains("connection closed") &&
              incomplete.errorDescription!.contains("max_output_tokens"),
              "explicit incomplete is distinguished from abrupt EOF")
        let event = ResponseStreamEvents.parse(#"{"type":"response.incomplete","response":{"incomplete_details":{"reason":"max_output_tokens"}}}"#)
        if case .incomplete(let reason) = event {
            check(reason == "max_output_tokens", "incomplete reason preserved")
        } else { fatalError("Response incomplete event was not classified") }
        print("PASS: stream termination classes, real Retry-After, scoped manual replay, partial preservation")
    }
}
