import SwiftUI

/// Displays every exact fork from an original conversation, while highlighting
/// the current branch's siblings. This is local history, not official cloud sync.
struct BranchVersionsSheet: View {
    let currentID: UUID?
    let conversations: [LocalConversation]
    let onChoose: (UUID) -> Void
    let onClose: () -> Void

    private var current: LocalConversation? {
        conversations.first(where: { $0.id == currentID })
    }
    private var familyID: UUID? {
        guard let current = current else { return nil }
        return current.branchedFrom?.parentConversationID ?? current.id
    }
    private var familyOriginal: LocalConversation? {
        guard let id = familyID else { return nil }
        return conversations.first(where: { $0.id == id })
    }
    private var familyForks: [BranchForkGroup] {
        guard let id = familyID else { return [] }
        return BranchNavigation.groupedForks(sourceID: id, conversations: conversations)
    }
    // A branch can also be a parent: do not bury its own children behind a
    // separate unnamed conversation duplicate.
    private var childForks: [BranchForkGroup] {
        guard let current = current, current.branchedFrom != nil else { return [] }
        return BranchNavigation.groupedForks(sourceID: current.id, conversations: conversations)
    }
    private func label(for group: BranchForkGroup, in parent: LocalConversation?) -> String {
        guard let anchor = group.anchorMessageID else { return "Forks from conversation end" }
        if let index = parent?.messages.firstIndex(where: { $0.id == anchor }) {
            return "After message \(index + 1)"
        }
        return "Message fork · \(anchor.uuidString.prefix(8))"
    }
    private func row(_ version: BranchDestination) -> some View {
        Button { onChoose(version.id) } label: {
            HStack(spacing: 12) {
                Image(systemName: version.isOriginal ? "text.bubble" : "arrow.triangle.branch")
                VStack(alignment: .leading, spacing: 4) {
                    Text(version.title).lineLimit(2)
                    Text("\(version.mode.displayName) · \(version.modelID ?? "Default model")" +
                         (version.temporary ? " · Temporary" : ""))
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer(minLength: 4)
                if version.id == currentID { Image(systemName: "checkmark") }
            }
        }
    }
    private func originalDestination(_ chat: LocalConversation) -> BranchDestination {
        BranchDestination(id: chat.id, title: chat.title, mode: chat.branchMode,
            modelID: chat.modelID, temporary: chat.isTemporary, isOriginal: true)
    }

    var body: some View {
        NavigationStack {
            List {
                if let original = familyOriginal {
                    Section("Original conversation") { row(originalDestination(original)) }
                } else if familyID != nil {
                    Section("Original conversation") {
                        Text("Original deleted; surviving local branches remain available.")
                            .foregroundColor(.secondary)
                    }
                }
                ForEach(familyForks) { group in
                    Section(label(for: group, in: familyOriginal)) {
                        ForEach(group.branches) { branch in row(branch) }
                    }
                }
                ForEach(childForks) { group in
                    Section("Branches from this version · " + label(for: group, in: current)) {
                        ForEach(group.branches) { branch in row(branch) }
                    }
                }
                if familyForks.isEmpty && childForks.isEmpty {
                    Section("Versions") {
                        Text("No alternate branches yet. Hold a message and choose Branch from this message.")
                            .foregroundColor(.secondary)
                    }
                }
                Section {
                    Text("Each branch is a separate local conversation. Switching does not overwrite the original or synchronize ChatGPT cloud history.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Branches & versions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done", action: onClose) }
            }
        }
    }
}
