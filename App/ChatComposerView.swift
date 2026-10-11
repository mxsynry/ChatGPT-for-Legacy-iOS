import SwiftUI
import PhotosUI

/// iOS 16 implementation inspired by the official 2026 app's distinct
/// composer, tool menu and long-press send/model-selection components.
struct ChatComposerView: View {
    @Binding var input: String
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var webSearch: Bool
    let imageAttached: Bool
    let documentName: String?
    let modelLabel: String
    let isGenerating: Bool
    let isRecording: Bool
    let onRemoveImage: () -> Void
    let onRemoveDocument: () -> Void
    let onCamera: () -> Void
    let onDocument: () -> Void
    let onModelPicker: () -> Void
    let onDictate: () -> Void
    let onSend: () -> Void
    let onStop: () -> Void
    let onNewChat: () -> Void
    let onTemporaryChat: () -> Void

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageAttached || documentName != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if imageAttached || documentName != nil || webSearch {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        if imageAttached { chip("Photo", icon: "photo", action: onRemoveImage) }
                        if let name = documentName { chip(String(name.prefix(24)), icon: "doc", action: onRemoveDocument) }
                        if webSearch {
                            chip("Web search", icon: "globe") { webSearch = false }
                        }
                    }
                }
                .padding(.horizontal, 3)
            }
            HStack(alignment: .bottom, spacing: 7) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 44)
                }
                .accessibilityLabel("Attach a photo")

                Menu {
                    Button(action: onCamera) { Label("Take photo", systemImage: "camera") }
                    Button(action: onDocument) { Label("Attach document", systemImage: "doc") }
                    Button { webSearch.toggle() } label: {
                        Label(webSearch ? "Turn off web search" : "Use web search", systemImage: "globe")
                    }
                    Button(action: onModelPicker) { Label("Choose model", systemImage: "cpu") }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 38, height: 44)
                }
                .accessibilityLabel("More chat tools")

                TextField("Message", text: $input, axis: .vertical)
                    .lineLimit(1...6)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.send)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Message")

                if !isGenerating {
                    Button(action: onDictate) {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .foregroundColor(isRecording ? .red : .primary)
                            .frame(width: 38, height: 44)
                    }
                    .accessibilityLabel(isRecording ? "Finish dictation" : "Dictate message")
                }

                Button(action: isGenerating ? onStop : onSend) {
                    Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                        .font(.headline)
                        .foregroundColor(Color(.systemBackground))
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(isGenerating || canSend ? 1 : 0.4), in: Circle())
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(isGenerating ? "Stop generating" : "Send message")
                .contextMenu {
                    Button(action: onModelPicker) {
                        Label("Choose model (currently \(modelLabel))", systemImage: "cpu")
                    }
                    Button(action: onNewChat) { Label("New chat", systemImage: "square.and.pencil") }
                    Button(action: onTemporaryChat) { Label("Temporary chat", systemImage: "eye.slash") }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 7)
    }

    private func chip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title + " ×", systemImage: icon)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
