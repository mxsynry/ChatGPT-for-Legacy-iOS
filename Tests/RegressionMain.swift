import Foundation

// Linux/macOS-compatible stand-in for the app's model: only for testing
// the pure parser, not for shipping in the iOS app target.
struct ChatMessage {
    let role: String
    let text: String
    let imageDataURL: String?
    let isInterrupted: Bool
    init(role: String, text: String, imageDataURL: String? = nil, isInterrupted: Bool = false) {
        self.role = role; self.text = text; self.imageDataURL = imageDataURL
        self.isInterrupted = isInterrupted
    }
}

// Pure branch-navigation tests need only the subset of the app model
// used by BranchNavigation, avoiding UIKit/SwiftUI dependencies on Linux.
struct LocalConversation {
    let id: UUID
    let title: String
    let branchMode: LocalBranchMode
    let modelID: String?
    let isTemporary: Bool
    let branchedFrom: BranchProvenance?
}

@main struct RegressionTests {
    private static var passed = 0
    private static func check(_ value: @autoclosure () -> Bool, _ reason: String) {
        if !value() { fputs("FAIL: \(reason)\n", stderr); exit(1) }
        passed += 1
    }
    static func main() throws {
        let port: UInt16 = 40789
        let validURL = URL(string: "http://127.0.0.1:40789/auth/callback?state=secure123&code=a1&client_id=oaiapp_123")!
        check(OAuthCallbackSafety.classify(validURL, expectedState: "secure123", port: port) == .authorizationCode("a1", "oaiapp_123"), "valid OAuth callback")
        check(OAuthCallbackSafety.classify(URL(string: "http://127.0.0.1:40789/evil?state=secure123&code=good")!, expectedState: "secure123", port: port) == .ignore, "wrong callback path ignored")
        check(OAuthCallbackSafety.classify(URL(string: "https://127.0.0.1:40789/auth/callback?state=secure123&code=good")!, expectedState: "secure123", port: port) == .ignore, "wrong callback scheme ignored")
        check(OAuthCallbackSafety.classify(URL(string: "http://127.0.0.1:40789/auth/callback?state=secure123&error=access_denied&code=good")!, expectedState: "secure123", port: port) == .ignore, "conflicting success and error ignored")
        check(OAuthCallbackSafety.classify(URL(string: "http://127.0.0.1:40789/auth/callback?state=secure123&client_id=oaiapp_123")!, expectedState: "secure123", port: port) == .ignore, "missing authorization code ignored")
        check(OAuthCallbackSafety.classify(validURL, expectedState: "other", port: port) == .ignore, "reject unsolicited state")
        check(OAuthCallbackSafety.classify(URL(string: "http://localhost:40789/auth/callback?state=secure123&code=a1")!, expectedState: "secure123", port: port) == .ignore, "reject localhost alias")
        check(OAuthCallbackSafety.classify(URL(string: "http://127.0.0.1:40790/auth/callback?state=secure123&code=a1")!, expectedState: "secure123", port: port) == .ignore, "reject wrong port")
        check(OAuthCallbackSafety.classify(URL(string: "http://127.0.0.1:40789/auth/callback?state=secure123&state=secure123&code=a1")!, expectedState: "secure123", port: port) == .ignore, "reject duplicate state")
        check(OAuthCallbackSafety.classify(URL(string: "http://127.0.0.1:40789/auth/callback?state=secure123&code=a1&code=b2")!, expectedState: "secure123", port: port) == .ignore, "reject duplicate code")
        check(OAuthCallbackSafety.classify(URL(string: "http://127.0.0.1:40789/auth/callback?state=secure123&error=access_denied")!, expectedState: "secure123", port: port) == .denied("access_denied"), "process explicit denial")
        check(OAuthCallbackSafety.classify(URL(string: "http://127.0.0.1:40789/auth/callback?state=secure123&code=a1&client_id=dynamic_agent_client")!, expectedState: "secure123", port: port) == .ignore, "reject registration placeholder")
        let entropy = String(repeating: "x", count: 42)
        let firstURL = try OAuthAuthorizationBuilder.makeURL(
            callbackURI: "http://127.0.0.1:40789/auth/callback", clientID: nil,
            hostID: "urn:uuid:abc1234567890", state: entropy, nonce: entropy,
            codeChallenge: entropy, retainedIDToken: nil, appName: "Test iOS App")
        let firstItems = URLComponents(url: firstURL, resolvingAgainstBaseURL: false)!.queryItems!
        func first(_ name: String) -> String? { firstItems.first(where: { $0.name == name })?.value }
        check(firstURL.host == "auth.openai.com", "correct OpenAI authorization origin")
        check(first("client_id") == "dynamic_agent_client", "dynamic registration entrypoint")
        check(first("agent_name_hint") == "Test iOS App", "first registration agent name")
        check(first("redirect_uri") == "http://127.0.0.1:40789/auth/callback", "exact loopback redirect")
        check(first("code_challenge_method") == "S256", "PKCE S256 challenge")
        check(first("scope")!.contains("chatgpt.tokens.use.direct"), "explicit plan permission")
        let returningURL = try OAuthAuthorizationBuilder.makeURL(
            callbackURI: "http://127.0.0.1:50912/auth/callback", clientID: "oaiapp_issued123",
            hostID: "urn:uuid:abc1234567890", state: entropy, nonce: entropy,
            codeChallenge: entropy, retainedIDToken: "retained-id-token", appName: "Test iOS App")
        let returningItems = URLComponents(url: returningURL, resolvingAgainstBaseURL: false)!.queryItems!
        check(returningItems.first(where: { $0.name == "client_id" })?.value == "oaiapp_issued123", "reuse issued client")
        check(!returningItems.contains(where: { $0.name == "agent_name_hint" }), "do not reregister returning client")
        check(returningItems.first(where: { $0.name == "id_token_hint" })?.value == "retained-id-token", "id-token hint only for returning account")
        do {
            _ = try OAuthAuthorizationBuilder.makeURL(
                callbackURI: "https://evil.example/auth/callback", clientID: nil,
                hostID: "urn:uuid:abc1234567890", state: entropy, nonce: entropy,
                codeChallenge: entropy, retainedIDToken: nil, appName: "Test iOS App")
            check(false, "wrong redirect URI rejected")
        } catch { check(true, "wrong redirect URI rejected") }
        let request = ResponsesPayload(messages: [
            ChatMessage(role: "user", text: "look at this", imageDataURL: "data:image/jpeg;base64,AAAA"),
            ChatMessage(role: "assistant", text: "looks good"),
            ChatMessage(role: "user", text: "next")
        ], model: "test-model", webSearch: true)
        let encoded = try JSONEncoder().encode(request)
        let payload = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        check(payload["store"] as? Bool == false, "OAuth uses store=false")
        check(payload["stream"] as? Bool == true, "OAuth requires stream=true")
        let messages = payload["input"] as! [[String: Any]]
        let photoParts = messages[0]["content"] as! [[String: Any]]
        check(photoParts.last?["type"] as? String == "input_image", "image input multipart")
        check(messages[1]["content"] as? String == "looks good", "history assistant is a plain string")
        check(messages[2]["content"] as? String == "next", "text messages are plain strings")
        let tools = payload["tools"] as! [[String: Any]]
        check(tools[0]["type"] as? String == "web_search", "current web_search tool")
        let nodes: [String: Any] = [
            "head": ["parent": "assistant", "message": ["author": ["role": "assistant"], "content": ["parts": ["Current answer"]], "create_time": 5]],
            "assistant": ["parent": "user", "message": ["author": ["role": "assistant"], "content": ["parts": ["First answer"]], "create_time": 4]],
            "alternate": ["parent": "user", "message": ["author": ["role": "assistant"], "content": ["parts": ["Discarded alternate"]], "create_time": 9]],
            "user": ["parent": "root", "message": ["author": ["role": "user"], "content": ["parts": ["Hello"]], "create_time": 3]],
            "root": ["parent": NSNull(), "message": ["author": ["role": "system"], "content": ["parts": ["Hidden"]], "create_time": 2]]
        ]
        let example: [[String: Any]] = [["id": "convo_1", "title": "Example", "mapping": nodes, "current_node": "head", "update_time": 1000]]
        let json = try JSONSerialization.data(withJSONObject: example)
        let imported = try ChatGPTHistoryImporter.parse(json)
        check(imported.count == 1, "one imported chat")
        check(imported[0].sourceID == "convo_1", "preserve source identity")
        check(imported[0].messages.map(\.role) == ["user", "assistant", "assistant"], "follow active conversation branch")
        check(!imported[0].messages.contains(where: { $0.text == "Discarded alternate" }), "exclude alternate branch")
        check(imported[0].messages[0].text == "Hello", "retain user content")
        check(imported[0].updatedAt.timeIntervalSince1970 == 1000, "retain update time")
        do { _ = try ChatGPTHistoryImporter.parse(Data("{}".utf8)); check(false, "invalid JSON shape rejected") }
        catch HistoryImportError.invalidFormat { check(true, "invalid JSON shape rejected") }
        do { _ = try ChatGPTHistoryImporter.parse(Data(repeating: 65, count: ChatGPTHistoryImporter.maxBytes + 1)); check(false, "oversized import rejected") }
        catch HistoryImportError.tooLarge { check(true, "oversized import rejected") }

        // Stage 14: account registration selection and refresh-token race policy.
        let accountA = ChatGPTAccountRegistration(clientID: "client-A", subject: "sub-A", email: "a@example.com")
        let accountB = ChatGPTAccountRegistration(clientID: "client-B", subject: "sub-B", email: "b@example.com")
        let index = OAuthRegistrationIndex.upsert(accountB, in: OAuthRegistrationIndex.upsert(accountA, in: []))
        check(index.count == 2, "switching accounts preserves registrations")
        check(OAuthRegistrationIndex.selected("client-A", from: index)?.subject == "sub-A", "reconnect stored account by issued ID")
        check(OAuthRegistrationIndex.selected(nil, from: index) == nil, "new registration does not reuse existing account")
        check(OAuthRegistrationIndex.selected("unknown", from: index) == nil, "unknown registration is not silently chosen")
        check(OAuthRegistrationIndex.upsert(accountA, in: index).count == 2, "reconnecting does not duplicate registration")
        let old = OAuthSessionSnapshot(clientID: "client-A", subject: "sub-A", accessToken: "old-access", refreshToken: "old-refresh")
        let refreshed = OAuthSessionSnapshot(clientID: "client-A", subject: "sub-A", accessToken: "new-access", refreshToken: "new-refresh")
        let otherAccount = OAuthSessionSnapshot(clientID: "client-B", subject: "sub-B", accessToken: "other-access", refreshToken: "other-refresh")
        let replacedRefresh = OAuthSessionSnapshot(clientID: "client-A", subject: "sub-A", accessToken: "old-access", refreshToken: "rotated-refresh")
        check(OAuthSessionSafety.canRotate(expected: old, current: old), "same credential generation may rotate")
        check(!OAuthSessionSafety.canRotate(expected: old, current: otherAccount), "reject refresh after account switch")
        check(!OAuthSessionSafety.canRotate(expected: old, current: refreshed), "reject old refresh after rotation")
        check(!OAuthSessionSafety.canRotate(expected: old, current: replacedRefresh), "reject refresh-token mismatch")
        check(!OAuthSessionSafety.canRotate(expected: old, current: nil), "reject refresh after sign out")
        check(OAuthSessionSafety.mayReturnRefreshedToken("new-access", clientID: "client-A", subject: "sub-A", current: refreshed), "return only active refreshed bearer")
        check(!OAuthSessionSafety.mayReturnRefreshedToken("old-access", clientID: "client-A", subject: "sub-A", current: refreshed), "reject superseded access token")
        check(!OAuthSessionSafety.mayReturnRefreshedToken("new-access", clientID: "client-A", subject: "sub-A", current: otherAccount), "never return an old account bearer")
        let now = Date().timeIntervalSince1970
        func claims(_ audience: Any, _ azp: String? = nil) -> OAuthIDClaims? {
            var raw: [String: Any] = ["iss": "https://auth.openai.com", "aud": audience,
                "sub": "some-user", "nonce": "nonce-unique", "exp": now + 3600,
                "iat": now, "nbf": now - 10]
            if let azp = azp { raw["azp"] = azp }
            return OAuthIDClaims.parse(raw)
        }
        check(claims("client-A")?.isAcceptable(clientID: "client-A", nonce: "nonce-unique", now: now) == true, "valid single audience claims")
        check(claims("client-A")?.isAcceptable(clientID: "client-A", nonce: "wrong", now: now) == false, "reject mismatched nonce")
        check(claims(["client-A", "aud2"])?.isAcceptable(clientID: "client-A", nonce: "nonce-unique", now: now) == false, "multi-audience ID token requires authorized party")
        check(claims(["client-A", "aud2"], "client-A")?.isAcceptable(clientID: "client-A", nonce: "nonce-unique", now: now) == true, "multi-audience azp verified")
        check(claims("client-A", "client-B")?.isAcceptable(clientID: "client-A", nonce: "nonce-unique", now: now) == false, "reject mismatched azp")
        check(claims("client-B")?.isAcceptable(clientID: "client-A", nonce: "nonce-unique", now: now) == false, "reject audience confusion")
        var expired: [String: Any] = ["iss": "https://auth.openai.com", "aud": "client-A", "sub": "sub", "nonce": "nonce-unique", "exp": now - 1, "iat": now - 20]
        check(OAuthIDClaims.parse(expired)?.isAcceptable(clientID: "client-A", nonce: "nonce-unique", now: now) == false, "reject expired identity token")
        expired["exp"] = now + 3600
        expired["iat"] = now + 1000
        check(OAuthIDClaims.parse(expired)?.isAcceptable(clientID: "client-A", nonce: "nonce-unique", now: now) == false, "reject implausible future issue time")
        expired["iat"] = now
        expired["iss"] = "https://untrusted.example"
        check(OAuthIDClaims.parse(expired)?.isAcceptable(clientID: "client-A", nonce: "nonce-unique", now: now) == false, "reject incorrect OIDC issuer")

        check(OAuthAccountSwitchPolicy.credentialClientID(active: "old", selected: nil, switching: true) == nil,
              "new account must use dynamic registration")
        check(OAuthAccountSwitchPolicy.credentialClientID(active: "old", selected: "another", switching: true) == "another",
              "selected account overrides active client during a switch")
        check(OAuthAccountSwitchPolicy.credentialClientID(active: "old", selected: "another", switching: false) == "old",
              "normal reauthorization stays bound to active client")
        check(OAuthAccountSwitchPolicy.credentialClientID(active: nil, selected: "returning", switching: false) == "returning",
              "signed-out user can reauthorize saved registration")
        // Stage 15: Responses SSE citations, status events, and hostile URLs.
        let deltaJSON = #"{"type":"response.output_text.delta","delta":"Hello, world!"}"#
        if case .delta(let text) = ResponseStreamEvents.parse(deltaJSON) {
            check(text == "Hello, world!", "stream delta content")
        } else { check(false, "stream delta decoded") }
        let citationJSON = #"{"type":"response.output_text.annotation.added","annotation":{"type":"url_citation","url":"https://example.org/story","title":"Example story"}}"#
        if case .citation(let citation) = ResponseStreamEvents.parse(citationJSON) {
            check(citation.url == "https://example.org/story", "source URL preserved")
            check(citation.title == "Example story", "source title preserved")
        } else { check(false, "stream citation decoded") }
        let completedJSON = #"{"type":"response.completed","response":{"output":[{"content":[{"annotations":[{"type":"url_citation","url":"https://example.org/final","title":"Final"}]}]}]}}"#
        if case .completed(let links, _) = ResponseStreamEvents.parse(completedJSON) {
            check(links.count == 1, "completed response restores missing source annotations")
            check(links[0].title == "Final", "completed source retains title")
        } else { check(false, "completed event decoded") }
        let failedJSON = #"{"type":"response.failed","response":{"error":{"message":"Usage limit reached"}}}"#
        if case .failed(let reason) = ResponseStreamEvents.parse(failedJSON) {
            check(reason == "Usage limit reached", "stream terminal error is surfaced")
        } else { check(false, "response.failed detected") }
        if case .incomplete = ResponseStreamEvents.parse(#"{"type":"response.incomplete"}"#) {
            check(true, "incomplete is never a successful response")
        } else { check(false, "incomplete response detected") }
        check(ResponseCitation(url: "javascript:alert(1)", title: "x") == nil,
              "untrusted source URI scheme rejected")
        check(ResponseCitation(url: "file:///etc/passwd", title: "x") == nil,
              "local file URI rejected as source")
        check(ResponseCitation(url: "https://user:secret@site.test", title: "x") == nil,
              "credential-bearing source URI rejected")
        check(ResponseCitation(url: "https://site.test/path", title: nil)?.title == "site.test",
              "missing source title falls back to host")
        if case .ignore = ResponseStreamEvents.parse("not json") {
            check(true, "garbled event is ignored")
        } else { check(false, "garbled event must not be treated as success") }
        // Allow older stored conversations with no citation field to remain valid.
        let legacyCitation = try JSONDecoder().decode(ResponseCitation.self,
            from: Data(#"{"url":"https://example.org/old","title":"Old"}"#.utf8))
        check(legacyCitation.title == "Old", "citation serialization is portable")
        do {
            _ = try JSONDecoder().decode(ResponseCitation.self,
                from: Data(#"{"url":"javascript:alert(1)","title":"Unsafe"}"#.utf8))
            check(false, "unsafe URL must not load from local history")
        } catch { check(true, "unsafe URL rejected on decoding") }
        check(ResponseCitation(url: "http://127.0.0.1:8000/callback", title: "x") == nil,
              "local OAuth callback URL must not become a clickable citation")
        check(ResponseCitation(url: "https://site.test/", title: String(repeating: "A", count: 300))?.title.count == 140,
              "source title is length bounded")
        // Stage 16: do not hide a user's catalog models simply because the
        // default picker excludes "hidden" or "preview" visibility states.
        let planCatalog = Data(#"{"models":[{"slug":"gpt-a","display_name":"A","visibility":"list"},{"slug":"gpt-b","display_name":"B","visibility":"hidden"},{"slug":"gpt-c","display_name":"C","visibility":"preview"},{"slug":"gpt-a","display_name":"duplicate","visibility":"list"}]}"#.utf8)
        let allChoices = try ModelCatalog.decode(planCatalog)
        check(allChoices.count == 3, "catalog returns all distinct server model choices")
        check(ModelCatalog.filtered(allChoices, query: "", showOther: false).count == 1,
              "default view honors server's listed model choices")
        check(ModelCatalog.filtered(allChoices, query: "", showOther: true).count == 3,
              "advanced view shows all returned models")
        check(ModelCatalog.filtered(allChoices, query: "gpt-b", showOther: true).first?.displayName == "B",
              "search includes advanced model slugs")
        let apiCatalog = Data(#"{"data":[{"id":"model-z"},{"id":"model-a"}]}"#.utf8)
        let parsedAPIModels = try ModelCatalog.decode(apiCatalog)
        check(parsedAPIModels.map(\.id) == ["model-a", "model-z"],
              "API-key models do not use ChatGPT visibility semantics")
        let usageJSON = #"{"type":"response.completed","response":{"usage":{"input_tokens":120,"output_tokens":40,"total_tokens":160},"output":[]}}"#
        if case .completed(_, let usage) = ResponseStreamEvents.parse(usageJSON) {
            check(usage?.totalTokens == 160, "actual server token usage retained")
            check(usage?.inputTokens == 120 && usage?.outputTokens == 40, "usage breakdown retained")
        } else { check(false, "completed event carries server token usage") }
        let missingUsageJSON = #"{"type":"response.completed","response":{"output":[]}}"#
        if case .completed(_, let usage) = ResponseStreamEvents.parse(missingUsageJSON) {
            check(usage == nil, "missing usage never invents a token quota")
        } else { check(false, "completed event with missing usage valid") }
        // Stage 16: actual API failure codes control recovery, not speculative quota charts.
        let structuredError = Data(#"{"error":{"message":"Limit hit","code":"subscription_sharing_usage_limit_exceeded","param":null}}"#.utf8)
        let planLimit = BackendDiagnostic.parse(structuredError, status: 429, requestID: "req_test")
        check(planLimit.isPlanLimit, "plan-limit code triggers account usage action")
        check(planLimit.errorDescription?.contains("req_test") == true, "preserve request ID for diagnostics")
        check(planLimit.guidance?.contains("Settings") == true, "plan usage recovery guidance")
        let capabilityError = Data(#"{"error":{"message":"Not supported","code":"subscription_sharing_unsupported_capability","param":"tools"}}"#.utf8)
        let capability = BackendDiagnostic.parse(capabilityError, status: 400, requestID: nil)
        check(capability.isCapabilityIssue, "unsupported feature identifies the incompatible request")
        check(capability.parameter == "tools", "preserve unsupported parameter")
        let directError = Data(#"{"detail":"Direct admission unavailable"}"#.utf8)
        let admission = BackendDiagnostic.parse(directError, status: 503, requestID: nil)
        check(admission.message == "Direct admission unavailable", "parse direct-admission detail body")
        check(admission.code == nil, "do not invent a server error code")
        // Stage 17: message-anchored branching (not full-chat duplication).
        let firstMsg = UUID(), middleMsg = UUID(), lastMsg = UUID()
        let ids = [firstMsg, middleMsg, lastMsg]
        check(BranchPlanning.prefixCount(ids: ids, through: firstMsg) == 1,
              "branch from first user message retains that message only")
        check(BranchPlanning.prefixCount(ids: ids, through: middleMsg) == 2,
              "branch from selected assistant answer retains exact prefix")
        check(BranchPlanning.prefixCount(ids: ids, through: lastMsg) == 3,
              "branch from newest answer retains all available messages")
        check(BranchPlanning.prefixCount(ids: ids, through: nil) == 3,
              "header branch can explicitly use entire current thread")
        check(BranchPlanning.prefixCount(ids: ids, through: UUID()) == nil,
              "deleted/stale message branch must be rejected")
        check(BranchPlanning.prefixCount(ids: [], through: nil) == 0,
              "empty-conversation branching supported")
        check(BranchPlanning.title(parent: "Example", mode: .workStyle) == "Work branch · Example",
              "Work branch has an explicit mode label")
        check(LocalBranchMode.workStyle.instructions?.contains("structured") == true,
              "Work-style mode changes inference instructions")
        check(LocalBranchMode.chat.instructions == nil,
              "plain chat carries no extra agent instructions")
        check(BranchReasoning.automatic.apiValue == nil,
              "model-default reasoning does not force unsupported effort")
        check(BranchReasoning.xhigh.apiValue == "xhigh",
              "extra-high model effort can be selected explicitly")
        let workBranchPayload = ResponsesPayload(
            messages: [ChatMessage(role: "user", text: "Plan and build this")],
            model: "gpt-model-returned-by-server", webSearch: false,
            branchMode: .workStyle, reasoningEffort: .high)
        let workEncoded = try JSONEncoder().encode(workBranchPayload)
        let workObject = try JSONSerialization.jsonObject(with: workEncoded) as! [String: Any]
        check((workObject["instructions"] as? String)?.contains("structured") == true,
              "Work-style request actually includes mode instructions")
        check((workObject["reasoning"] as? [String: Any])?["effort"] as? String == "high",
              "branch reasoning effort is transmitted in Responses request")
        check(workObject["model"] as? String == "gpt-model-returned-by-server",
              "model choice is never rewritten locally")
        let normalPayload = ResponsesPayload(
            messages: [ChatMessage(role: "user", text: "Hi")],
            model: "chosen", webSearch: false)
        let normalObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(normalPayload)) as! [String: Any]
        check(normalObject["instructions"] == nil, "normal chat has no Work-style directive")
        check(normalObject["reasoning"] == nil, "normal chat doesn't specify reasoning effort")
        let provenance = BranchProvenance(parentConversationID: UUID(), parentMessageID: firstMsg, createdAt: Date())
        let provenanceData = try JSONEncoder().encode(provenance)
        let provenanceDecoded = try JSONDecoder().decode(BranchProvenance.self, from: provenanceData)
        check(provenanceDecoded == provenance, "branch provenance survives JSON persistence")
        // Stage 17: the only numeric usage gauge is backed by actual x-ratelimit
        // response headers and is never mistaken for ChatGPT plan capacity.
        let suppliedHeaders = [
            "X-RateLimit-Limit-Requests": "100",
            "x-ratelimit-remaining-requests": "24",
            "X-RateLimit-Reset-Requests": "3s",
            "x-ratelimit-limit-tokens": "30000",
            "X-Ratelimit-Remaining-Tokens": "15000"
        ]
        guard let limits = RateLimitHeaders.parse(suppliedHeaders) else {
            check(false, "parse actual request/token headers")
            return
        }
        check(limits.requests?.remaining == 24 && limits.requests?.limit == 100,
              "rate-limit counts are sourced from HTTP headers")
        check(limits.requests?.fractionRemaining == 0.24,
              "usage ring percentage is computed only from reported rate window")
        check(limits.requests?.resetText == "3s", "reset text remains a server string")
        check(limits.tokens?.fractionRemaining == 0.5, "token rate window is separate")
        check(RateLimitHeaders.parse([:]) == nil,
              "no limit header means no fabricated account percentage")
        check(RateLimitHeaders.parse(["x-ratelimit-remaining-requests":"50"]) == nil,
              "remaining alone is insufficient to infer percentage")
        check(RateLimitHeaders.parse(["x-ratelimit-limit-requests":"0",
                                       "x-ratelimit-remaining-requests":"0"]) == nil,
              "zero limit cannot generate a ring")
        check(RateLimitHeaders.parse(["x-ratelimit-limit-requests":"10",
                                       "x-ratelimit-remaining-requests":"-1"]) == nil,
              "negative allowance is not treated as usable")
        let oversizedRemain = RateLimitHeaders.parse([
            "x-ratelimit-limit-requests":"10", "x-ratelimit-remaining-requests":"25"])
        check(oversizedRemain?.requests?.fractionRemaining == 1,
              "rate window display clamps remaining values")
        // Header spelling may be duplicated by a network proxy; parsing must not crash.
        check(RateLimitHeaders.parse(["X-Ratelimit-Limit-Requests":"20",
                                       "x-ratelimit-limit-requests":"20",
                                       "x-ratelimit-remaining-requests":"10"]) != nil,
              "case-folded duplicate header keys do not crash")
        // Stage 18: alternate versions must be constrained to the exact fork.
        let parentID = UUID()
        let anchor = UUID()
        let otherAnchor = UUID()
        let childA = UUID()
        let childB = UUID()
        let parent = LocalConversation(id: parentID, title: "Original",
            branchMode: .chat, modelID: "model-a", isTemporary: false, branchedFrom: nil)
        let branchA = LocalConversation(id: childA, title: "First",
            branchMode: .chat, modelID: "model-b", isTemporary: false,
            branchedFrom: BranchProvenance(parentConversationID: parentID,
                                          parentMessageID: anchor, createdAt: Date(timeIntervalSince1970: 1)))
        let branchB = LocalConversation(id: childB, title: "Second",
            branchMode: .workStyle, modelID: "model-c", isTemporary: true,
            branchedFrom: BranchProvenance(parentConversationID: parentID,
                                          parentMessageID: anchor, createdAt: Date(timeIntervalSince1970: 2)))
        let elsewhere = LocalConversation(id: UUID(), title: "Other anchor",
            branchMode: .chat, modelID: nil, isTemporary: false,
            branchedFrom: BranchProvenance(parentConversationID: parentID,
                                          parentMessageID: otherAnchor, createdAt: Date(timeIntervalSince1970: 3)))
        let versionList = BranchNavigation.versions(sourceID: parentID, messageID: anchor,
            conversations: [elsewhere, branchB, parent, branchA])
        check(versionList.map(\.id) == [parentID, childA, childB],
              "show only parent and siblings at same message fork")
        check(versionList[2].mode == .workStyle && versionList[2].temporary,
              "version browser retains model/mode and temporary metadata")
        check(BranchNavigation.versions(sourceID: UUID(), messageID: anchor,
              conversations: [parent]).isEmpty, "deleted parent does not invent versions")
        // Stage 18: SSE collector works on fragmented and multiline event frames,
        // comment keepalives, EOF without a trailing blank line and limits.
        var frames = SSEFrameCollector()
        check((try? frames.consume(": heartbeat")) == nil, "ignore SSE keepalive")
        check((try? frames.consume("event: message")) == nil, "ignore non-data SSE field")
        check((try? frames.consume("data: {\"type\":")) == nil, "hold first data segment")
        check((try? frames.consume("data: \"response.completed\"}")) == nil, "hold second segment")
        let joined = try frames.consume("")
        check(joined == "{\"type\":\n\"response.completed\"}", "join multiline data fields")
        check(frames.finish() == nil, "do not replay consumed SSE event")
        check((try? frames.consume("data: {\"type\":\"response.completed\"}")) == nil, "hold EOF frame")
        check(frames.finish() == "{\"type\":\"response.completed\"}", "flush final SSE event at EOF")
        check((try? frames.consume("data: [DONE]")) == nil, "receive DONE marker")
        check((try? frames.consume("")) == "[DONE]", "emit DONE marker")
        var oversized = SSEFrameCollector()
        do {
            _ = try oversized.consume("data: " + String(repeating: "x", count: SSEFrameCollector.maxEventBytes + 1))
            check(false, "reject oversize SSE frame")
        } catch SSEFrameError.frameTooLarge {
            check(true, "reject oversize SSE frame")
        }
        // Stage 19: the original conversation lists forks from *every* anchor,
        // rather than hiding all non-nil-anchor branches.
        let atEnd = LocalConversation(id: UUID(), title: "At end", branchMode: .chat,
            modelID: "model-d", isTemporary: false,
            branchedFrom: BranchProvenance(parentConversationID: parentID,
                parentMessageID: nil, createdAt: Date(timeIntervalSince1970: 4)))
        let forkGroups = BranchNavigation.groupedForks(sourceID: parentID,
            conversations: [atEnd, elsewhere, branchB, parent, branchA])
        check(forkGroups.count == 3, "all three original-message fork points are visible")
        let anchored = forkGroups.first(where: { $0.anchorMessageID == anchor })
        check(anchored?.branches.map(\.id) == [childA, childB],
              "siblings at the same message fork remain ordered")
        check(forkGroups.first(where: { $0.anchorMessageID == nil })?.branches.map(\.id) == [atEnd.id],
              "end-of-conversation forks have their own group")
        check(BranchNavigation.groupedForks(sourceID: parentID,
            conversations: [branchB, branchA]).count == 1,
              "surviving branches stay navigable after original deletion")
        check(BranchNavigation.groupedForks(sourceID: UUID(),
            conversations: [parent, branchA]).isEmpty,
              "unrelated branches do not appear")
        let overflowing: [String: Any] = ["usage": ["input_tokens": Int.max,
            "output_tokens": 10]]
        check(ResponseUsage.parse(overflowing) == nil,
              "untrusted token counts never overflow Int")
        check(ResponseUsage.parse(["usage": ["input_tokens": 8,
            "output_tokens": 7, "total_tokens": 3]]) == nil,
              "reject inconsistent server total-token counts")
        var bomFrames = SSEFrameCollector()
        check((try? bomFrames.consume("\u{FEFF}data: test")) == nil,
              "SSE allows leading BOM")
        check((try? bomFrames.consume("")) == "test", "leading SSE BOM stripped")
        var hugeComment = SSEFrameCollector()
        do {
            _ = try hugeComment.consume(":" + String(repeating: "a", count: SSEFrameCollector.maxEventBytes + 1))
            check(false, "reject enormous non-data line")
        } catch SSEFrameError.frameTooLarge {
            check(true, "reject enormous non-data line")
        }
        var coalescer = StreamingTextBatcher()
        let baseline = Date(timeIntervalSince1970: 100)
        check(coalescer.push("H", now: baseline) == "H", "first streamed text appears instantly")
        check(coalescer.push("e", now: baseline.addingTimeInterval(0.01)) == nil,
              "rapid subsequent chunks are buffered")
        check(coalescer.push("llo", now: baseline.addingTimeInterval(0.02)) == nil,
              "buffer preserves delta ordering")
        check(coalescer.push("!", now: baseline.addingTimeInterval(0.08)) == "ello!",
              "batched text delivered without animation")
        check(coalescer.push("a", now: baseline.addingTimeInterval(0.09)) == nil,
              "batch accumulator resets after emission")
        check(coalescer.flush() == "a", "final pending delta flushed at stream completion")
        check(coalescer.flush() == nil, "no stale delta replay")
        // Stage 20: read-only loopback HTTP parsing must not accept a forged Host,
        // absolute-target routing or a malformed request line.
        let validGET = "GET /auth/callback?state=secure123&code=a1 HTTP/1.1\r\nHost: 127.0.0.1:40789\r\nUser-Agent: test\r\n\r\n"
        check(OAuthLoopbackHTTP.callbackURL(requestText: validGET, port: port)?.path == "/auth/callback",
              "valid loopback GET accepted")
        check(OAuthLoopbackHTTP.callbackURL(requestText: validGET.replacingOccurrences(of: "127.0.0.1:40789", with: "localhost:40789"), port: port) == nil,
              "reject host aliases and host poisoning")
        check(OAuthLoopbackHTTP.callbackURL(requestText: validGET.replacingOccurrences(of: "GET ", with: "POST "), port: port) == nil,
              "reject callback POST")
        check(OAuthLoopbackHTTP.callbackURL(requestText: validGET.replacingOccurrences(of: "HTTP/1.1", with: "HTTP/2"), port: port) == nil,
              "reject unsupported HTTP request line")
        let duplicateHost = validGET.replacingOccurrences(of: "User-Agent: test", with: "Host: attacker.invalid")
        check(OAuthLoopbackHTTP.callbackURL(requestText: duplicateHost, port: port) == nil,
              "reject duplicate Host headers")
        check(OAuthLoopbackHTTP.callbackURL(requestText: validGET.replacingOccurrences(of: "/auth/callback?", with: "/admin?"), port: port) == nil,
              "reject alternate callback path")
        check(OAuthLoopbackHTTP.callbackURL(requestText: validGET.replacingOccurrences(of: "GET /", with: "GET http://evil/"), port: port) == nil,
              "reject absolute-form request target")
        check(OAuthLoopbackHTTP.callbackURL(requestText: validGET.dropLast(4).description, port: port) == nil,
              "reject incomplete HTTP headers")
        let listTime = Date(timeIntervalSince1970: 1000)
        let pinnedEntry = ConversationListEntry(id: UUID(), title: "Pinned chat", updatedAt: listTime.addingTimeInterval(-90), pinned: true,
            archived: false, locked: false, searchableText: "blue sky")
        let regularEntry = ConversationListEntry(id: UUID(), title: "Recent chat", updatedAt: listTime, pinned: false,
            archived: false, locked: false, searchableText: "orange")
        let archivedEntry = ConversationListEntry(id: UUID(), title: "Older", updatedAt: listTime.addingTimeInterval(500), pinned: false,
            archived: true, locked: false, searchableText: "orange")
        let lockedEntry = ConversationListEntry(id: UUID(), title: "Locked conversation", updatedAt: listTime, pinned: false,
            archived: false, locked: true, searchableText: "private-secret")
        let entries = [regularEntry, archivedEntry, pinnedEntry, lockedEntry]
        check(ConversationListPolicy.visible(entries, filter: .recent, query: "").first?.id == pinnedEntry.id,
              "pinned conversations sort before recent ones")
        check(!ConversationListPolicy.visible(entries, filter: .recent, query: "").contains(where: { $0.id == archivedEntry.id }),
              "archived conversations hidden from recent")
        check(ConversationListPolicy.visible(entries, filter: .archived, query: "").map(\.id) == [archivedEntry.id],
              "archived filter only shows archived")
        check(ConversationListPolicy.visible(entries, filter: .pinned, query: "").map(\.id) == [pinnedEntry.id],
              "pinned filter works")
        check(ConversationListPolicy.visible(entries, filter: .recent, query: "sky").map(\.id) == [pinnedEntry.id],
              "unlocked contents are searchable")
        check(ConversationListPolicy.visible(entries, filter: .recent, query: "secret").isEmpty,
              "locked message text is never searched")
        check(ConversationListPolicy.visible(entries, filter: .recent, query: "locked").map(\.id) == [lockedEntry.id],
              "locked conversation has anonymous searchable label")
        let blocks = MarkdownSegments.split("Hello\n```swift\nprint(1)\n```\nBye")
        check(blocks == [.prose("Hello"), .code(language: "swift", text: "print(1)"), .prose("Bye")],
              "fenced code blocks become separate UI segments")
        check(MarkdownSegments.split("```python\nprint(1)") == [.code(language: "python", text: "print(1)")],
              "unfinished streaming fence stays in monospaced block")
        check(MarkdownSegments.split("plain") == [.prose("plain")], "plain text survives Markdown parser")
        check(MarkdownSegments.split("").isEmpty, "empty Markdown yields no blocks")
        check(MarkdownRenderCache.split("Hello\n```swift\nprint(1)\n```\nBye") == blocks,
              "cached Markdown matches uncached parser")
        check(MarkdownRenderCache.split("Hello\n```swift\nprint(1)\n```\nBye") == blocks,
              "Markdown cache repeat lookup is deterministic")
        MarkdownRenderCache.clear()
        check(MarkdownRenderCache.split("plain") == [.prose("plain")],
              "clearing Markdown cache does not alter rendering")
        let longProse = String(repeating: "UTF-8 café 🙂\n", count: 1000)
        check(MarkdownRenderCache.split(longProse) == MarkdownSegments.split(longProse),
              "large Unicode Markdown parses identically with the cache")
        check(ResponseCitation(url: "https://example.com/article", title: "Valid") != nil,
              "public HTTPS citation allowed")
        check(ResponseCitation(url: "http://example.com/path", title: "Bad") == nil,
              "unsecured citation URL is blocked")
        check(ResponseCitation(url: "https://127.1.2.3/private", title: nil) == nil,
              "loopback IP citation blocked")
        check(ResponseCitation(url: "https://192.168.1.4/private", title: nil) == nil,
              "private IP citation blocked")
        check(ResponseCitation(url: "https://somehost.local/private", title: nil) == nil,
              "local network DNS citation blocked")
        check(ResponseCitation(url: "https://user:pass@example.com", title: nil) == nil,
              "credential-bearing source URL blocked")
        let serverProgress = ResponseStreamEvents.parse("{\"type\":\"response.in_progress\"}")
        if case .progress(let status) = serverProgress {
            check(status == "Generating…", "in-progress SSE phase is surfaced")
        } else { check(false, "in-progress SSE phase is surfaced") }
        let toolProgress = ResponseStreamEvents.parse("{\"type\":\"response.output_item.added\",\"item\":{\"type\":\"web_search_call\"}}")
        if case .progress(let status) = toolProgress {
            check(status == "Searching web…", "web-search progress appears before text")
        } else { check(false, "web-search progress appears before text") }
        let interruptionFiltered = ResponsesPayload(messages: [
            ChatMessage(role: "user", text: "original prompt"),
            ChatMessage(role: "assistant", text: "partial output", isInterrupted: true),
            ChatMessage(role: "assistant", text: "full retry answer")
        ], model: "gpt-test", webSearch: false)
        let filteredJSON = String(data: try JSONEncoder().encode(interruptionFiltered), encoding: .utf8)!
        check(!filteredJSON.contains("partial output") && filteredJSON.contains("full retry answer"),
              "interrupted visible text excluded from later model context")
        print("PASS: \(passed) source regression checks")
    }
}
