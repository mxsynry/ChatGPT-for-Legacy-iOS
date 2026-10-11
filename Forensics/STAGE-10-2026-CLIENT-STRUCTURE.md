# Stage 10: Official 2026 client binary-led UI/UX reconstruction

## Scope
Both **user-supplied decrypted official ChatGPT IPA Mach-O frameworks** were read directly. The report uses extracted **printable identifiers and Swift source-file path strings embedded in the binary**. These strings are evidence of named components in the build; **not recovered Swift source code**, proof of exact UX behavior, or authorization to transplant private frameworks. We did not obtain a running iOS 18 screen recording or screenshots.

## Actual evidence from `ChatGPT.framework/ChatGPT`

### Message Action Context Sheet
- `CalpicoMessageActionsSheet` — 2026 ✓ / 2024 not found
- `CalpicoMessageContextMenuInteraction` — 2026 ✓ / 2024 not found
- `MessageRowContextMenuPart` — 2026 ✓ / 2024 ✓
- `MessageRowActionAnalytics` — 2026 not found / 2024 not found

### Composer Model Selection
- `SendLongPressModelSelector` — 2026 ✓ / 2024 not found
- `MessageInputLongPressModelSelectorView` — 2026 ✓ / 2024 not found
- `ComposerModelPickerNativeMenuAnchor` — 2026 ✓ / 2024 not found
- `ComposerModelPickerUIKitMenuBuilder` — 2026 ✓ / 2024 not found

### Conversation Drafts
- `ConversationDraftLifecycleTracker` — 2026 ✓ / 2024 not found
- `MessageInput/ConversationDraftLifecycleTracker.swift` — 2026 not found / 2024 not found

### Biometric Locked Chats
- `ChatGPTLockedChats/LockedChatsBiometricCredentialStore.swift` — 2026 ✓ / 2024 not found
- `ChatGPTLockedChats/LockedChatsPINFlowViewModel.swift` — 2026 ✓ / 2024 not found
- `PasskeysView` — 2026 ✓ / 2024 not found

### Native Passkey Auth
- `NativeAuthPasskeyAuthenticator` — 2026 ✓ / 2024 not found
- `NativeAuthUsernamelessPasskeyLoginCoordinator` — 2026 ✓ / 2024 not found
- `NativeAuthPasskeyLoginView` — 2026 ✓ / 2024 not found

### Message Sources
- `ChatGPTMessageRow/MessageSourcesView.swift` — 2026 ✓ / 2024 not found
- `ChatGPTMessageRow/MessageSourcesPresentationModel` — 2026 not found / 2024 not found

### Message Markup
- `ChatGPTMessageRow/MessageAssistantContentStack.swift` — 2026 ✓ / 2024 not found
- `OAIMarkdown` — 2026 ✓ / 2024 ✓

### Media File Restore
- `ChatGPTMessageInput/MessageEditingAttachmentRestorer.swift` — 2026 ✓ / 2024 not found
- `ChatGPTMessageInput/LibraryFileUploadRestorer.swift` — 2026 ✓ / 2024 not found

### Writing Blocks
- `ChatGPTMessages/WritingBlockConversationComposerViewModel.swift` — 2026 ✓ / 2024 not found

## What this changes in our independent iOS 16 code (Stage 10)

1. **Per-conversation composer drafts.** Added `draft` to local `LocalConversation` with backward-compatible decoding, a 350 ms deferred save, restore when switching chats, and clear on send. Inspired by presence of `ConversationDraftLifecycleTracker`, not copied from it. Temporary chat drafts remain non-persistent in the existing repository.
2. **Send-button press-and-hold convenience.** A native iOS 16 context menu offers model selection, new chat, and temporary chat. This is our approximation of the observed `SendLongPressModelSelector` family; **it is not claimed to match the 2026 app's exact options**.
3. **Earlier-message regeneration safeguard.** If a selected assistant response has later messages, the app asks before discarding subsequent turns. Existing `rewindToAssistant` function remains the actual truncation logic.
4. No changes to ChatGPT/Google auth: **the 2026 binary contains native passkey/auth class names**, but that does not make their private authentication protocol available. We have not implemented unsupported token sharing or intercepted credentials.

## Open issues surfaced by official components

- The actual 2026 client includes distinct action-sheet / context-menu and message-content components, compared with our monolithic SwiftUI view. Splitting `RootView` into view models/components should be a follow-up architectural refactor.
- The 2026 client has locked-chat biometric credential/PIN components; our Stage 4 app lock protects **the entire app**, not individual conversations. Treat these separately.
- `MessageSourcesView` and related names indicate a separate source presentation layer; Stage 10 still lacks clickable citation cards and verification UI.
- The model picker references a dedicated menu model. Our API model picker is separate from ChatGPT subscription tiers and official first-party models. Don't misrepresent it as their model selector.
- Attachments restoration exists in official identifiers. Our file/document input currently lacks edit-time attachment restoration and a resumable upload queue.

## Verification and limitations

- Every claimed embedded symbol is recorded in `OFFICIAL-2026-BINARY-UI-IDENTIFIERS.json` with a direct 2026/2024 presence check.
- Static Swift syntax parse was run. Xcode SDK type-checking and device testing **have not** been performed.
- The source package does **not** bundle proprietary official app binaries or assets.
