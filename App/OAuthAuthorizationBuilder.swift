import Foundation

// Deliberately independent of UIKit/Network so request shape can be unit-tested.
enum OAuthAuthorizationBuilder {
    enum Failure: Error { case invalidCallback, invalidParameters }
    static let authorizeURL = URL(string: "https://auth.openai.com/api/accounts/authorize")!
    static let resource = "https://api.openai.com/v1"
    static let scope = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"

    static func makeURL(callbackURI: String, clientID: String?, hostID: String,
                        state: String, nonce: String, codeChallenge: String,
                        retainedIDToken: String?, appName: String) throws -> URL {
        guard let callback = URL(string: callbackURI), callback.scheme == "http",
              callback.host == "127.0.0.1", callback.port != nil,
              callback.path == "/auth/callback" else { throw Failure.invalidCallback }
        guard hostID.count >= 10, state.count >= 20, nonce.count >= 20,
              codeChallenge.count >= 40,
              appName.count >= 3 else { throw Failure.invalidParameters }
        let newRegistration = clientID == nil
        let client = clientID ?? "dynamic_agent_client"
        guard newRegistration || (client != "dynamic_agent_client" && !client.isEmpty) else {
            throw Failure.invalidParameters
        }
        var fields = [
            URLQueryItem(name: "client_id", value: client),
            URLQueryItem(name: "ext_agent_host_id", value: hostID),
            URLQueryItem(name: "redirect_uri", value: callbackURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "resource", value: resource),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge)
        ]
        if newRegistration {
            fields.append(URLQueryItem(name: "agent_name_hint", value: appName))
        } else if let retainedIDToken = retainedIDToken, !retainedIDToken.isEmpty {
            fields.append(URLQueryItem(name: "id_token_hint", value: retainedIDToken))
        }
        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = fields
        guard let url = components.url else { throw Failure.invalidParameters }
        return url
    }
}
