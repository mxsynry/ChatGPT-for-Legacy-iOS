import Foundation

/// A fork is keyed by its source conversation and the anchor message.
/// `nil` anchor denotes a branch from the end of the conversation.
struct BranchForkKey: Hashable {
    let sourceConversationID: UUID
    let anchorMessageID: UUID?
}

struct BranchDestination: Equatable, Identifiable {
    let id: UUID
    let title: String
    let mode: LocalBranchMode
    let modelID: String?
    let temporary: Bool
    let isOriginal: Bool
}

struct BranchForkGroup: Identifiable {
    let parentConversationID: UUID
    let anchorMessageID: UUID?
    let branches: [BranchDestination]
    let createdAt: Date
    var id: String { parentConversationID.uuidString + ":" + (anchorMessageID?.uuidString ?? "end") }
}

enum BranchNavigation {
    /// All alternate paths from exactly one fork, plus its parent conversation.
    /// Stable ordering helps users find previous versions reliably.
    static func versions(sourceID: UUID, messageID: UUID?, conversations: [LocalConversation]) -> [BranchDestination] {
        guard let parent = conversations.first(where: { $0.id == sourceID }) else { return [] }
        let related = conversations.filter {
            $0.branchedFrom?.parentConversationID == sourceID &&
            $0.branchedFrom?.parentMessageID == messageID
        }.sorted {
            ($0.branchedFrom?.createdAt ?? .distantPast) < ($1.branchedFrom?.createdAt ?? .distantPast)
        }
        let original = BranchDestination(id: parent.id, title: parent.title,
                                         mode: parent.branchMode, modelID: parent.modelID,
                                         temporary: parent.isTemporary, isOriginal: true)
        return [original] + related.map {
            BranchDestination(id: $0.id, title: $0.title, mode: $0.branchMode,
                              modelID: $0.modelID, temporary: $0.isTemporary, isOriginal: false)
        }
    }
}

// The Stage 18 "Versions" screen displayed only branches with a nil anchor
// when opened from the ORIGINAL conversation. Real forks from earlier messages
// were therefore invisible. Group by each exact fork point instead.
extension BranchNavigation {
    static func groupedForks(sourceID: UUID, conversations: [LocalConversation]) -> [BranchForkGroup] {
        let children = conversations.compactMap { item -> (LocalConversation, BranchProvenance)? in
            guard let origin = item.branchedFrom,
                  origin.parentConversationID == sourceID else { return nil }
            return (item, origin)
        }
        let anchors = Set(children.map { $0.1.parentMessageID })
        return anchors.compactMap { anchor -> BranchForkGroup? in
            let matching = children.filter { $0.1.parentMessageID == anchor }
                .sorted {
                    if $0.1.createdAt != $1.1.createdAt { return $0.1.createdAt < $1.1.createdAt }
                    return $0.0.id.uuidString < $1.0.id.uuidString
                }
            guard let first = matching.first else { return nil }
            let items = matching.map { chat, _ in
                BranchDestination(id: chat.id, title: chat.title, mode: chat.branchMode,
                    modelID: chat.modelID, temporary: chat.isTemporary, isOriginal: false)
            }
            return BranchForkGroup(parentConversationID: sourceID, anchorMessageID: anchor,
                                   branches: items, createdAt: first.1.createdAt)
        }.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id < $1.id
        }
    }
}

