import SwiftUI
import UIKit

struct MessageContentView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(MarkdownRenderCache.split(text).enumerated()), id: \.offset) { entry in
                switch entry.element {
                case .prose(let markdown):
                    Text(.init(markdown)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .code(let language, let code):
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            Text(language.isEmpty ? "Code" : language)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = code
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                        }.padding(10)
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(code.isEmpty ? " " : code)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(12)
                        }
                    }
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .contain)
                }
            }
        }
    }
}
