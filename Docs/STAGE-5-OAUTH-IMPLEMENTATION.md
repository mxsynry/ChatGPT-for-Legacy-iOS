# Stage 5 — OAuth feasibility and implementation contract (verified against official docs 2026-10-08)

Official references:
- https://developers.openai.com/siwc/token-sharing-open-source/sign-in
- https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations
- https://developers.openai.com/siwc/token-sharing-open-source/token-reference
- https://developers.openai.com/siwc/quickstart

## Correcting the earlier browser-auth assumption

The **open-source dynamic-registration flow** specifically requires an **HTTP loopback redirect on `127.0.0.1`**, path `/auth/callback`, from first registration onward. A custom URL scheme or arbitrary `ASWebAuthenticationSession` callback cannot be substituted without a separately documented supported flow. Therefore, simply adding an `ASWebAuthenticationSession` button would *not* implement this documented flow.

Mobile feasibility requires an iOS-local loopback listener, browser callback routing, app lifecycle/background testing, and careful testing on iOS 16. An external Safari browser may be more appropriate than a system authentication session if loopback return is not supported by the latter. Do not claim the OAuth flow works until validated on device.

## Verified protocol

1. Generate stable per-installation `ext_agent_host_id` (`urn:uuid:<UUIDv4>`), persist it securely.
2. Start an HTTP listener on `127.0.0.1` before opening the system browser. Restrict it to loopback; choose a free port; exact path `/auth/callback`.
3. Generate fresh `state`, OIDC `nonce`, and PKCE verifier/challenge for every attempt.
4. Navigate to `https://auth.openai.com/api/accounts/authorize` with `client_id=dynamic_agent_client` for new registrations, `agent_name_hint`, host ID, redirect URI, resource `https://api.openai.com/v1`, response type `code`, and scopes `openid profile email offline_access resource.invoke chatgpt.tokens.use.direct`.
5. Validate callback state; obtain **issued** `client_id` (do not reuse `dynamic_agent_client` for exchange).
6. Exchange code at `https://auth.openai.com/api/accounts/oauth/token` using PKCE verifier and exact redirect URI.
7. Verify ID-token signature against issuer JWKS, `iss`, `aud`, `exp`, and `nonce` using a maintained JOSE/OIDC implementation. Never accept an unverified JWT.
8. Check `chatgpt.tokens.use.direct` in granted scopes before plan-backed inference. Save credentials per verified account in Keychain; serialize refresh and handle revocation.
9. Use Responses API `store:false` and `stream:true` with a permitted model; do not assume account history access.

## Current implementation state

**NOT IMPLEMENTED**: loopback listener, browser OAuth, token exchange, JWKS verification, account switcher, refresh, revocation. The Settings screen deliberately does not present a nonfunctional Google login button.

**IMPLEMENTED**: separate API-key mode, Keychain, streaming, app lock, local privacy improvements.

## Security tests before login release

- Reject callback with wrong state, wrong path, reused code, wrong client ID, wrong account, expired state, or missing nonce.
- Reject forged/unverified ID token and missing plan permission.
- Ensure loopback listener is bound to `127.0.0.1`, not `0.0.0.0`.
- Test app backgrounding during Safari redirect and local listener lifecycle on iOS 16.7.16.
- No OAuth tokens in logs, UserDefaults, browser URL history, or conversation export.
