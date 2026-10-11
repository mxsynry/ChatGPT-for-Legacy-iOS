import Foundation
import Combine
import LocalAuthentication

/// Local-only privacy gate. This is not an OpenAI account passkey.
/// Unlock state is ephemeral and is revoked whenever the app resigns active.
@MainActor final class PrivateChatAccess: ObservableObject {
    @Published private(set) var unlocked = Set<UUID>()
    @Published var error: String?

    func canRead(_ id: UUID) -> Bool { unlocked.contains(id) }
    func revokeAll() { unlocked.removeAll() }
    func revoke(_ id: UUID) { unlocked.remove(id) }

    /// A separate authentication gate for exporting all chats, including locked
    /// ones. Unlocking one conversation must not unlock or export another one.
    func authorizeSensitiveExport() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            error = policyError?.localizedDescription ?? "Device authentication unavailable."
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication,
                localizedReason: "Export your locally protected conversations")
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    @discardableResult func authenticate(_ id: UUID) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var laError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &laError) else {
            error = laError?.localizedDescription ?? "Device passcode or Touch ID is unavailable."
            return false
        }
        do {
            guard try await context.evaluatePolicy(.deviceOwnerAuthentication,
                      localizedReason: "Unlock this private conversation") else { return false }
            unlocked.insert(id)
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
