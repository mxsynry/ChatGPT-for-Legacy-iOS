import Foundation

// Pure Foundation policy: can be regression-tested without a simulator or secrets.
enum OAuthCallbackOutcome: Equatable {
    case ignore
    case authorizationCode(String, String?)
    case denied(String)
}

enum OAuthCallbackSafety {
    static func classify(_ callbackURL: URL, expectedState: String, port: UInt16) -> OAuthCallbackOutcome {
        guard callbackURL.scheme == "http",
              callbackURL.host == "127.0.0.1",
              callbackURL.port == Int(port),
              callbackURL.path == "/auth/callback",
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return .ignore }
        let stateValues = items.filter { $0.name == "state" }
        // An unsolicited request must never consume a pending OAuth login.
        guard stateValues.count == 1, stateValues[0].value == expectedState else { return .ignore }
        let codes = items.filter { $0.name == "code" }
        let errors = items.filter { $0.name == "error" }
        if errors.count == 1, codes.isEmpty {
            return .denied(String((errors[0].value ?? "authorization_denied").prefix(100)))
        }
        guard errors.isEmpty, codes.count == 1,
              let code = codes[0].value, !code.isEmpty, code.count <= 4096 else { return .ignore }
        let issuedIDs = items.filter { $0.name == "client_id" }
        guard issuedIDs.count <= 1 else { return .ignore }
        let issuedID = issuedIDs.first?.value
        guard issuedID == nil || (issuedID != "dynamic_agent_client" &&
                                   !(issuedID ?? "").isEmpty && (issuedID ?? "").count <= 512) else { return .ignore }
        return .authorizationCode(code, issuedID)
    }
}
