import SwiftUI
import SafariServices

/// Keep model selection independent of any usage/capacity display on iOS 16.
struct ModelAndUsageBar: View {
    let modelName: String
    let isChatGPTPlan: Bool
    let lastUsage: ResponseUsage?
    let lastRateLimits: RateLimitHeaders?
    let onModel: () -> Void
    let onBranch: () -> Void
    let onUsage: () -> Void

    private var usageLabel: String {
        if isChatGPTPlan { return "Plan usage" }
        // HTTP rate limiting is not an account credit balance.
        if let rate = lastRateLimits?.requests {
            return "Rate \(Int(rate.fractionRemaining * 100))%"
        }
        return "Usage"
    }
    var body: some View {
        HStack(spacing: 7) {
            Button(action: onModel) {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                    Text(modelName).lineLimit(1).truncationMode(.middle)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Color(.secondarySystemBackground), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 190, alignment: .leading)
            .accessibilityLabel("Choose model: \(modelName)")
            .accessibilityIdentifier("model.selector.alwaysVisible")

            Spacer(minLength: 0)
            Button(action: onBranch) {
                Image(systemName: "arrow.triangle.branch")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Branch conversation into another mode")
            .accessibilityIdentifier("conversation.branch")

            Button(action: onUsage) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.pie")
                    Text(usageLabel).lineLimit(1)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .accessibilityLabel("View usage. Shows verified API rate limits when available and links to actual ChatGPT account usage")
            .frame(minHeight: 44)
            .accessibilityIdentifier("usage.button")
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }
}

struct OfficialUsageBrowser: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let url = URL(string: "https://chatgpt.com/settings/usage")!
        return SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

struct UsageInfoSheet: View {
    let isChatGPTPlan: Bool
    let lastUsage: ResponseUsage?
    let lastRateLimits: RateLimitHeaders?
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var showOfficialUsage = false

    var body: some View {
        NavigationStack {
            Form {
                if isChatGPTPlan {
                    Section("Real ChatGPT account usage") {
                        Text("View your actual account and app limits in ChatGPT Settings → Usage. This screen is owned by ChatGPT, not inferred from message tokens.")
                            .font(.footnote)
                        Button("View ChatGPT usage in app") { showOfficialUsage = true }
                        Button("Open Usage in Safari") {
                            if let url = URL(string: "https://chatgpt.com/settings/usage") {
                                openURL(url)
                            }
                        }
                        Text("Sign in on the official page if prompted. The app's OAuth token is not a browser cookie.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }
                Section("Last completed request") {
                    if let usage = lastUsage {
                        LabeledContent("Input tokens", value: String(usage.inputTokens))
                        LabeledContent("Output tokens", value: String(usage.outputTokens))
                        LabeledContent("Total tokens", value: String(usage.totalTokens))
                    } else {
                        Text("No server-reported token totals yet.")
                            .foregroundColor(.secondary)
                    }
                    Text("Token totals describe one request, not your remaining ChatGPT plan allowance.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                if let limits = lastRateLimits {
                    Section("API HTTP rate limits (not plan balance)") {
                        if let resource = limits.requests {
                            rateRow("Requests", resource)
                        }
                        if let resource = limits.tokens {
                            rateRow("Tokens", resource)
                        }
                        Text("These come from x-ratelimit response headers, when supplied. They describe a server rate window and do not represent five-hour or weekly ChatGPT usage.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }
                if !isChatGPTPlan {
                    Section("API account") {
                        Text("API billing and rate windows are managed separately from ChatGPT subscriptions.")
                            .font(.footnote)
                        Button("Open OpenAI Platform") {
                            if let url = URL(string: "https://platform.openai.com/usage") {
                                openURL(url)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Usage")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showOfficialUsage) {
                NavigationStack {
                    OfficialUsageBrowser()
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle("ChatGPT usage")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showOfficialUsage = false }
                            }
                        }
                }
            }
        }
    }

    private func rateRow(_ title: String, _ resource: RateLimitHeaders.Resource) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                Spacer()
                Text("\(resource.remaining) / \(resource.limit)")
                    .monospacedDigit().foregroundColor(.secondary)
            }
            ProgressView(value: resource.fractionRemaining)
            if let reset = resource.resetText {
                Text("Reported reset: \(reset)")
                    .font(.footnote).foregroundColor(.secondary)
            }
        }
    }
}
