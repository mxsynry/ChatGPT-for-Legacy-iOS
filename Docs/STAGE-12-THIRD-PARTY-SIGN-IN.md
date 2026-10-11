# Stage 12 — third-party Continue with ChatGPT first

## Implemented in source (not yet device-validated)

- "Continue with ChatGPT" Settings action; opens **OpenAI's own** authorize page in Safari.
- On OpenAI's page, the user may authenticate with Google, a passkey, or other available OpenAI methods (subject to provider browser restrictions). The app itself must never collect Google passwords/passkeys.
- Open-source dynamic OAuth registration (`dynamic_agent_client`), stable `ext_agent_host_id`, random PKCE S256, `state`, and `nonce`.
- HTTP `127.0.0.1` `/auth/callback` listener, bound to loopback, with per-attempt dynamic port. OAuth authorization-code exchange against OpenAI's token endpoint.
- RS256 ID-token signature verification against live OpenAI JWKS, issuer, audience, expiry, nonce and validated `sub`.
- Granted-scope check before using ChatGPT plan inference; no silent API-key fallback when an OAuth session exists but lacks plan permission.
- Keychain-protected tokens, host ID and issued client ID, serialized refresh in an actor, local sign-out.
- OAuth bearer token used for Responses SSE and model discovery when a session is active. API key used only when no ChatGPT session is present.

## Blocking caveat on iOS 16 (HIGH priority)

OpenAI documents a strict HTTP loopback callback on `127.0.0.1` for open-source clients, with callback path `/auth/callback`. iOS 16 does not expose the newer HTTPS callback matcher for `ASWebAuthenticationSession`. This implementation uses **SFSafariViewController** (Apple's browser UI presented in-app) plus a loopback listener to try keeping the app alive. **OpenAI and Google may reject this browser mode or iOS may still suspend the listener**. It is NOT proven to work on iOS 16.7.16 and cannot truthfully be advertised as fully functioning without testing. The browser displays a minimal success page and the client attempts to dismiss it after callback.

A more reliable iOS-native custom-scheme or universal-link callback would require support from the OAuth registration; substituting one for the required loopback callback violates the documented OSS flow. Do not silently adopt an undocumented OpenAI private OAuth flow from a decrypted IPA.

## Further hardening before shipping

1. Xcode build & real iOS 16.7.16 device test, including an ordinary sign-in taking >30 seconds and Safari suspension.
2. Revoke refresh token remotely during sign-out. Current UI explicitly says **Sign out locally**.
3. When account selection changes, store multiple client registrations rather than only one.
4. Disable misleading UI on app background expiry and provide a retry path.
5. Avoid persisting unsuccessful/empty assistant messages; test SSE errors and plan-specific model availability.
6. Verify OpenAI browser consent availability in the user's region and account.
7. Test RS256 against real JWKS/key rotation; protect API and OAuth session simultaneously.
8. Evaluate an approved iOS-specific redirect strategy if the provider adds one. 
9. Add complete end-to-end tests of passkey, Google, declined consent, expired sessions, refresh token rotation and HTTP 401/403/429.

## References

- https://developers.openai.com/siwc/token-sharing-open-source/sign-in
- https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations
- https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions

**This work is independent Swift source, not the decrypted official app's original source.**
