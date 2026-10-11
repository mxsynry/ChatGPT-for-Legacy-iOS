# V22 stabilization and failure ledger

## Confirmed at the source level

| Problem | Root cause | Patch | Reproduction/test |
|---|---|---|---|
| History could be overwritten on startup | `init` called `newChat()` after a silent JSON decode failure | `ConversationFileRecovery`, preserve corrupt file, disable writes for unreadable files | `StoreBehaviorMain`: corrupt bytes preserved, readable new file, oversized and unreadable paths untouched |
| Citation metadata could invalidate all history | Decoding one invalid source URL threw from `[ResponseCitation]` decoding | Safely drop invalid citation array while preserving message | `StoreBehaviorMain`: invalid `javascript:` citation doesn't discard transcript |
| Recovery copy inaccessible on next launch | Recovery URL held only in in-memory state | Discover previously preserved copies at startup | `StoreBehaviorMain`: re-open store and recover same file URL |
| Data portability actions could present on wrong sheet | Settings actions presented import/export from root with Settings already showing | Attach picker/share sheet inside Settings hierarchy | Swift syntax parsing and V22 source checks; real iOS UI test pending |
| Portable store checks could rely on iOS-only file protection | Previously compiled the store without platform-specific source distinction | iOS-only protection and portable `.atomic` write for test hosts | Linux native type-check/regression passed; macOS CI pending |
| Stage 20 duplicate source declarations went undetected | Syntax-only tests accepted duplicate fields/methods | Existing V21 store type-check plus new top-level duplicate-type guardrail | `Scripts/preflight.sh` |

## Intentionally not changed

- Experimental OAuth provider/PKCE flow: no unverified protocol substitutions or first-party private backend calls.
- Backend model selection and account permission limits: no server-side access bypass.
- Streaming text animation: no new fades introduced.
- Existing attachment, voice, branching, usage, and locked-chat functionality remains source-level and device-untested.

## Release gate

Source-level checks passed; **full iOS SDK build remains the blocking gate**. Do not call this a verified IPA until GitHub Actions generates it and installation passes.
