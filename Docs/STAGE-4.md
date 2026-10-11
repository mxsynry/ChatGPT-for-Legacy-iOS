# Stage 4: Local device app lock

Implemented:
- `LocalAuthentication` device-owner authentication with Touch ID **or device passcode** fallback (iPhone 8 Plus compatible).
- Settings action requires successful device authentication before enabling lock.
- Lock overlay when returning from inactive/background states; SwiftUI content hidden behind opaque overlay.
- Enable/disable preference in UserDefaults (no credentials stored there).
- GitHub Actions XcodeGen -> Xcode build -> unsigned IPA artifact pipeline.

Important security limitations:
- This is a **local privacy gate**, not an OpenAI passkey or Google login.
- The local JSON conversation database is not separately encrypted; iOS Data Protection configuration and migration still need review.
- Disabling app lock while an attacker has an unlocked app is possible; a future build should require authentication before disabling.
- iOS app switcher snapshots should be tested; a dedicated privacy cover should be added if screenshots leak content.
- No Xcode or iPhone runtime tests have been completed in this environment.

Remaining: verify official OAuth eligibility, implement ASWebAuthenticationSession/PKCE only with supported public client registration, add passkey handling through the OpenAI-owned sign-in page, test iOS 16 device build, replace temporary chat placeholder.
