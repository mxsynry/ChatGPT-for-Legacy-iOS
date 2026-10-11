# Feature reconstruction matrix — iOS 16 target

Evidence levels:
- **Observed metadata** = framework/extension names extracted from user-provided official 2024/2026 IPA bundles.
- **Documented** = public vendor documentation, not proof that a particular private app implements it the same way.
- **Proposed** = our clean-room implementation choice.
- **Implemented** = source present in this repository, not necessarily device-tested.

| Feature | Evidence | iOS 16 implementation | State |
|---|---|---|---|
| Chat UI / local sidebar | App product behavior; our own scaffold | SwiftUI NavigationStack, local JSON | Implemented; uncompiled |
| API-key chat on mobile | Public OpenAI Responses API | User-provided key in iOS Keychain; URLSession; store=false | Implemented; uncompiled |
| ChatGPT/Google account login | Public browser sign-in flow; NOT inferable from IPA alone | ASWebAuthenticationSession + supported OAuth registration/PKCE after protocol verification | Planned; no misleading login button |
| Passkeys for OpenAI account | Public OpenAI Help Center documents account passkeys | OpenAI-owned authentication UI via system browser; do not register credentials for OpenAI's domain ourselves | Planned; delegated to identity provider |
| App lock with biometrics | Proposed app-local privacy feature | LocalAuthentication, LAContext, policy deviceOwnerAuthentication | Planned; separate from OpenAI account passkeys |
| Secure credential storage | Apple Keychain | ThisDeviceOnly Keychain item; no UserDefaults secrets | Implemented for API key |
| Privacy controls | Public product concept; not evidence of private implementation | Local history delete, opt-in analytics, redaction, data retention settings | Planned |
| Temporary chat | Product concept | Do not persist local conversation when enabled; API store=false | Planned; store=false alone is not full temporary-chat semantics |
| Streaming without fade | User requirement | URLSession SSE; direct text updates without animation | Planned; current request is nonstreaming |
| Attachments | 2026 IPA contains relevant extension names | UIDocumentPicker, security-scoped file access | Planned |
| Voice / realtime | 2026 IPA framework metadata: LiveKitWebRTC | AVAudioSession/AVAudioEngine; public realtime API if available | Planned |
| Share extension | 2026 IPA extension metadata | iOS Share Extension target | Planned |
| Passkey registration for *our own* service | Proposed optional future | AuthenticationServices WebAuthn with associated domains and server challenge | Not appropriate until we own a service/domain |
| API provider profiles | Gopeed-inspired extensible transport | Provider protocol, secure per-provider credentials, permissions | Planned |

Do not confuse API-key authorization with ChatGPT subscription login. API-key billing and ChatGPT account/plan access are different mechanisms.

## Security acceptance tests
1. No credentials in logs, JSON conversation storage, screenshots or error strings.
2. Removing the API key deletes the Keychain item; fresh app starts unauthenticated.
3. TLS uses default URLSession trust validation; no certificate bypass.
4. A request failure must not append a fabricated assistant message.
5. Changing conversations during a request must not insert the response into the wrong conversation.
6. A malicious imported conversation cannot execute code.
7. OAuth requires issuer, audience, state, nonce, PKCE and signed token validation; never use embedded WebView password capture.
8. Passkey UI must remain on the OpenAI-owned sign-in origin, not spoofed in our app.
9. Validate privacy behavior under app backgrounding, crash and device lock.
10. Verify iOS 16.7.16 on real hardware, including TrollStore packaging, before claiming compatibility.
