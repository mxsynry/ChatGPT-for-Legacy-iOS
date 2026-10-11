import SwiftUI

struct BranchCreationContext: Identifiable {
    let id = UUID()
    let conversationID: UUID
    let messageID: UUID?
    let precedingCount: Int
    let totalCount: Int
    let parentTitle: String
    let defaultModelID: String
    let initiallyTemporary: Bool
}

/// "Branch from here" is a modal operation, not "Duplicate conversation".
/// It selects an anchor, new-chat style, model, and optional reasoning effort.
struct BranchCreateSheet: View {
    let context: BranchCreationContext
    let models: [ModelChoice]
    let onCreate: (LocalBranchMode, String, BranchReasoning, Bool) -> Void
    let onCancel: () -> Void
    @State private var selectedMode = LocalBranchMode.chat
    @State private var modelID: String
    @State private var reasoning = BranchReasoning.automatic
    @State private var temporary: Bool
    @State private var showAllModels = false
    private var visibleModels: [ModelChoice] { models.filter { showAllModels || $0.isListed } }

    init(context: BranchCreationContext, models: [ModelChoice],
         onCreate: @escaping (LocalBranchMode, String, BranchReasoning, Bool) -> Void,
         onCancel: @escaping () -> Void) {
        self.context = context
        self.models = models
        self.onCreate = onCreate
        self.onCancel = onCancel
        _modelID = State(initialValue: context.defaultModelID)
        _temporary = State(initialValue: context.initiallyTemporary)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Branch point") {
                    Text(context.parentTitle).lineLimit(2)
                    Text("Keep first \(context.precedingCount) of \(context.totalCount) messages in the new branch. The original stays unchanged.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section("Which mode?") {
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(LocalBranchMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    if selectedMode == .workStyle {
                        Text("Work-style is a structured chat prompt in this open-source client, NOT the official ChatGPT Work runtime or cloud computer.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    Toggle("Temporary (do not save locally)", isOn: $temporary)
                }
                Section("Which model?") {
                    TextField("Exact model ID", text: $modelID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !models.isEmpty {
                        Picker("Choose returned model", selection: $modelID) {
                            if !visibleModels.contains(where: { $0.id == modelID }) {
                                Text("Selected: \(modelID)").tag(modelID)
                            }
                            ForEach(visibleModels) { item in
                                Text(item.displayName).tag(item.id)
                            }
                        }
                        Toggle("Show other returned models", isOn: $showAllModels)
                    }
                    Text("Your selected model is passed through unchanged. The server decides whether it supports this mode or feature.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section("Reasoning") {
                    Picker("Effort", selection: $reasoning) {
                        ForEach(BranchReasoning.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    Text("A requested effort may be rejected by a model; Model default is safest.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Button {
                    onCreate(selectedMode,
                             modelID.trimmingCharacters(in: .whitespacesAndNewlines),
                             reasoning, temporary)
                } label: {
                    Label("Create branch from here", systemImage: "arrow.triangle.branch")
                        .frame(maxWidth: .infinity)
                }
                .disabled(modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Branch into…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
