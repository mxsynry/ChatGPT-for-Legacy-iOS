# Binary-led porting decisions — iOS 16 nextgen

## What was inspected

The two **user-supplied** decrypted IPA archives were opened as ZIPs, their bundle metadata parsed, their individual packaged animation/haptic assets identified, and the JSON Lottie/motion formats inspected. This inspection was independent of any alleged restored Swift source. The binary images themselves were **not** successfully transformed into source code, and the 2026 binary's UI code was not executed on iOS 16.

- `1.2024.348` includes a ChatGPT framework with minimum iOS 16.4, basic haptic AHAP assets and three extensions. It can be used as a compatibility baseline, but no claim is made that its current login/session transport still works.
- `1.2026.266` declares iOS 18.0. It contains three packaged birthday Lottie animations, one 60-fps custom orbit-motion sequence (2,835 frames), 225 proprietary mesh/face assets, seven haptic AHAP files and eight extensions. None of these prove the bundled full voice/Work/connector services are available to an independent iOS 16 app.

## What this patch ports into the reconstructed app

| Area | New behavior | Relationship to official IPAs | Status |
|---|---|---|---|
| Interrupted response | Preserve partial text; distinguish explicit `response.incomplete` from closed stream; safe diagnostic with request ID | Independent public Responses API logic; comparison target is official interruption experience | Implemented in source; device unverified |
| Rate limit | Read `Retry-After` on HTTP 429; show countdown and manual Retry button, never auto-POST | Behavior inspired by modern interruption UX, **not** a private quota fetch | Implemented in source; device unverified |
| Retry | Scoped to exact triggering user message; new response appears below retained partial; no claiming to resume private server state | Independent response regeneration | Implemented in source; device unverified |
| Generation dots | Three staggered pulse dots with Reduce Motion support | Independently authored SwiftUI animation; not extracted official keyframes | Implemented in source; device unverified |
| Composer interactions | Spring-styled chip change and native feedback for send/tools/retry | Adapted native UI motion/haptics, not cloned official AHAP curves | Implemented in source; device unverified |
| Original Lottie | Three birthday animations separately inventoried and exported for **personal reference** | Actual 2026 animation assets (60 fps, ~0.8-2.7 s) | Analyzed only; not wired to app runtime |
| Orbit pipeline | Orbit motion JSON plus orbitmesh/orbitfaces counted | Data relies on modern engine/rendering framework | Analyzed only; cannot be directly transplanted |

## User-facing contract

- `Retry response` means **new inference**. The original request may already have been processed or billed. Partial text is preserved, not concatenated with an unrelated regeneration.
- A rate limit countdown appears **only when the server supplies `Retry-After`**. Without it the button is still manual but no fictional reset time is displayed.
- The client uses the documented `api.openai.com/v1/responses`, with `store=false`. No cloud conversation is fetched through internal first-party ChatGPT endpoints.
- The retry action does not save message text, credentials or authorization headers in a diagnostic. It remains limited to the selected, locally authorized conversation.
- Local portable Swift compile/regression success is **not** proof of Xcode 16.4 SDK compilation or installation on iOS 16.7.16. Continue with GitHub Actions Nextgen workflow, not the legacy bag.xml workflow.

## Further work required for full parity

1. Compare running official 2024 / 2026 app screenshots and gestures at the exact same states: sidebar, scroll, sheet, composer focus, error, resumption, typing, model picker. Packaged animation resources do not reveal UI transition curves in compiled Swift/Obj-C.
2. If desired, integrate specific original `.lottie` birthday resources through a compatible animation runtime in a **private local test build**. Do not assume that a public repository may redistribute closed-source official assets; permission/licensing needs to be considered. No additional animation engine dependency is added in this stabilizing patch.
3. For voice/orbit, determine mesh formats and rendering APIs and benchmark on the actual iPhone 8 Plus; avoid copying the iOS 18 binary framework into an iOS 16 executable.
4. Implement native public features in independent modules, with CI and real device tests for all actions; mark server-controlled account features unavailable where authorized APIs don't exist.

