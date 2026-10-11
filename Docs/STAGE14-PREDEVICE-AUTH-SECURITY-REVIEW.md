# Stage 14 — Third-party OAuth review before device testing

**Scope:** Stage 13 independent iOS 16 source, plus public OpenAI SIWC documentation and **direct string-presence scan of user-provided 2024 and 2026 ChatGPT.framework binaries**. No actual account sign-in, network token exchange, Xcode build, or iPhone test occurred in this review.

## Evidence (do not mistake names for source code)

`Forensics/STAGE14-OFFICIAL-FRAMEWORK-IDENTIFIERS.json` records exact string counts in the executable bytes. In the 2026 compiled framework, `NativeAuthPasskey` occurs 21 times, `NativeAuthUsernamelessPasskeyLoginCoordinator` 5, and `ASWebAuthenticationSession` 22. The first two were absent in the scanned 2024 compiled framework, but `ASWebAuthenticationSession` is also referenced in 2024. The 2026 framework also references `CalpicoConversationsRepository`, `FileCalpicoConversationsCache` and `/backend-api`.

**What that does NOT prove:** any specific invocation of these classes, permission to use first-party backend endpoints, Google's behavior in an embedded browser, which passkey implementation the app uses, or availability of the official app's source code. Presence/absence of readable identifier strings is not proof of complete feature presence/absence.

## Findings and actual source corrections

| Severity | Earlier Stage 13 issue | Stage 14 change | Residual risk |
|---|---|---|---|
| High | Switching ChatGPT accounts permanently cleared the single saved issued client registration | Keychain `registrations-v2` preserves multiple **validated registrations**, including migration from the old record; UI lets user reauthorize one | Only **one active token session** retained, not full parallel signed-in accounts |
| High | Selecting a different account or dismissing consent cleared an otherwise-working session | Old session stays in Keychain during the pending browser flow; client ID and ID-token hints are bound to the selected registration only; commit after identity validation | Must confirm multi-account browser behavior on iOS 16 hardware |
| High | A revoked/expired OAuth session could fall through to a previously saved API key on a later request | Explicit non-secret billing-route preference; OAuth route fails closed until the user manually chooses API-key billing | Confirm billing prompts and model picker manually |
| High | A successful refresh lacking replacement refresh token could silently reuse an invalidated old token | Require a nonempty replacement refresh token; reject malformed refresh response | Live server behavior still pending |
| Medium | App could display stale model catalog after account switch or successful login | Invalidate previous model lookup generations; fetch once OAuth transaction completes | Confirm server model lists and model selection on device |
| Medium | Saving a new API key deleted the old one before checking replacement write | Keychain update-in-place, WhenUnlockedThisDeviceOnly for new credentials | Keychain migration and old item accessibility need device review |
| High | Old rotating refresh response could be applied after sign-out / account switch with the same subject/client ID | Compare-and-swap on **complete token generation** under an in-process lock; reject stale refresh completions | Needs live server and Keychain tests |
| High | A waiting refresh could return a prior account's bearer after account switch | In-flight requests keyed by full credential snapshot, result checked against current session before return | Swift actor and actual network behavior untested |
| High | Canceling after browser callback but during network exchange could still store an account | Per-attempt generation guards after each awaited operation; cancellation invalidates the attempt | Closing a browser on iOS still requires device exercise |
| Medium | `LoopbackCallback.start()` blocked the main actor up to 5 sec with a semaphore | Asynchronous `NWListener` readiness with single-resume continuation and 8-second startup limit | Network.framework exact iOS 16 runtime behavior unproven |
| Medium | CSPRNG failure fell back to a short UUID instead of failing | Fail closed rather than silently weaken state, nonce, and PKCE verifier generation | OS CSPRNG availability assumed |
| Medium | JWT claim validation didn't account for an OIDC multi-audience `azp` requirement | Added pure `OAuthIDClaims` validation with issuer, audience, azp, nonce, exp, nbf and iat; RSA verification remains in iOS Security implementation | JWKS/ID token signature verification still untested on iPhone |
| Medium | A callback-issued but **unverified** client ID persisted for the next login attempt | Removed pending-issued-client reuse; reuse only registrations saved after ID token validation | Interrupted first-time consent may require registering again |
| Medium | Existing Keychain token accessibility was weaker | New items use `WhenUnlockedThisDeviceOnly`, best-effort migration for old records | Actual Keychain update behavior needs an iOS test |
| Low | Authentication errors were opaque to the user | Added non-secret phase labels to the Settings interface | Browser itself may still show user-facing provider errors |
| Low | First-time registration app label resembled official ChatGPT app | `OpenChat16` app display name and dynamic agent name | Branding/UI assets still need independent audit |

## Authentication protocol vs browser reality

OpenAI's open-source flow requires `http://127.0.0.1:<port>/auth/callback` **exactly** in authorization and token exchange; dynamic first registration uses `client_id=dynamic_agent_client`, and the issued ID is saved after validated successful sign-in. It uses `state`, `nonce`, PKCE S256 and OpenAI-signed ID-token verification. This is **not** the same as logging into a proprietary first-party ChatGPT session.

Google documents `SFSafariViewController` as a supported option for OAuth, but **Google acceptance in isolation does not prove** the OpenAI page or iOS 16 callback listener works end-to-end. Apple `ASWebAuthenticationSession` is the preferred system OAuth abstraction, but a custom-scheme callback does **not** meet this OpenAI flow's documented HTTP loopback redirect requirement. Our provisional `SFSafariViewController` + localhost listener is a compatibility hypothesis awaiting a device test; it is **not marked working**.

Native account passkeys remain OpenAI-owned on OpenAI's authenticated origin. The `LocalAuthentication` Touch ID app lock is separate from an account passkey.

## Platform and authorization boundaries

- The third-party OAuth scopes authorize identity and, if separately granted, **eligible Responses API requests** using the user's ChatGPT plan. They **do not grant** existing ChatGPT cloud conversations or account memory. The official app's first-party history repository is evidence that the *first-party* app has access, not that our third-party token does.
- The API's `/v1/conversations` is **not** the ChatGPT sidebar/history service. Stage 13's user-export import is still an offline fallback.
- Public Responses API HTTP requests using ChatGPT plan tokens require `store:false` and `stream:true`; other endpoints or hidden first-party session cookies are not substituted.
- Source never captures Google passwords, OpenAI session cookies or private Apple/ChatGPT signing identities.
- API keys and ChatGPT OAuth tokens are distinct. A denied plan grant must not silently charge the user's API key; Stage 14 exposes an explicit API-key alternative.

## Still blocking a release

**P0 before rollout:** (1) Xcode iOS 16 typecheck/build, (2) loopback `NWListener` binding and callback within the iOS 16 Safari container, (3) Google and passkey paths if offered, (4) Keychain update + sign-out race on real hardware, (5) token refresh and plan-authorized streaming response, (6) consent and rate-limit errors, (7) verify product identity/terms/eligibility, (8) iPhone 8 Plus performance.

**P1:** multi-account **token** persistence vs registrations-only, account-aware model picker invalidation, accessibility, VoiceOver, advanced attachment safety, app-switcher privacy, large ChatGPT history exports (64MB JSON can cause peak memory spikes), full source/build reproducibility. None of these are claimed solved by code parsing.

## Review only, not an iPhone test

Portable code regression checks now cover 62 assertions (expanded previous portable checks), including account registration retention, session generation refresh races, and OIDC audience/authorized-party validation. `Scripts/preflight.sh` runs them and parses app Swift source. This is **not** Xcode type checking or device functionality verification.

### Official references (public documentation)

- https://developers.openai.com/siwc/token-sharing-open-source/sign-in
- https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions
- https://developers.openai.com/siwc/token-sharing-open-source/token-reference
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations
- https://developers.google.com/identity/protocols/oauth2/native-app
- https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession
- https://openai.com/policies/sign-in-with-chatgpt-terms/

## Additional static-review findings and constraints (2026-10-09)

1. **Account switching:** An already-working ChatGPT plan token remains active while the new registration is in the browser. `pendingAccountSwitch` changes client-ID binding only for the pending OAuth transaction; a token is committed only after a verified identity and consent. App termination mid-switch currently loses the pending UI selection; this is not a credential leak.
2. **Explicit billing:** `AuthBillingChoice` stores only a nonsecret route preference. API-key billing is never used automatically after an OAuth session is removed or its refresh fails. Saving an API key while signed out explicitly chooses the API route. Saving a backup key while ChatGPT is connected does not switch routes.
3. **Token shape:** The authorization-code token reply must identify `Bearer`; refresh must return a new token set. If a token response is incomplete, fail rather than guessing a credential or silently falling back.
4. **Model-cache race:** Model lists belong to the selected account. An older asynchronous request result is discarded after account change; fetch is triggered when browser authorization ends, not before its tokens are committed.
5. **Keychain:** API keys and OAuth tokens are independent ThisDeviceOnly keychain entries. Existing keys are not deleted before an update. Keychain persistence, migration and device lock accessibility require real-device testing.
6. **Google/passkeys:** Google explicitly permits `SFSafariViewController` as a secure browser choice; this is support for the *browser class*, not proof the OpenAI → Google → localhost round-trip is successful on iOS 16. Native passkeys remain under OpenAI's origin, not a fake in-app passkey API.
7. **First-party history:** Readable `/backend-api` identifiers in the decrypted official client do not authorize using its private protocol or obtaining official cookies in this reconstruction. SIWC plan scopes grant eligible Responses API access, not the first-party ChatGPT sidebar.
8. **Not a full compiler test:** `swiftc -frontend -parse` verifies grammar, while portable pure-Swift code builds and runs with the Linux toolchain. Neither substitutes for Xcode's iOS SDK typechecking or an iPhone installation.

**Additional authoritative references:**
- https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery
- https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions
- https://developers.openai.com/siwc/token-sharing-open-source/token-reference
- https://developers.google.com/identity/protocols/oauth2/javascript-implicit-flow
