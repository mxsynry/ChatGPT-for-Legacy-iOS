import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import Network
import Security
import UIKit
import SafariServices

// Experimental iOS 16 open-source Sign in with ChatGPT transport.
// System Safari is used because the OSS OAuth flow requires an HTTP loopback callback.
// iOS can suspend the app while Safari is foregrounded: this requires on-device validation.
enum SignInFailure: LocalizedError {
    case unableToListen, cancelled, malformedCallback, invalidState, missingRegistration
    case invalidToken, noPlanPermission, server(String), backgroundExpired
    var errorDescription: String? {
        switch self {
        case .unableToListen: return "Could not start the local sign-in callback listener."
        case .cancelled: return "Sign-in was cancelled."
        case .malformedCallback: return "The sign-in callback was incomplete."
        case .invalidState: return "Sign-in security verification failed."
        case .missingRegistration: return "OpenAI did not return an issued client ID."
        case .invalidToken: return "The OpenAI identity token could not be verified."
        case .noPlanPermission: return "Account connected, but ChatGPT plan use wasn't authorized."
        case .server(let detail): return detail
        case .backgroundExpired: return "iOS suspended sign-in before the browser could return. Please retry."
        }
    }
}

private enum SignInConstants {
    static let resource = "https://api.openai.com/v1"
    static let authorize = "https://auth.openai.com/api/accounts/authorize"
    static let token = "https://auth.openai.com/api/accounts/oauth/token"
    static let jwks = "https://auth.openai.com/.well-known/jwks.json"
    static let issuer = "https://auth.openai.com"
}

struct ChatGPTSession: Codable {
    let clientID: String
    let subject: String
    let email: String?
    let accessToken: String
    let refreshToken: String?
    let idToken: String
    let scopes: String
    let expiresAt: Date
    var canUsePlan: Bool { scopes.split(separator: " ").contains("chatgpt.tokens.use.direct") }
    var snapshot: OAuthSessionSnapshot {
        OAuthSessionSnapshot(clientID: clientID, subject: subject,
                             accessToken: accessToken, refreshToken: refreshToken)
    }
}

// Non-secret billing selection: do NOT infer that an API key may be charged
// merely because a ChatGPT OAuth refresh has expired or been disconnected.
// The identity/refresh tokens themselves stay in Keychain.
enum AuthBillingChoice {
    private static let key = "OpenChat16AuthBillingRoute"
    enum Route: String { case chatgptPlan, apiKey }
    static var route: Route {
        if let stored = UserDefaults.standard.string(forKey: key),
           let value = Route(rawValue: stored) { return value }
        // Migration for existing Stage 13 sessions: default to the already-
        // authorized ChatGPT route when there is a signed-in account.
        return ChatGPTSessionVault.load() != nil ? .chatgptPlan : .apiKey
    }
    static func select(_ route: Route) { UserDefaults.standard.set(route.rawValue, forKey: key) }
}

// Tokens and client registration are protected by iOS Keychain, never UserDefaults.
enum ChatGPTSessionVault {
    private static let service = "dev.ios16reconstruction.chat.siwc"
    private static let tokenLock = NSLock()
    private static func get(_ name: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess ? item as? Data : nil
    }
    @discardableResult private static func put(_ name: String, _ data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name
        ]
        // Rotate tokens in-place rather than deleting the old refresh token first.
        let changed = SecItemUpdate(query as CFDictionary,
                                    [kSecValueData as String: data] as CFDictionary)
        if changed == errSecSuccess {
            // Best-effort upgrade of Stage 13 Keychain records from
            // AfterFirstUnlock to WhenUnlocked; never sacrifice the token write
            // just because a device refuses to alter an existing protection class.
            _ = SecItemUpdate(query as CFDictionary,
                              [kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
                                  as CFDictionary)
            return true
        }
        guard changed == errSecItemNotFound else { return false }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
    static func hostID() throws -> String {
        if let raw = get("host"), let value = String(data: raw, encoding: .utf8) { return value }
        let generated = "urn:uuid:" + UUID().uuidString.lowercased()
        guard put("host", Data(generated.utf8)) else {
            throw SignInFailure.server("Could not save the device identifier in Keychain.")
        }
        return generated
    }
    static func load() -> ChatGPTSession? {
        guard let data = get("session") else { return nil }
        return try? JSONDecoder().decode(ChatGPTSession.self, from: data)
    }
    @discardableResult static func save(_ session: ChatGPTSession) -> Bool {
        guard let data = try? JSONEncoder().encode(session) else { return false }
        tokenLock.lock(); defer { tokenLock.unlock() }
        return put("session", data)
    }
    private struct LegacyRegistration: Codable { let clientID: String; let subject: String }
    static func registrations() -> [ChatGPTAccountRegistration] {
        if let data = get("registrations-v2"),
           let records = try? JSONDecoder().decode([ChatGPTAccountRegistration].self, from: data) {
            return records
        }
        // Preserve an existing Stage 13 registration on first upgrade.
        if let raw = get("registration"),
           let old = try? JSONDecoder().decode(LegacyRegistration.self, from: raw) {
            return [ChatGPTAccountRegistration(clientID: old.clientID, subject: old.subject, email: nil)]
        }
        return []
    }
    static func registration() -> ChatGPTAccountRegistration? {
        let records = registrations()
        if let data = get("selected-client-id"), let clientID = String(data: data, encoding: .utf8) {
            // A sentinel ID means the user explicitly chose Add Another Account.
            return OAuthRegistrationIndex.selected(clientID, from: records)
        }
        if let saved = load() {
            return records.first(where: { $0.clientID == saved.clientID && $0.subject == saved.subject })
        }
        return records.last
    }
    @discardableResult static func selectRegistration(_ clientID: String?) -> Bool {
        return put("selected-client-id", Data((clientID ?? "__new_registration__").utf8))
    }
    @discardableResult static func saveRegistration(clientID: String, subject: String,
                                                      email: String? = nil) -> Bool {
        let account = ChatGPTAccountRegistration(clientID: clientID, subject: subject, email: email)
        let records = OAuthRegistrationIndex.upsert(account, in: registrations())
        guard let encoded = try? JSONEncoder().encode(records),
              put("registrations-v2", encoded) else { return false }
        return selectRegistration(clientID)
    }
    // Do not delete other account registrations when adding a different account.
    // Registration != active token; sign-in is still required before API access.
    static func clearRegistrationSelection() { _ = selectRegistration(nil) }

    static func clearTokens() {
        tokenLock.lock(); defer { tokenLock.unlock() }
        deleteCurrentTokens()
    }
    @discardableResult static func clearTokens(ifCurrent old: ChatGPTSession) -> Bool {
        tokenLock.lock(); defer { tokenLock.unlock() }
        guard OAuthSessionSafety.canRotate(expected: old.snapshot, current: load()?.snapshot) else {
            return false
        }
        deleteCurrentTokens()
        return true
    }
    @discardableResult static func rotateTokens(ifCurrent old: ChatGPTSession,
                                                 updated: ChatGPTSession) -> Bool {
        guard let data = try? JSONEncoder().encode(updated) else { return false }
        tokenLock.lock(); defer { tokenLock.unlock() }
        guard OAuthSessionSafety.canRotate(expected: old.snapshot, current: load()?.snapshot) else {
            return false
        }
        return put("session", data)
    }
    private static func deleteCurrentTokens() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "session"]
        SecItemDelete(query as CFDictionary)
    }

}

private func randomURLSafe(_ count: Int = 32) throws -> String {
    var buffer = [UInt8](repeating: 0, count: count)
    guard SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer) == errSecSuccess else {
        throw SignInFailure.server("Secure random generation unavailable. Sign-in stopped.")
    }
    return Data(buffer).base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

private func formEncoded(_ fields: [String: String]) -> Data {
    var c = URLComponents()
    c.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
    return Data((c.percentEncodedQuery ?? "").utf8)
}

// Bind to the loopback interface only. State and PKCE remain required even on localhost.
private final class LoopbackCallback {
    private var listener: NWListener?
    private var callback: CheckedContinuation<URL, Error>?
    private var completed = false
    private var receivedURL: URL?
    private var expectedState = ""
    private let queue = DispatchQueue(label: "chatgpt.siwc.callback")
    var redirectURI: String = ""

    // Asynchronous listener startup avoids freezing SwiftUI for up to five seconds
    // on failure. Every continuation is completed exactly once on the listener queue.
    private var startContinuation: CheckedContinuation<Void, Error>?
    private func finishStarting(_ error: Error? = nil) {
        guard let pending = startContinuation else { return }
        startContinuation = nil
        if let error = error { pending.resume(throwing: error) }
        else { pending.resume(returning: ()) }
    }
    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard !self.completed else {
                    continuation.resume(throwing: SignInFailure.cancelled)
                    return
                }
                self.startContinuation = continuation
                do {
                    let params = NWParameters.tcp
                    params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
                    let nw = try NWListener(using: params)
                    self.listener = nw
                    nw.stateUpdateHandler = { [weak self, weak nw] state in
                        guard let self = self else { return }
                        switch state {
                        case .ready:
                            guard let port = nw?.port?.rawValue else {
                                self.finishStarting(SignInFailure.unableToListen)
                                return
                            }
                            self.redirectURI = "http://127.0.0.1:\(port)/auth/callback"
                            self.finishStarting()
                        case .failed:
                            self.finishStarting(SignInFailure.unableToListen)
                        case .cancelled:
                            self.finishStarting(SignInFailure.cancelled)
                        default: break
                        }
                    }
                    nw.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
                    nw.start(queue: self.queue)
                    self.queue.asyncAfter(deadline: .now() + 8) { [weak self] in
                        guard let self = self, self.startContinuation != nil else { return }
                        self.listener?.cancel()
                        self.finishStarting(SignInFailure.unableToListen)
                    }
                } catch {
                    self.finishStarting(SignInFailure.unableToListen)
                }
            }
        }
    }
    func arm(expectedState: String) {
        queue.sync { self.expectedState = expectedState }
    }
    func wait() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if let url = self.receivedURL { continuation.resume(returning: url) }
                else if self.completed { continuation.resume(throwing: SignInFailure.cancelled) }
                else { self.callback = continuation }
            }
        }
    }
    func stop(_ error: Error = SignInFailure.cancelled) {
        queue.async {
            guard !self.completed else { return }
            self.completed = true
            self.listener?.cancel()
            self.finishStarting(error)
            self.callback?.resume(throwing: error)
            self.callback = nil
        }
    }
    private func accept(_ conn: NWConnection) {
        conn.start(queue: queue)
        // Only the callback's correct host, port, path and unpredictable OAuth state
        // may finish the pending login. Unknown probes never consume the callback.
        func read(_ buffered: Data) {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
                guard let self = self, error == nil else { conn.cancel(); return }
                var request = buffered
                if let data = data { request.append(data) }
                guard request.count <= 16384 else { conn.cancel(); return }
                guard let requestText = String(data: request, encoding: .utf8) else { conn.cancel(); return }
                guard requestText.contains("\r\n\r\n") else {
                    if isComplete { conn.cancel() } else { read(request) }
                    return
                }
                guard let port = self.listener?.port?.rawValue,
                      let url = OAuthLoopbackHTTP.callbackURL(requestText: requestText, port: port) else {
                    self.respond(conn, valid: false)
                    return
                }
                let outcome = OAuthCallbackSafety.classify(url, expectedState: self.expectedState, port: port)
                guard outcome != .ignore else {
                    self.respond(conn, valid: false)
                    return
                }
                self.respond(conn, valid: true)
                guard !self.completed else { return }
                self.completed = true
                self.receivedURL = url
                self.listener?.cancel()
                self.callback?.resume(returning: url)
                self.callback = nil
            }
        }
        read(Data())
    }
    private func respond(_ connection: NWConnection, valid: Bool) {
        let html = valid
            ? "<html><body style='font-family:-apple-system;padding:2rem'><h2>Authorization received</h2><p>Return to the app to continue.</p></body></html>"
            : "<html><body>Invalid authentication callback.</body></html>"
        let status = valid ? "200 OK" : "400 Bad Request"
        let reply = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nContent-Security-Policy: default-src 'none'; style-src 'unsafe-inline'\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n" + html
        connection.send(content: Data(reply.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }

}

private struct TokenReply: Decodable {
    let access_token: String
    let refresh_token: String?
    let id_token: String
    let expires_in: Int
    let scope: String
    let token_type: String
}

// Validate RS256 JWS using Apple's Security framework and OpenAI's live JWKS.
private enum IdentityValidator {
    private struct JWKS: Decodable {
        struct JWK: Decodable { let kid: String?; let kty: String; let n: String?; let e: String? }
        let keys: [JWK]
    }
    private static func unbase64(_ text: String) -> Data? {
        let b64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        return Data(base64Encoded: b64 + String(repeating: "=", count: (4 - b64.count % 4) % 4))
    }
    private static func len(_ count: Int) -> Data {
        if count < 128 { return Data([UInt8(count)]) }
        var i = count, bytes: [UInt8] = []
        while i > 0 { bytes.insert(UInt8(i & 255), at: 0); i >>= 8 }
        return Data([UInt8(0x80 | bytes.count)] + bytes)
    }
    private static func derInteger(_ x: Data) -> Data {
        var data = x
        while data.count > 1 && data.first == 0 { data.removeFirst() }
        if let f = data.first, f & 0x80 != 0 { data.insert(0, at: 0) }
        return Data([0x02]) + len(data.count) + data
    }
    static func validate(idToken: String, clientID: String, nonce: String) async throws -> (String, String?) {
        let parts = idToken.split(separator: ".").map(String.init)
        guard parts.count == 3, let hd = unbase64(parts[0]), let pd = unbase64(parts[1]),
              let sig = unbase64(parts[2]),
              let header = try? JSONSerialization.jsonObject(with: hd) as? [String: Any],
              let payload = try? JSONSerialization.jsonObject(with: pd) as? [String: Any],
              header["alg"] as? String == "RS256", let kid = header["kid"] as? String else { throw SignInFailure.invalidToken }
        let (data, response) = try await URLSession.shared.data(from: URL(string: SignInConstants.jwks)!)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let key = try JSONDecoder().decode(JWKS.self, from: data).keys.first(where: { $0.kid == kid && $0.kty == "RSA" }),
              let n = key.n.flatMap(unbase64), let e = key.e.flatMap(unbase64) else { throw SignInFailure.invalidToken }
        let body = derInteger(n) + derInteger(e)
        let der = Data([0x30]) + len(body.count) + body
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(der as CFData,
            [kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
             kSecAttrKeyClass as String: kSecAttrKeyClassPublic] as CFDictionary, &error) else { throw SignInFailure.invalidToken }
        let signingInput = Data((parts[0] + "." + parts[1]).utf8)
        guard SecKeyVerifySignature(publicKey, .rsaSignatureMessagePKCS1v15SHA256, signingInput as CFData, sig as CFData, &error),
              let claims = OAuthIDClaims.parse(payload),
              claims.isAcceptable(clientID: clientID, nonce: nonce) else {
            throw SignInFailure.invalidToken
        }
        // A user-facing email label should not be taken from an unverified claim.
        let verifiedEmail = (payload["email_verified"] as? Bool) == true
            ? payload["email"] as? String : nil
        return (claims.subject, verifiedEmail)
    }
}

// User-initiated Safari dismissal should immediately cancel OAuth rather than
// leave a 3-minute spinner in Settings.
private final class SignInBrowserDelegate: NSObject, SFSafariViewControllerDelegate {
    let onDismiss: () -> Void
    init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) { onDismiss() }
}

@MainActor final class ChatGPTSignIn: ObservableObject {
    @Published private(set) var session: ChatGPTSession? = ChatGPTSessionVault.load()
    @Published private(set) var busy = false
    // Switching registrations never invalidates an authenticated session
    // before the replacement OAuth flow has completed and been verified.
    @Published private(set) var pendingAccountSwitch = false
    @Published var message: String?
    @Published private(set) var phase = "Idle"
    @Published private(set) var loopbackDiagnostic: String?
    private var callback: LoopbackCallback?
    private var safariController: SFSafariViewController?
    private var safariDelegate: SignInBrowserDelegate?
    // Only reuse client registrations bound to an already-validated account.
    // Never cache an unverified callback-issued client ID across login attempts.
    private var loginAttempt = UUID()
    /// Foreground-only diagnostic: tests local networking, not the Safari/Google
    /// background lifecycle. No account secrets, token or OAuth code is used.
    func testLoopback() async {
        guard !busy else {
            loopbackDiagnostic = "Finish or cancel sign-in before testing loopback."
            return
        }
        let probe = LoopbackCallback()
        let began = Date()
        do {
            try await probe.start()
            let state = try randomURLSafe()
            probe.arm(expectedState: state)
            var parts = URLComponents(string: probe.redirectURI)!
            parts.queryItems = [URLQueryItem(name: "state", value: state),
                                URLQueryItem(name: "code", value: "local-probe-only")]
            guard let url = parts.url else { throw SignInFailure.malformedCallback }
            let timeout = Task {
                try? await Task.sleep(nanoseconds: 9_000_000_000)
                probe.stop(SignInFailure.backgroundExpired)
            }
            defer { timeout.cancel(); probe.stop() }
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (data, response) = try await URLSession.shared.data(for: request)
            let received = try await probe.wait()
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  data.count > 0,
                  received == url else { throw SignInFailure.malformedCallback }
            loopbackDiagnostic = String(format:
                "PASS · local 127.0.0.1 callback in %.2fs. Safari/Google/passkey login still needs testing.",
                Date().timeIntervalSince(began))
        } catch {
            probe.stop()
            loopbackDiagnostic = "Local callback failed: " + error.localizedDescription
        }
    }
    func cancelSignIn() {
        // The browser can be dismissed *after* the loopback callback, while
        // token exchange/JWKS validation is still in flight. Invalidate that
        // continuation too so it cannot save an unwanted account.
        loginAttempt = UUID()
        callback?.stop(SignInFailure.cancelled)
        // Avoid a programmatic dismissal being treated as user cancellation.
        safariController?.delegate = nil
        safariController?.dismiss(animated: true)
    }
    func switchAccount() {
        guard !busy else { return }
        // Do not destroy a good session just because the user opened the
        // account picker. The new registration becomes active only on success.
        cancelSignIn()
        ChatGPTSessionVault.clearRegistrationSelection()
        pendingAccountSwitch = true
        message = "Choose Continue with ChatGPT to add an account, or select a saved registration."
    }
    func selectSavedAccount(_ account: ChatGPTAccountRegistration) {
        guard !busy else { return }
        cancelSignIn()
        guard ChatGPTSessionVault.selectRegistration(account.clientID) else {
            message = "Unable to select the saved account securely."
            return
        }
        pendingAccountSwitch = true
        message = "Ready to reauthorize \(account.email ?? account.subject). Tap Continue with ChatGPT."
    }
    private func presentBrowser(_ url: URL) -> Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let root = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else { return false }
        var presenter = root
        while let current = presenter.presentedViewController { presenter = current }
        let browser = SFSafariViewController(url: url)
        browser.dismissButtonStyle = .close
        safariController = browser
        let delegate = SignInBrowserDelegate { [weak self] in
            Task { @MainActor in self?.cancelSignIn() }
        }
        safariDelegate = delegate
        browser.delegate = delegate
        presenter.present(browser, animated: true)
        return true
    }
    func signOut() {
        // Prevent a pending browser callback/token exchange from signing the
        // user back in *after* they chose to sign out.
        cancelSignIn()
        // Explicit local-only sign-out. For remote invalidation select Disconnect.
        ChatGPTSessionVault.clearTokens()
        session = nil
        pendingAccountSwitch = false
        message = "Signed out locally. Remote revocation has not been confirmed."
    }
    func disconnect() async {
        guard !busy else { return }
        guard let current = session, let refresh = current.refreshToken else {
            signOut()
            return
        }
        busy = true
        defer { busy = false }
        var remotelyRevoked = false
        do {
            let discoveryURL = URL(string: "https://auth.openai.com/.well-known/openid-configuration")!
            let (data, response) = try await URLSession.shared.data(from: discoveryURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let document = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let endpoint = document["revocation_endpoint"] as? String,
                  let uri = URL(string: endpoint), uri.scheme == "https", uri.host == "auth.openai.com" else {
                throw SignInFailure.server("OpenAI revocation endpoint unavailable.")
            }
            var request = URLRequest(url: uri)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = formEncoded([
                "token": refresh, "token_type_hint": "refresh_token", "client_id": current.clientID
            ])
            let (_, result) = try await URLSession.shared.data(for: request)
            remotelyRevoked = (result as? HTTPURLResponse)?.statusCode == 200
        } catch {
            // Keep failure detail generic. No secrets or refresh tokens in diagnostics.
        }
        ChatGPTSessionVault.clearTokens()
        session = nil
        pendingAccountSwitch = false
        message = remotelyRevoked
            ? "Session revoked and local credentials removed."
            : "Signed out locally, but remote revocation was not confirmed. Disconnect this app in ChatGPT Settings."
    }
    func signIn() async {
        guard !busy else { return }
        let thisAttempt = UUID()
        loginAttempt = thisAttempt
        busy = true
        defer {
            busy = false
            callback = nil
            safariController?.delegate = nil
            safariController?.dismiss(animated: true)
            safariController = nil
            safariDelegate = nil
        }
        phase = "Preparing secure browser sign-in"
        let listener = LoopbackCallback()
        callback = listener
        do {
            try await listener.start()
            guard loginAttempt == thisAttempt else { throw SignInFailure.cancelled }
            phase = "Waiting for browser authorization"
            let state = try randomURLSafe(), nonce = try randomURLSafe(), verifier = try randomURLSafe(64)
            let digest = Data(SHA256.hash(data: Data(verifier.utf8)))
            let challenge = digest.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
            let chosenRegistration = ChatGPTSessionVault.registration()
            let attemptClientID = OAuthAccountSwitchPolicy.credentialClientID(
                active: session?.clientID, selected: chosenRegistration?.clientID,
                switching: pendingAccountSwitch)
            // When an existing login remains active during account switching,
            // it must not leak its ID-token hint or client binding into the
            // *new* account's browser authorization.
            let saved: ChatGPTSession? = session?.clientID == attemptClientID ? session : nil
            let registered = chosenRegistration?.clientID == attemptClientID ? chosenRegistration : nil
            listener.arm(expectedState: state)
            let authURL = try OAuthAuthorizationBuilder.makeURL(
                callbackURI: listener.redirectURI,
                clientID: attemptClientID,
                hostID: try ChatGPTSessionVault.hostID(),
                state: state, nonce: nonce, codeChallenge: challenge,
                retainedIDToken: saved?.idToken,
                appName: "OpenChat16")
            // Keep the app foreground with SafariServices so the loopback listener isn't
            // immediately suspended. This is still experimental for Google/passkeys.
            guard presentBrowser(authURL) else { throw SignInFailure.cancelled }
            let expiry = Task { [weak listener] in
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                listener?.stop(SignInFailure.backgroundExpired)
            }
            defer { expiry.cancel() }
            let result = try await listener.wait()
            guard loginAttempt == thisAttempt else { throw SignInFailure.cancelled }
            let args = URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems ?? []
            func query(_ key: String) -> String? { args.first(where: { $0.name == key })?.value }
            guard query("state") == state else { throw SignInFailure.invalidState }
            if let error = query("error") { throw SignInFailure.server("Authorization was declined: \(error)") }
            guard let code = query("code") else { throw SignInFailure.malformedCallback }
            guard let issued = attemptClientID ?? query("client_id"),
                  issued != "dynamic_agent_client" else { throw SignInFailure.missingRegistration }
            if saved != nil || registered != nil {
                if let fromCallback = query("client_id"), fromCallback != issued { throw SignInFailure.invalidState }
            }
            phase = "Exchanging authorization code"
            let body = formEncoded([
                "grant_type": "authorization_code", "client_id": issued, "code": code,
                "code_verifier": verifier, "redirect_uri": listener.redirectURI, "resource": SignInConstants.resource
            ])
            var request = URLRequest(url: URL(string: SignInConstants.token)!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            let (data, response) = try await URLSession.shared.data(for: request)
            guard loginAttempt == thisAttempt else { throw SignInFailure.cancelled }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw SignInFailure.server("Token exchange failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)).")
            }
            let tokens = try JSONDecoder().decode(TokenReply.self, from: data)
            guard tokens.token_type.caseInsensitiveCompare("Bearer") == .orderedSame,
                  !tokens.access_token.isEmpty, tokens.expires_in > 0 else {
                throw SignInFailure.invalidToken
            }
            phase = "Verifying account identity"
            let identity = try await IdentityValidator.validate(idToken: tokens.id_token, clientID: issued, nonce: nonce)
            guard loginAttempt == thisAttempt else { throw SignInFailure.cancelled }
            if let saved = saved, saved.subject != identity.0 { throw SignInFailure.invalidToken }
            if let registered = registered, registered.subject != identity.0 { throw SignInFailure.invalidToken }
            let newSession = ChatGPTSession(clientID: issued, subject: identity.0, email: identity.1,
                accessToken: tokens.access_token, refreshToken: tokens.refresh_token, idToken: tokens.id_token,
                scopes: tokens.scope, expiresAt: Date().addingTimeInterval(TimeInterval(tokens.expires_in)))
            guard ChatGPTSessionVault.saveRegistration(clientID: issued, subject: identity.0,
                                                      email: identity.1),
                  ChatGPTSessionVault.save(newSession) else {
                throw SignInFailure.server("Could not securely save the ChatGPT session in Keychain.")
            }
            session = newSession
            AuthBillingChoice.select(.chatgptPlan)
            pendingAccountSwitch = false
            phase = "Signed in"
            message = newSession.canUsePlan ? "ChatGPT account connected." : "Signed in; plan access wasn't granted."
        } catch {
            phase = "Authorization did not complete"
            message = error.localizedDescription
            listener.stop()
        }
    }
}

// Credential selection: an explicitly connected ChatGPT plan is never silently billed
// through the user's fallback API key on OAuth authorization failures.
actor ChatGPTCredentialProvider {
    static let shared = ChatGPTCredentialProvider()
    private var inFlightRefresh: (id: UUID, snapshot: OAuthSessionSnapshot,
                                   task: Task<String, Error>)?

    private struct RefreshReply: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int
        let scope: String?
    }
    private struct ErrorReply: Decodable {
        struct Detail: Decodable { let code: String? }
        let error: Detail?
    }

    func token() async throws -> String? {
        // An explicit ChatGPT route cannot silently fall back to API-key
        // billing after sign-out, revocation or a refresh-token failure.
        guard AuthBillingChoice.route == .chatgptPlan else { return nil }
        guard let saved = ChatGPTSessionVault.load() else {
            throw SignInFailure.server("Sign in with ChatGPT, or explicitly switch to API-key billing in Settings.")
        }
        guard saved.canUsePlan else { throw SignInFailure.noPlanPermission }
        if saved.expiresAt.timeIntervalSinceNow > 120 { return saved.accessToken }
        // Only join the refresh for this *exact* credential generation.
        // A switch to a different account must never receive the previous token.
        if let inFlight = inFlightRefresh, inFlight.snapshot == saved.snapshot {
            let token = try await inFlight.task.value
            guard OAuthSessionSafety.mayReturnRefreshedToken(token, clientID: saved.clientID,
                    subject: saved.subject, current: ChatGPTSessionVault.load()?.snapshot) else {
                throw SignInFailure.cancelled
            }
            return token
        }
        let refreshID = UUID()
        let task = Task { try await self.performRefresh(saved) }
        inFlightRefresh = (id: refreshID, snapshot: saved.snapshot, task: task)
        defer {
            if inFlightRefresh?.id == refreshID { inFlightRefresh = nil }
        }
        let token = try await task.value
        guard OAuthSessionSafety.mayReturnRefreshedToken(token, clientID: saved.clientID,
                subject: saved.subject, current: ChatGPTSessionVault.load()?.snapshot) else {
            throw SignInFailure.cancelled
        }
        return token
    }

    private func performRefresh(_ old: ChatGPTSession) async throws -> String {
        guard let refreshToken = old.refreshToken else {
            throw SignInFailure.server("Sign in again to renew ChatGPT access.")
        }
        var request = URLRequest(url: URL(string: SignInConstants.token)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "grant_type": "refresh_token", "refresh_token": refreshToken,
            "client_id": old.clientID, "resource": SignInConstants.resource
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SignInFailure.invalidToken }
        guard http.statusCode == 200 else {
            let code = (try? JSONDecoder().decode(ErrorReply.self, from: data))?.error?.code
            let unrecoverable: Set<String> = ["invalid_grant", "invalid_refresh_token",
                "token_expired", "refresh_token_expired", "refresh_token_invalidated", "refresh_token_reused"]
            if let code = code, unrecoverable.contains(code) {
                // Clear only the refresh token that actually failed. An account
                // switch or newer token rotation must not be erased.
                if ChatGPTSessionVault.clearTokens(ifCurrent: old) {
                    throw SignInFailure.server("ChatGPT authorization expired. Sign in again.")
                }
                throw SignInFailure.cancelled
            }
            throw SignInFailure.server("ChatGPT refresh failed (HTTP \(http.statusCode)). Try again later.")
        }
        let reply = try JSONDecoder().decode(RefreshReply.self, from: data)
        // This OAuth integration uses rotating refresh tokens. A successful
        // response that omits the replacement token must not silently keep
        // using the old one, which might already have been invalidated.
        guard !reply.access_token.isEmpty, reply.expires_in > 0,
              let newRefreshToken = reply.refresh_token, !newRefreshToken.isEmpty else {
            throw SignInFailure.invalidToken
        }
        guard OAuthSessionSafety.canRotate(expected: old.snapshot,
              current: ChatGPTSessionVault.load()?.snapshot) else {
            // A sign-out/account-switch during the network call must not reinstate a session.
            throw SignInFailure.cancelled
        }
        let updated = ChatGPTSession(clientID: old.clientID, subject: old.subject,
            email: old.email, accessToken: reply.access_token,
            refreshToken: newRefreshToken,
            // Retain the *validated* prior ID token; new ID-token claims from a
            // refresh must not be accepted without their own signature validation.
            idToken: old.idToken, scopes: reply.scope ?? old.scopes,
            expiresAt: Date().addingTimeInterval(TimeInterval(reply.expires_in)))
        guard updated.canUsePlan else { throw SignInFailure.noPlanPermission }
        guard ChatGPTSessionVault.rotateTokens(ifCurrent: old, updated: updated) else {
            // Could also mean sign-out or a newer refresh replaced these credentials.
            throw SignInFailure.cancelled
        }
        return updated.accessToken
    }
}
