# Stage 16 — Model flexibility, persistent picker, usage, backend diagnostics

## What changed in this independently reconstructed iOS 16 client

**Main model UI:** `ModelAndUsageBar.swift` now displays a persistent model-name button **below** the standard navigation bar, independently of compact `.principal` toolbar rendering. This fixes the earlier risk that the picker was obscured by the capacity/usage control on older iPhone display sizes. The existing Send-button long-press and composer tools both still open the same picker.

**Model choice across modes:** The application has no local allow/deny matrix between model choice and temporary chat, local conversation history, photo input, or optional web-search toggle. Those options remain visible and independent. An actual Responses request is always validated by the public service. Models/tools that the server doesn't support are **not** unlocked or bypassed by this project.

**Per-conversation model preferences:** `ConversationStore` now keeps `modelID` per local chat, with backwards-compatible JSON decoding. Selecting a model updates the current chat's preference and also the default for *new* chats. Switching between existing chats preserves each chat's selection. An account model-catalog refresh no longer silently changes the user's selected model.

**Model discovery:** `ModelCatalog.swift` independently decodes plan and API-key catalog formats; normal display honors `visibility: list`, while an explicit Advanced toggle can show **all models returned by the server**, including unlisted ones, with visual warnings. Manual model ID entry is also available. A catalog entry or typed model slug does not imply entitlement or inference compatibility. Exact IDs passed to requests are never rewritten by this client.

**Usage:** An independent usage button shows **server-reported tokens on the last completed response** (input, output, total), where present. It NEVER labels this value as the percentage of remaining ChatGPT capacity. ChatGPT plan usage is managed in ChatGPT **Settings → Usage**; the sheet opens the official ChatGPT site and explains where to navigate. API-key billing is separate.

**Backend diagnostics:** `BackendDiagnostics.swift` preserves the structured API error `code`, `param`, HTTP status, and response request ID where present; additionally understands direct-admission `detail` error bodies. Specific usage-limit errors show a `View usage` action; unsupported-capability errors explain that the user can independently select a different model or disable web search. No silent model changes or billing-route switching.

**Convenience:** Chat search matches message text as well as titles. A new `Branch current chat` menu item duplicates local chat history/draft/model preference to compare alternate models without overwriting the original branch.

## Evidence from user-supplied official ChatGPT IPA binaries

`Forensics/STAGE16-MODEL-UX-DIRECT-SCAN.json` directly compares the 2024 and 2026 `ChatGPT.framework` Mach-O files, using literal UTF-8 substring presence. The 2026 framework contains `SendLongPressModelSelector`, `ComposerModelPickerUIKitMenuBuilder`, and `ConversationDraftLifecycleTracker`, which were absent as literal strings in the earlier framework; 2026 also contains multiple `UsageLimit`/`ContextWindow` identifiers. This is **architecture evidence**, not recovered original Swift code or a guarantee of exact on-screen behavior.

## Server requirements we intentionally do not bypass

1. `https://api.openai.com/v1/models` account catalog is advisory, not an entitlement guarantee. For plan OAuth, display recommended `visibility: list` choices by default and preserve source ordering.
2. Inference uses public `POST /v1/responses` with `store:false`, `stream:true` for ChatGPT plan OAuth.
3. Server-side eligibility, compatible tools/modalities, safety policy, context windows, billing, and usage limits remain authoritative. No private ChatGPT account endpoints, stolen credentials, or bypasses are used.
4. The documented third-party OAuth scope does **not** grant official ChatGPT cloud conversation history or memory. Offline export import remains optional.

## Regression verification / remaining risks

- `bash Scripts/preflight.sh`: **93 portable Swift regression assertions passed**, Swift syntax parse passed, private-backend path check passed.
- New assertions cover all-vs-listed model catalogs, per-model search, server-reported usage, missing usage, plan-limit and unsupported-capability error recovery.
- The current environment lacks macOS Xcode/iOS SDK. **No iOS compile or device test has been completed.** UI layout, Google/passkey browser callback, and inference still require your iPhone 8 Plus running iOS 16.7.16, plus Xcode CI logs.
- Branching copies chat messages including attachments; large local transcripts will consume more storage. Avoid repeatedly branching image-heavy chats.

## Official public references (for external verification)

- https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations
- https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery
- https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions
