# Stage 19 — Source audit, official IPA evidence, branching reliability, and backend fixes

This ZIP continues the **independent SwiftUI iOS 16 reconstruction**. It does not contain OpenAI's original Swift source or patched proprietary binaries. This stage is a code review with targeted changes, not a verified device release.

## What was checked

- Audited Stage 18's actual Swift source (`ConversationStore`, `BranchNavigation`, `RootView`, `ChatGPTSignIn`, `OpenAIClient`, `ResponseStreamEvents`, `SSEFrameCollector`, model/usage UI, and Xcode build scripts).
- Read the supplied **2024 and 2026 decrypted `ChatGPT.framework/ChatGPT` binaries** and checked literal identifiers directly; results are in `Forensics/STAGE19-DIRECT-BINARY-CONFIRMATION.json`.
- Cross-checked public Sign in with ChatGPT and Responses requirements against official published documentation. The public OAuth grant supports authorized inference, *not* official cloud history synchronization or private account rate-limit RPC calls.

### Important correction to older comparisons

The literal identifiers **`MessageRowContextMenuPart` and `MessageSourcesView` occur in BOTH** user-provided frameworks. Prior reports implied some of these were absent in 2024; that was not accurate. The 2026 framework additionally contains identifiers such as `ConversationDraftLifecycleTracker`, `ConversationBranchingService`, `SendLongPressModelSelector`, `ComposerModelPickerUIKitMenuBuilder`, `UsageLimitsDashboardViewModel`, and `MessageEditingAttachmentRestorer`. Presence/absence of a literal string is **not proof of feature absence or identical UI behavior**.

## Concrete fixes

| Severity | Stage 18 defect | Stage 19 change |
|---|---|---|
| HIGH | The original chat's Versions sheet only requested branches with `parentMessageID == nil`, so earlier message-anchored forks were invisible. | `BranchNavigation.groupedForks` and rewritten `BranchVersionsSheet` display distinct fork groups for all message anchors, with child-branch descendants and surviving siblings after original deletion. |
| HIGH | `Scripts/preflight.sh` omitted `BranchNavigation.swift` and `SSEFrameCollector.swift` from its compiler invocation. The shipped local preflight **failed**. | Include those modules and the new batching utility; GitHub Actions now invokes the same `Scripts/preflight.sh` to avoid divergence. |
| HIGH | Choosing API-key billing called `chatGPTSignIn.signOut()`, destroying a usable authorized account merely to change billing routes. | Switching routes preserves both credentials, explicitly cancels the current request, and exposes a button to switch back to ChatGPT-plan billing. |
| MEDIUM | Hitting Stop before first token left a permanent empty assistant row; this row could be sent back as invalid conversation context. | Track active assistant message ID, remove only genuinely empty placeholders when stopped or finished, retain partial responses, and flush streaming changes. |
| MEDIUM | Updating a SwiftUI message row on every tiny SSE text delta is unnecessarily expensive on an iPhone 8 Plus. | Deliver first text immediately; batch subsequent deltas for ~70 ms/4 KB via `StreamingTextBatcher`. **No text-fade or typewriter animation**. |
| MEDIUM | SSE collector did not accept a leading UTF-8 BOM and had no size check on non-data/comment lines. | Support a single initial BOM; reject any oversized SSE line. |
| MEDIUM | `ResponseUsage.parse` could overflow `Int` when summing untrusted server token counts. | Use `addingReportingOverflow` and reject impossible total-token combinations. |
| LOW | Users could branch an actively streaming, incomplete assistant placeholder. | Block branching while a response is still generating and explain why. |

## Tests actually run in this environment

```sh
bash Scripts/preflight.sh
```

- **151 portable compiled Swift regression assertions passed** using the local Swift compiler.
- Stage 19 source wiring checks passed.
- `swiftc -frontend -parse App/*.swift` passed.
- Static scan found no direct first-party `/backend-api/` request paths in the app source.
- ZIP integrity and YAML/JSON static validation performed before packaging.

These checks do **not** compile the iOS UIKit/SwiftUI target against Apple's SDK. GitHub Actions' `xcodebuild` step and runtime/device login checks **have not** run here.

## Highest-priority unresolved items

1. Run `.github/workflows/ios-build.yml` on macOS and fix any real Xcode type-check/availability/entitlement errors. A Swift parser cannot prove these absent.
2. On iPhone 8 Plus / iOS 16.7.16, verify `SFSafariViewController` + the NWListener loopback callback survives OpenAI-hosted Google and passkey sign-in. Do not label OAuth working until code exchange and first authorized `response.completed` succeed.
3. Verify local app-lock snapshots, microphone permissions, camera/PDF imports, and performance under long conversations.
4. Test fork grouping with original chat/at-message forks, deleted original, children of branches, and temporary chats.
5. Revisit source UI, attachments restoration, locked chat state, and first-party-only Work/usage features. The public OAuth scope does not grant official cloud conversation history or first-party private RPC access.

## References

- https://developers.openai.com/siwc/token-sharing-open-source/sign-in
- https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations
- https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions
