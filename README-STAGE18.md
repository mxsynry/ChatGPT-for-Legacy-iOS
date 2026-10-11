# Stage 18 — Branch version navigation and transport hardening

This release continues the **clean-room, iOS 16-native** reconstruction. The official
2026 framework's `branchConversation(conversationID:messageID:...)` identifier
inspired the UI workflow, **not** recovered or reused proprietary source code.

## Implemented
- A **Versions** button on a branch's header, plus **View branches** on original chats with descendants.
- Dedicated version browser that lists original conversation and all sibling branches
  created from the *same source message*, in creation order. A different fork
  is not conflated with a version of the selected one.
- The browser includes each version's local mode/model/temporary state; switches
  selection without overwriting the messages in any version.
- Split SSE frame collection into `SSEFrameCollector`: handles multiline `data:`
  fields, comments/keepalives, blank line dispatch, missing terminal blank line,
  and refuses a >2 MiB event. Existing URLSession stream parser uses it.
- Added portable regression tests for exact-fork navigation and SSE framing;
  wired new Foundation-only files into CI.

## Verification
- Linux Swift parser: PASS for all `App/*.swift`.
- Compiled/ran native portable regression test binary: **134 checks passed**.
- Existing UI/backend static wiring script: **32 checks passed**.
- Full iOS Xcode compilation: **NOT performed** (Xcode/macOS SDK unavailable here).
- iOS 16 iPhone install, Google/passkey login, and actual inference: **NOT verified**.

## Known gaps
- Original-chat Versions browser only describes `nil`-anchor forks. A specific
  fork is accessible from a child branch, not yet through a per-message version counter.
- The OAuth loopback listener and browser lifecycle still require a real-device test.
- The official ChatGPT cloud Work engine, account-capacity readings and cloud
  conversation history cannot be claimed via the supported third-party API.
- Branching is local and cannot sync first-party ChatGPT account branches.

## Next device checkpoint
Upload this ZIP's source to your repository, run the existing GitHub Actions
`iOS 16 source build` workflow, and send the **first failing Xcode compiler log**
if any. Do not label the IPA installable until that compile and runtime test pass.
