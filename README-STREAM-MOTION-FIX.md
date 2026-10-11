# Nextgen V22 — Stream interruption + binary animation audit

This is a **patch to the existing SwiftUI `nextgen` branch**, not the legacy `ChatGPT.xcodeproj` project and not a replacement for an official client. It does not include proprietary official binaries.

## Changes

- Public Responses API streaming now distinguishes `response.incomplete` (with reason) from EOF/connection error. Successful completion exits the read loop without waiting for an extra network close.
- Partial assistant output is retained. For HTTP 429 or incomplete stream the chat shows a contextual **Retry response** button. A `Retry-After` countdown is displayed only when provided by the server.
- No automatic retry, no assumed continuation of an already billed request, no replay after a different new user turn. Manual retry sends the same user prompt prefix as a new response; a partial assistant turn remains visible but is excluded from the new API input.
- Native iOS 16 Reduce Motion-aware status dots, native composer chip spring motion and feedback, native retry banner.
- Two source IPAs are documented under `Docs/OfficialClient/` with package versions, file type counts, actual `.lottie`, `.ahap`, and orbit motion evidence. `Scripts/inventory_decrypted_ipas.py` can regenerate the reports using your local IPA files.

## Not yet proven

- Apple SDK compilation on the current branch, OAuth route, rate-limit headers on real accounts, any official server quota, appearance and performance on iPhone 8 Plus.
- Exact official visual animation keyframes for common UI transitions. Decrypted app executables do not include those transitions as separate `.lottie` resources. The 2026 Lottie files are birthday-specific, and the 3D orbit asset needs the original rendering pipeline.

## Safeguards

- The patch installer requires the known `nextgen` source hashes and will stop rather than overwrite any unexpected local changes.
- Use **NEXTGEN SwiftUI iOS16 — V22 (NOT bag.xml)** workflow. `Build Unsigned iOS IPA` / `ChatGPT-Legacy-arm64-unsigned.ipa` is the old app.
- Unit tests added to `Tests/StreamRecoveryMain.swift` and `Scripts/preflight.sh` for rate-limit deadlines, incomplete parsing, and retry scope/partial preservation.
