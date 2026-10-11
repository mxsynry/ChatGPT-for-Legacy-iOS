# Stage 21 — Rendering, memory, scrolling and UI correctness

**Development status:** Source-only release; no Xcode SDK/device test. The official 2026 ChatGPT IPA is an architectural reference, not redistributed or decompiled Swift source. Stage 21 starts from Stage 20 and remains an independent iOS 16 client.

## Critical build blockers fixed in Stage 20

- Stage 20 `ConversationStore.swift` contained duplicate `isPinned`, `isArchived`, `isLocked` and `webSearchEnabled` stored properties, duplicate `set*` methods, and repeated Codable decoding and branch assignment. These passed syntax parsing but would fail normal Swift typechecking. All duplicate declarations were removed.
- The actual app now explicitly imports Combine in `ConversationStore.swift` and `VoiceServices.swift`, which declare `ObservableObject` and `@Published`. Linux-only shims are conditionally used to type-check the real ConversationStore source on non-Apple build hosts.
- `Scripts/preflight.sh` now **type-checks the actual store**, not just parses all files, and runs behavior tests for streaming, saved chats, flags, drafts, deletion and temporary chat persistence.

## UI/rendering changes

| Previous problem | Stage 21 change | Outcome/qualification |
|---|---|---|
| Every SwiftUI message-body update base64-decoded and instantiated `UIImage(data:)` | `AttachmentThumbnailView` loads images lazily, decodes in a utility task using ImageIO downsampling capped at 520px, uses a 24-MB/48-item thumbnail cache | Removes expensive full bitmap decoding from `MessageRowView.body`; device FPS unmeasured. Cache clears on inactivity; row releases strong thumbnail reference on disappearance. |
| Full Markdown/code block reconstruction with each incoming delta | While text is streaming the row uses simple selectable `Text`; rich Markdown/code controls appear when streaming finishes | Reduces repeated parsing and layout for long outputs without text fades. |
| Unchanged completed messages split into Markdown segments on unrelated UI events | Capped 6-MB/64-entry `MarkdownRenderCache`, cleared when inactive | Avoids repeated segmentation on redraws; parser remains portable and regression-tested. |
| Automatic scroll triggered by *every* appended string and compared entire response text | On a new message scroll immediately; on SSE ticks scroll at most about every 220ms, until the user manually scrolls away. `Latest` still returns to bottom. | Fewer layout-driven scroll operations while preserving pause-on-manual-scroll. |
| Each SSE delta scanned the store twice to read the current response then replace entire text | `ConversationStore.appendDelta` appends using one conversation/message lookup | Fewer searches and string copies per UI delta. |
| Stream checkpoints serialized all chat history every 1.5s | Checkpoints at most every 8s during generation, with explicit flush on stop/finish/background | Fewer large JSON writes. Crash could lose up to ~8s of streamed text since last checkpoint. |
| Full-resolution photo conversion executed on the main thread | PhotosPicker input uses ImageIO downsampling and JPEG compression on a worker task; new choices cancel old selections | Less work on UI actor and protection against outdated selection completion. |
| Importing multi-megabyte ChatGPT JSON / PDF blocked main thread | Imports parse in utility tasks; progress shown and history import button disabled during import | Limits UI stalls, though merging thousands of chats still happens on the main actor and needs device profiling. |
| Dark-mode send icon could become white on a white background | Send icon uses `Color(.systemBackground)` against `.primary`, and interactive tap target expanded to 44pt | Adaptive contrast. On-device dynamic-type verification still required. |
| Search scanned all imported messages on every typed letter | Sidebar applies a 220ms debounce | Less repeated work when searching large imports; full-text indexing remains a future optimization. |
| Reattaching the exact same photo did not always trigger selection change | Reset picker selection after sending and on chat switch | Allows selecting the same image again later. |

## Test evidence

```sh
bash Scripts/preflight.sh
# PASS 182 Foundation-based regressions (up from 178)
# PASS Stage 19 wiring checks
# PASS 39 Stage 20 wiring assertions
# PASS 21 Stage 21 rendering/UI/privacy assertions
# PASS Stage 21 store behavior tests
# PASS native ConversationStore.swift typecheck with Swift on host
# PASS syntax parse for App/*.swift
```

A **host-side Markdown microbenchmark** is available:

```sh
swiftc -O App/MarkdownSegments.swift Tests/RenderBenchmarkMain.swift -o /tmp/chat-markdown-bench
/tmp/chat-markdown-bench
```

One local execution on the supplied Linux host: 1,200 parses of the *same* sample, uncached **0.671s**, cached **0.001s**. This is deliberately a repeat-input cache microbenchmark; **it is not a claim of 670× faster end-to-end iPhone rendering or frame rate**. The sample was checked to return identical Markdown segments.

## Further investigation required

1. **Full Xcode typecheck:** UIKit/SwiftUI/ImageIO are unavailable on this host. MacOS GitHub Actions build must identify remaining SwiftUI API/type errors.
2. **Real iPhone 8 Plus performance:** Profile Memory Graph, allocations, frame pacing and scrolling with 1,000 messages, code blocks, images, accessibility text sizes, dark mode and background lock.
3. **OAuth:** Real localhost Safari login/Google/passkeys and authorized inference remain experimental, independent of render changes.
4. **Chat storage:** ConversationStore still serializes the full history on persisted saves. Long-term improvement is SQLite/Core Data plus file-backed images and background indexing.
5. **Voice and attachment validation:** ImageIO orientation, HEIC and camera behavior require native QA. Camera compression now runs off-main; raw selected images can still be momentarily large.
6. **UI fidelity:** Official binary identifiers cannot establish pixel-perfect colors, spacing, menu ordering or transitions. An official 2026 screenshot/video and native test are needed for visual matching.

**Do not describe Stage 21 as a compiled or device-tested IPA.** The workflow still produces an unsigned install candidate only after Xcode succeeds.
