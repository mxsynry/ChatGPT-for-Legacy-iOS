import SwiftUI

// Actual 2026 framework includes a separate MessageSourcesView module.
// This is our independently implemented iOS 16 source presentation component.
struct MessageSourcesView: View {
    let sources: [ResponseCitation]
    @State private var expanded = false

    var body: some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Button {
                    expanded.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "link")
                        Text("Sources (\(sources.count))")
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Show cited websites")
                if expanded {
                    ForEach(sources) { source in
                        if let url = URL(string: source.url) {
                            Link(destination: url) {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "arrow.up.right.square")
                                    Text(source.title).lineLimit(2)
                                    Spacer(minLength: 0)
                                }
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .padding(8)
                                .background(Color(.tertiarySystemBackground),
                                            in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
            .padding(.top, 5)
        }
    }
}
