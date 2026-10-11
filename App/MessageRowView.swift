import SwiftUI
import UIKit

/// iOS 16 reconstruction: row owns visual layout and contextual actions.
/// Modeled on component boundaries identified in the official 2026 binary,
/// not extracted Swift code or a pixel-perfect copy.
struct MessageRowView: View {
    let message: ChatMessage
    let onCopy: () -> Void
    let onShare: () -> Void
    let onEdit: () -> Void
    let onRegenerate: () -> Void
    let onBranch: () -> Void
    let onReadAloud: () -> Void
    let speaking: Bool
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == "user" { Spacer(minLength: 32) }
            VStack(alignment: .leading, spacing: 8) {
                if let encoded = message.imageDataURL {
                    AttachmentThumbnailView(messageID: message.id, dataURL: encoded)
                }
                if isStreaming {
                    // Parsing complex Markdown/code fences on *every* SSE delta
                    // caused O(n²) work on lengthy responses. Show instant text;
                    // render rich Markdown once the response finishes.
                    Text(message.text.isEmpty ? "…" : message.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    MessageContentView(text: message.text.isEmpty ? "…" : message.text)
                }
                if message.role == "assistant" {
                    if message.isInterrupted {
                        Label("Interrupted response", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    MessageSourcesView(sources: message.citations)
                }
            }
            .padding(13)
            .background(message.role == "user" ? Color(.secondarySystemBackground) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            if message.role != "user" { Spacer(minLength: 32) }
        }
        .id(message.id)
        .contextMenu {
            Button(action: onCopy) { Label("Copy", systemImage: "doc.on.doc") }
            Button(action: onShare) { Label("Share", systemImage: "square.and.arrow.up") }
            Button(action: onBranch) { Label("Branch from this message…", systemImage: "arrow.triangle.branch") }
                .disabled(isStreaming)
            if message.role == "user" {
                Button(action: onEdit) { Label("Edit message", systemImage: "pencil") }
            } else {
                Button(action: onRegenerate) { Label("Regenerate", systemImage: "arrow.clockwise") }
                    .disabled(isStreaming)
                Button(action: onReadAloud) {
                    Label(speaking ? "Stop reading" : "Read aloud", systemImage: "speaker.wave.2")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
