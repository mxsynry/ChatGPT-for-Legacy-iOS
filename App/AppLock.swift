import SwiftUI
import LocalAuthentication

@MainActor final class AppLock: ObservableObject {
    @Published private(set) var unlocked = false
    @Published var errorMessage: String?
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "appLockEnabled")
            if !enabled { unlocked = true }
            else { unlocked = false }
        }
    }
    init() {
        enabled = UserDefaults.standard.bool(forKey: "appLockEnabled")
        unlocked = !enabled
    }
    func lock() { if enabled { unlocked = false } }
    func unlock() async {
        guard enabled else { unlocked = true; return }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorMessage = error?.localizedDescription ?? "Device authentication is unavailable."
            return
        }
        do {
            let accepted = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                localizedReason: "Unlock your local conversations")
            if accepted { unlocked = true; errorMessage = nil }
        } catch { errorMessage = error.localizedDescription }
    }
    func enableAfterAuthentication() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorMessage = error?.localizedDescription ?? "Set a device passcode first."
            return
        }
        do {
            if try await context.evaluatePolicy(.deviceOwnerAuthentication,
                    localizedReason: "Enable app lock") {
                enabled = true
                unlocked = true
                errorMessage = nil
            }
        } catch { errorMessage = error.localizedDescription }
    }
}
