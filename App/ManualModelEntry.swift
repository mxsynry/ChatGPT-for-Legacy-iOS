import SwiftUI

struct ManualModelEntry: View {
  @State private var entry: String
  let onSelect: (String) -> Void

  init(current: String, onSelect: @escaping (String) -> Void) {
    _entry = State(initialValue: current)
    self.onSelect = onSelect
  }
  private var valid: Bool {
    let id = entry.trimmingCharacters(in: .whitespacesAndNewlines)
    return !id.isEmpty && id.count <= 160
      && !id.contains(where: { $0.isWhitespace || $0.isNewline })
  }
  var body: some View {
    Form {
      Section("Model ID") {
        TextField("Exact model slug", text: $entry)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        Button("Use this model") { onSelect(entry.trimmingCharacters(in: .whitespacesAndNewlines)) }
          .disabled(!valid)
      }
      Section {
        Text(
          "Manual selection is for legitimate account models not shown in the UI. It cannot unlock unavailable models or override server-side usage limits."
        )
        .font(.footnote).foregroundColor(.secondary)
      }
    }.navigationTitle("Custom model")
  }
}
