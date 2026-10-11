import Foundation

// Pure, deterministic policies tested without Keychain, UIKit or network access.
struct ChatGPTAccountRegistration: Codable, Hashable, Identifiable {
    let clientID: String
    let subject: String
    var email: String?
    var id: String { clientID }
}

enum OAuthRegistrationIndex {
    static func upsert(_ item: ChatGPTAccountRegistration,
                       in records: [ChatGPTAccountRegistration]) -> [ChatGPTAccountRegistration] {
        var copy = records
        if let index = copy.firstIndex(where: { $0.clientID == item.clientID }) {
            copy[index] = item
        } else {
            copy.append(item)
        }
        return copy
    }
    static func selected(_ clientID: String?, from records: [ChatGPTAccountRegistration])
        -> ChatGPTAccountRegistration? {
        guard let clientID = clientID, !clientID.isEmpty else { return nil }
        return records.first(where: { $0.clientID == clientID })
    }
}

struct OAuthSessionSnapshot: Equatable {
    let clientID: String
    let subject: String
    let accessToken: String
    let refreshToken: String?
}

enum OAuthSessionSafety {
    static func canRotate(expected: OAuthSessionSnapshot, current: OAuthSessionSnapshot?) -> Bool {
        current == expected
    }
    static func mayReturnRefreshedToken(_ token: String, clientID: String,
                                        subject: String, current: OAuthSessionSnapshot?) -> Bool {
        guard let current = current else { return false }
        return current.clientID == clientID && current.subject == subject && current.accessToken == token
    }
}

struct OAuthIDClaims {
    let issuer: String
    let audience: [String]
    let authorizedParty: String?
    let subject: String
    let nonce: String
    let expiration: TimeInterval
    let notBefore: TimeInterval
    let issuedAt: TimeInterval

    static func parse(_ json: [String: Any]) -> OAuthIDClaims? {
        guard let issuer = json["iss"] as? String,
              let subject = json["sub"] as? String,
              let nonce = json["nonce"] as? String,
              let expiration = json["exp"] as? TimeInterval,
              let issuedAt = json["iat"] as? TimeInterval else { return nil }
        let aud: [String]
        if let singular = json["aud"] as? String { aud = [singular] }
        else if let multiple = json["aud"] as? [String] { aud = multiple }
        else { return nil }
        return .init(issuer: issuer, audience: aud,
                     authorizedParty: json["azp"] as? String,
                     subject: subject, nonce: nonce,
                     expiration: expiration,
                     notBefore: (json["nbf"] as? TimeInterval) ?? 0,
                     issuedAt: issuedAt)
    }
    func isAcceptable(clientID: String, nonce expectedNonce: String,
                      now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard issuer == "https://auth.openai.com", !subject.isEmpty,
              nonce == expectedNonce, expiration > now,
              notBefore <= now + 60, issuedAt <= now + 60,
              issuedAt >= now - 86_400, // reject wildly stale or malformed issued-at times
              audience.contains(clientID), !audience.isEmpty else { return false }
        // OIDC requires azp for multiple audiences. When present for a single audience,
        // it must still identify our exact issued client.
        if audience.count > 1 { return authorizedParty == clientID }
        if let authorizedParty = authorizedParty { return authorizedParty == clientID }
        return true
    }
}

// Portable policy for account-picker state. Browser consent must never
// invalidate the existing authenticated session before the replacement
// identity and issued client registration have been verified and committed.
enum OAuthAccountSwitchPolicy {
    static func credentialClientID(active: String?, selected: String?, switching: Bool) -> String? {
        switching ? selected : (active ?? selected)
    }
}
