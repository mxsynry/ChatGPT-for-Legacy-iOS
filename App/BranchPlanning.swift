import Foundation

// Independent iOS 16 implementation. The official 2026 binary contains
// branchConversation(conversationID:messageID:...) and "Branch into Work";
// this client does not have access to the first-party Work runtime.
enum LocalBranchMode: String, CaseIterable, Codable, Identifiable {
    case chat
    case workStyle

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .chat: return "Chat"
        case .workStyle: return "Work-style (local)"
        }
    }
    var instructions: String? {
        switch self {
        case .chat: return nil
        case .workStyle:
            return "Help the user finish their requested work through a structured, practical approach. " +
                "For complex tasks, identify the concrete deliverable, provide useful intermediate outputs, " +
                "and clearly distinguish completed actions from proposed actions. " +
                "Never claim to have executed tools or accessed a computer when you have not."
        }
    }
}

enum BranchReasoning: String, CaseIterable, Codable, Identifiable {
    case automatic, low, medium, high, xhigh

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .automatic: return "Model default"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .xhigh: return "Extra high"
        }
    }
    var apiValue: String? { self == .automatic ? nil : rawValue }
}

struct BranchProvenance: Codable, Equatable {
    let parentConversationID: UUID
    let parentMessageID: UUID?
    let createdAt: Date
}

enum BranchPlanning {
    /// `nil` anchor means branch after the latest complete message.
    /// A specific anchor retains all messages *through that message* only.
    static func prefixCount(ids: [UUID], through anchor: UUID?) -> Int? {
        guard let anchor = anchor else { return ids.count }
        guard let index = ids.firstIndex(of: anchor) else { return nil }
        return index + 1
    }

    static func title(parent: String, mode: LocalBranchMode) -> String {
        let label = mode == .workStyle ? "Work branch" : "Branch"
        return String("\(label) · \(parent)".prefix(100))
    }
}
