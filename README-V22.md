# OpenChat16 — V22 Stabilization (source project)

This is a **stabilization pass on V21**, not a claimed full backport of OpenAI's iOS 18 client. The bundled Swift files are independently written and require Xcode to build for iOS 16. No proprietary ChatGPT executable or asset is transplanted.

## Main changes

1. **Conversation-data recovery:** The app no longer overwrites existing history when `conversations.json` is corrupt or temporarily unreadable. Invalid JSON is moved to a preserved `.recovery-<UUID>.json` file before a new history is written; unreadable or oversized files enter a no-write state.
2. **Recoverability after restart:** Previously preserved history files remain discoverable and can be exported from Settings after local Touch ID/passcode confirmation.
3. **Defensive decoding:** An unsafe citation URL can no longer prevent the rest of the message transcript from loading. Unsafe citation metadata is discarded.
4. **Settings modal ownership:** Import ChatGPT export and share JSON now present from within the Settings navigation hierarchy instead of asking the already-presenting root screen to open another sheet.
5. **Portable type-checking:** ConversationStore + file recovery are type-checked together and exercised by executable behavioral tests, including corrupt, oversized, unreadable and migration cases. The macOS/Linux test paths use atomic writes; the iOS target keeps file-protection options.
6. **Build diagnostics:** GitHub Actions now logs Xcode version/SDK, runs preflight with a saved log, generates the project, validates the scheme, compiles for both simulator and device SDKs, and uploads logs on failure. The unsigned IPA is only packaged after the device SDK build succeeds.

## What was validated in this environment

- `bash Scripts/preflight.sh`: passes (182 existing portable regressions, Stage 19–21 wiring checks, V22 duplicate-type/structure checks and conversation recovery behavior checks).
- `swiftc -frontend -parse App/*.swift`: passes.
- Native `ConversationStore` and `ConversationFileRecovery` type-check under Swift 6.2.1 on Linux.
- ZIP integrity: checked before distribution.

## What remains UNVERIFIED

- **Full iOS SDK / SwiftUI type-check:** This Linux workspace does not have `xcodebuild` or Apple's iOS SDK. XcodeGen's generated Xcode project has **not** been compiled here.
- Installation and runtime on iPhone 8 Plus with iOS 16.7.16.
- End-to-end third-party Continue with ChatGPT authentication, Google/passkey login, and localhost callback in Safari.
- OAuth-authorized streaming inference, iOS-specific sheet presentation, LocalAuthentication, attachments, VoiceServices, and on-device frame rate.

The prior source-level test counts did not prove any of those items; this release does not mark them completed.

## Next required build step

1. Place this ZIP's contents at the **root of a GitHub repository** (preserve `.github/workflows/ios-build.yml`). Do not place the `project` directory itself as a nested subdirectory.
2. Commit/push. Open GitHub Actions → **iOS 16 Reconstruction — Stabilization V22** → Run workflow.
3. If it fails, download the **V22-build-logs** artifact, especially `preflight.log`, `build-simulator.log` and `build-device.log`, and fix the **first** diagnostic before making another feature update.
4. Only if the device SDK build passes, download **OpenChat16-V22-unsigned.ipa** and test installation with TrollStore on the actual device. Make a backup of existing local history first.
5. Separately test ordinary API-key chat, stop/cancel, persistence, temporary chats, imports, Touch ID and then **Continue with ChatGPT** via Google/passkeys.

**Security:** Do not send OAuth tokens or API keys as part of a build log or bug report. Never paste live secrets into source files. A local Touch ID chat lock controls the app UI; it is not a promise of per-conversation end-to-end encryption.
