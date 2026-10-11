# Stage 13 — official binary review, stronger third-party login and history import

This is a continuation of the independent native iOS 16 project. It contains no bag.xml source or transplanted official ChatGPT binaries.

## Improved code
- Dedicated, unit-tested OAuth authorization URL builder and strict loopback callback validator.
- Partial-receive tolerant HTTP loopback callback server, browser cancellation, five-minute expiry, preserved sign-in scene while passkeys/Google are active.
- Keychain writes checked; in-place token rotation; single-flight refresh, stop refresh session resurrection on logout.
- Account-bound registration persistence, Switch Account, remote session-revocation attempt from documented discovery endpoint.
- Account-specific model catalog including display names and visible model IDs.
- Public Responses API payloads with `store:false`, `stream:true`, text-context, image parts and current `web_search`.
- Direct local import of your own ChatGPT `conversations.json` export, following the current conversation branch, deduplicating imported IDs.
- Lower disk write volume during streaming.

## Verified locally
- `swiftc` syntax parsing of all app Swift source files: PASS.
- 32 regression assertions compiled and executed using portable Swift: PASS.
- Source ZIP integrity: verify with `unzip -t`.

## NOT verified
- Xcode build / iPhone 8 Plus runtime / TrollStore IPA installation.
- Google/passkey login through Safari on iOS 16, live refresh/revocation, response inference using a real account.
- Official first-party cloud-history synchronization. The documented third-party OAuth scope does **not** include existing ChatGPT history, although the official app itself has history/repository components.

## Import existing history
In ChatGPT: Settings → Data Controls → Export. After receiving/downloading the ZIP, extract it using Files, then in this app: Settings → Data portability → Import ChatGPT history (`conversations.json`). Text-only messages are imported to local storage; this is not an authenticated cloud sync.

## Compile and test
From this source repository, open GitHub Actions → `iOS 16 source build` → Run workflow. Its macOS runner performs portable Swift regression checks, generates the Xcode project using XcodeGen, builds an unsigned iOS app, and packages the IPA as a downloadable artifact. No claims of successful CI results have been made yet.

Read `Docs/STAGE-13-CLOUD-HISTORY-AND-THIRD-PARTY-REVIEW.md` and `Docs/STAGE-13-DEVICE-ACCEPTANCE.md` for evidence and specific test cases.
