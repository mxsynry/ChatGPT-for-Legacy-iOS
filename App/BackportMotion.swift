import SwiftUI
import UIKit

/// Native iOS 16 motion components. The timings are independently authored;
/// bundled official-client Lottie/orbit assets are inventoried separately.
enum BackportMotion {
    /// Respect UIKit's haptic availability/fallback; these are *inspired* by
    /// the official clients' AHAP cue inventory, not copies of those patterns.
    static func selectionHaptic() { UISelectionFeedbackGenerator().selectionChanged() }
    static func confirmationHaptic() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static let menu = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let appearance = Animation.easeOut(duration: 0.22)
    static let interruption = AnyTransition.move(edge: .bottom).combined(with: .opacity)
}

struct BackportActivityDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 5, height: 5)
                    .scaleEffect(reduceMotion ? 1 : (running ? 1 : 0.55))
                    .opacity(reduceMotion ? 1 : (running ? 1 : 0.35))
                    .animation(reduceMotion ? nil :
                        .easeInOut(duration: 0.54)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.13), value: running)
            }
        }
        .onAppear { running = true }
        .onDisappear { running = false }
        .accessibilityHidden(true)
    }
}

/// A distinct interruption state rather than an alert that disappears and
/// makes an interrupted response impossible to retry manually.
struct StreamRetryBanner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: ResponseRetryContext
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let seconds = max(0, Int(ceil((state.retryAfter ?? .distantPast)
                .timeIntervalSince(timeline.date))))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.isRateLimited ? "Response rate-limited" : "Response interrupted")
                            .font(.subheadline.weight(.semibold))
                        Text(state.reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                        if state.receivedPartialText {
                            Text("Your partial answer is preserved. Retry generates a new full answer.")
                                .font(.caption2).foregroundColor(.secondary)
                        } else {
                            Text("Retry sends a new request and may use additional tokens.")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Button(action: onDismiss) { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss response recovery")
                }
                Button {
                    BackportMotion.confirmationHaptic()
                    onRetry()
                } label: {
                    Label(seconds > 0 ? "Retry in \(seconds)s" : "Retry response",
                          systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(seconds > 0)
                .accessibilityHint("Starts another request, never resumes the original network connection")
            }
            .padding(12)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .transition(reduceMotion ? .opacity : BackportMotion.interruption)
        }
    }
}
