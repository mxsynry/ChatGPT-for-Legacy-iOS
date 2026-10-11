# Stage 14 — Pre-device third-party sign-in review

**Source-only security hardening and official IPA evidence review. Not an installable or tested IPA.**

This update focuses entirely on third-party `Continue with ChatGPT` and safe iOS 16 login behavior. It does **not** claim to convert the 2026 compiled application into original source.

### Specific improvements

- Preserve registrations for multiple validated ChatGPT accounts; choose saved registrations to reauthorize; migrate Stage 13 single-registration data.
- Preserve the currently working login when beginning a different account's browser authorization; commit the replacement only after verified success.
- Keep API-key billing strictly opt-in: an expired/revoked ChatGPT grant never silently switches subsequent requests to a stored API key.
- Require a Bearer token response and a replacement refresh token for a rotating refresh.
- Protect API keys with WhenUnlockedThisDeviceOnly and update in-place rather than deleting a valid key first.
- Invalidate stale account-specific model-list loads and refresh the catalog after sign-in completes.
- Reject cross-account OAuth token refreshes and never overwrite newer credentials with stale refresh responses.
- Cancel sign-in even after the OAuth browser returns, when token exchange and ID-token verification are still pending.
- Start loopback listener asynchronously to avoid freezing the UI; no silent weak-random fallback.
- Enforce OIDC multi-audience `azp` and additional time checks after RSA signature verification.
- Better Keychain accessibility for new credentials and best-effort migration of earlier records.
- Non-secret sign-in progress phases and independent `OpenChat16` app identity.
- Expanded portable regression coverage. 62 total source-level assertions pass in this environment.

### What remains experimental

Google/browser passkeys through OpenAI's own sign-in page, localhost HTTP callback on iOS 16, OpenAI plan authorization, JWKS/keychain runtime behavior, complete Xcode build. A saved account registration is **not** an active session. Only one active token record is currently kept. An active login is preserved while a new account's consent is pending, but full parallel multi-account token persistence is still not implemented.

### Commands

Run `sh Scripts/preflight.sh` on Linux/macOS to compile portable pure-Swift regression modules and Swift parse all app sources. For a real iOS compile, push the **entire repository** and run the included GitHub Actions workflow; the XcodeGen project uses a deployment target of iOS 16.0. Use signed/unsigned IPA packaging only after build passes.

See `Docs/STAGE14-PREDEVICE-AUTH-SECURITY-REVIEW.md` for the full issue log, official binary evidence and test blockers.
