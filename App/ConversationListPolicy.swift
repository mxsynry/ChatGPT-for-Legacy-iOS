import Foundation

// Pure Foundation model for searchable, pinned and archived conversations.
// Kept separate from SwiftUI for tests on non-Apple build hosts.
enum ConversationListFilter: String, CaseIterable, Identifiable {
    case recent = "Recent", pinned = "Pinned", archived = "Archived"
    var id: String { rawValue }
}

struct ConversationListEntry: Identifiable, Equatable {
    let id: UUID
    let title: String
    let updatedAt: Date
    let pinned: Bool
    let archived: Bool
    let locked: Bool
    let searchableText: String
}

enum ConversationListPolicy {
    static func visible(_ records: [ConversationListEntry],
                        filter: ConversationListFilter, query: String) -> [ConversationListEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return records.filter { record in
            let match: Bool
            switch filter {
            case .recent: match = !record.archived
            case .pinned: match = record.pinned && !record.archived
            case .archived: match = record.archived
            }
            guard match else { return false }
            // Locked chat message text is never included in the searchable index.
            if needle.isEmpty { return true }
            if record.locked { return "Locked conversation".localizedCaseInsensitiveContains(needle) }
            return record.title.localizedCaseInsensitiveContains(needle) ||
                record.searchableText.localizedCaseInsensitiveContains(needle)
        }.sorted {
            if $0.pinned != $1.pinned { return $0.pinned && !$1.pinned }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
