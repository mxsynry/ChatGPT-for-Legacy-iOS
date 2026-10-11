# ChatGPT iOS 16 — Stage 15: UI/UX + Responses backend correction

A **clean-room** SwiftUI/iOS 16 source project developed against publicly documented APIs. Its 2026 official ChatGPT IPA reference remains external; proprietary frameworks, resources, and private endpoints are **not** bundled.

**This stage actually changes source code**, not just docs:

- Extracted `ChatComposerView` and `MessageEditorSheet` from oversized `RootView`.
- Improved long-press Send model shortcut, attached-item chips, human-readable model display names, and quick conversation switching.
- Stops auto-scrolling when the user manually reads older messages; "Latest" resumes.
- Adds `MessageSourcesView` and public Responses SSE annotation handling so web-search citations can be tapped.
- Fixes 350 ms draft race, avoids draft loss before authentication, and delays nested sheet presentations on iOS 16.
- Adds image downscaling/size limits for older phones, source URL validation, and persistence of citations.

See `Docs/STAGE15-UI-AND-BACKEND-FIXES.md` and `Docs/STAGE15-2026-VS-2024-REVIEW.md` for exact changes and official-binary evidence.

**Verification:** `bash Scripts/preflight.sh` passes 78 portable regression checks and Swift syntax parsing. This does **not** prove Apple SDK type-checking, runtime login, TrollStore installation, or pixel-identical 2026 UI. No usable `.ipa` is included; macOS Xcode build still required.
