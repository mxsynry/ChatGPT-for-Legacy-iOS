import SwiftUI

struct MessageEditContext: Identifiable {
    let messageID: UUID
    let conversationID: UUID
    let originalText: String
    let hasLaterMessages: Bool
    let preservesImage: Bool
    var id: UUID { messageID }
}

/// Long messages can be edited without a single-line alert truncating content.
/// Destructive rewinding occurs only after explicit confirmation.
struct MessageEditorSheet: View {
    let context: MessageEditContext
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @State private var draft: String
    @State private var askToDiscard = false

    init(context: MessageEditContext, onSave: @escaping (String) -> Void,
         onCancel: @escaping () -> Void) {
        self.context = context
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: context.originalText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Edit your message")
                    .font(.headline)
                TextEditor(text: $draft)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .frame(minHeight: 180)
                if context.preservesImage {
                    Label("Existing photo attachment will be preserved", systemImage: "photo")
                        .font(.caption)
                }
                Text("Editing an earlier prompt and regenerating may remove later turns in this conversation.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("Edit message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if context.hasLaterMessages { askToDiscard = true }
                        else { onSave(draft) }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.count > 20_000)
                }
            }
            .confirmationDialog("Discard later turns?", isPresented: $askToDiscard,
                                titleVisibility: .visible) {
                Button("Save and regenerate", role: .destructive) { onSave(draft) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Later messages will be removed. This cannot be undone.")
            }
        }
    }
}
