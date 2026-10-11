import Foundation

/// One explicit replay opportunity, scoped to the exact user message that
/// triggered the interrupted response. Partial assistant text remains visible,
/// but is NOT included in the replay payload to avoid contaminating a retry.
struct ResponseRetryContext {
    let conversationID: UUID
    let triggeringUserID: UUID
    let failedAssistantID: UUID
    let modelID: String
    let webSearchEnabled: Bool
    let retryAfter: Date?
    let isRateLimited: Bool
    let reason: String
    let receivedPartialText: Bool

    func inputForManualRetry(_ messages: [ChatMessage]) -> [ChatMessage]? {
        guard let last = messages.last,
              last.id == failedAssistantID || last.id == triggeringUserID,
              let userIndex = messages.lastIndex(where: { $0.id == triggeringUserID && $0.role == "user" }),
              !messages[(userIndex + 1)...].contains(where: { $0.role == "user" }) else { return nil }
        return Array(messages.prefix(userIndex + 1))
    }
}
