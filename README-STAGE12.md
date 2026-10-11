# Stage 12 — Sign in with ChatGPT (experimental iOS 16 transport)

This archive continues Stage 11 and prioritizes **third-party Continue with ChatGPT** instead of additional cosmetic UI changes.

The source includes a real OpenAI authorization URL builder, localhost OAuth receiver, PKCE, token exchange, JWT verification, secure token storage, refresh and bearer-authenticated API request path. It opens OpenAI's own login page (with Google/passkey options if available to the user).

**Not yet a successful login:** the project is uncompiled, iOS loopback behavior is untested, and in-app Safari authentication compatibility and iOS callback behavior are unverified. The new Settings button is explicitly labeled experimental. This must be fixed or validated before calling the login feature working.

Do not confuse ChatGPT plan OAuth with access to official ChatGPT conversation history. See Docs/STAGE-12-THIRD-PARTY-SIGN-IN.md for exact details and blockers.

Build with XcodeGen and Xcode on macOS, and inspect `.github/workflows/ios-build.yml` for the CI source build. No old bag.xml files were used.
