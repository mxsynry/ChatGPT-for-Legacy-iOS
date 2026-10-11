# Official 2026 vs 2024 framework: direct binary comparison

I scanned the **actual ChatGPT.framework Mach-O executables in the two user-provided decrypted IPA files**. These are present/absent **printable identifiers**, not source-level functionality proofs or UI screenshots. A missing identifier does not mean an older implementation lacked the user-visible feature; it may have used another name.

| Area | Exact searched identifier | 2024 | 2026 |
|---|---|---|---|
| Message action sheet | `CalpicoMessageActionsSheet` | Not found | Yes |
| Message action sheet | `CalpicoMessageContextMenuInteraction` | Not found | Yes |
| Message action sheet | `MessageRowContextMenuPart` | Yes | Yes |
| Send model picker | `SendLongPressModelSelector` | Not found | Yes |
| Send model picker | `MessageInputLongPressModelSelectorView` | Not found | Yes |
| Send model picker | `ComposerModelPickerUIKitMenuBuilder` | Not found | Yes |
| Draft ownership | `ConversationDraftLifecycleTracker` | Not found | Yes |
| Clickable sources | `ChatGPTMessageRow/MessageSourcesView.swift` | Not found | Yes |
| Clickable sources | `MessageSourcesView` | Yes | Yes |
| Assistant rendering | `ChatGPTMessageRow/MessageAssistantContentStack.swift` | Not found | Yes |
| Assistant rendering | `OAIMarkdown` | Yes | Yes |
| Biometric locked chats | `ChatGPTLockedChats/LockedChatsBiometricCredentialStore.swift` | Not found | Yes |
| Biometric locked chats | `ChatGPTLockedChats/LockedChatsPINFlowViewModel.swift` | Not found | Yes |
| Passkey identity | `NativeAuthPasskeyAuthenticator` | Not found | Yes |
| Passkey identity | `NativeAuthUsernamelessPasskeyLoginCoordinator` | Not found | Yes |
| Attachment restoration | `ChatGPTMessageInput/MessageEditingAttachmentRestorer.swift` | Not found | Yes |
| Attachment restoration | `ChatGPTMessageInput/LibraryFileUploadRestorer.swift` | Not found | Yes |
| Writing blocks | `ChatGPTMessages/WritingBlockConversationComposerViewModel.swift` | Not found | Yes |
| History | `CalpicoConversationsRepository` | Not found | Yes |
| History | `ChatGPTHistory/HistoryViewModel.swift` | Yes | Yes |

## What the newer architecture suggests and what Stage 15 actually changes

1. **Message action separation.** 2026 has `CalpicoMessageActionsSheet` and `CalpicoMessageContextMenuInteraction` markers. Stage 15 retains a dedicated `MessageRowView` with long-press actions. This is an iOS 16 approximation, not recovered proprietary source.
2. **Separate composer/model control.** 2026's `SendLongPressModelSelector` and `ComposerModelPickerUIKitMenuBuilder` markers suggest specialized composer UX. Stage 15 extracts `ChatComposerView`, declutters the iPhone 8 Plus input row, and preserves long-press Send → model chooser.
3. **Per-chat draft lifecycle.** 2026 has `ConversationDraftLifecycleTracker`. Stage 15 fixes a real bug where a 350-ms delayed draft save could be cancelled on a fast conversation switch.
4. **Message sources.** 2026 has `MessageSourcesView` evidence. Stage 15 implements linkable source cards and parses `response.output_text.annotation.added` and completion annotations from the **public Responses API**. This fixes web-search answers previously showing no tappable citations.
5. **Editing UX.** The official binary includes message editing/attachment restore identifiers. Stage 15 replaces the Stage 14 single-line alert with a multiline sheet, with confirmation before destructive rewinding.
6. **Locked chats.** 2026 includes dedicated PIN and credential-store identifiers. Our existing whole-app Touch ID lock is **not** the same as official per-conversation locked chats. Per-chat encryption remains unfinished.
7. **Authentication.** 2026 has native passkey component names. This is evidence of private first-party behavior, **not permission** for a third-party client to call its private login/backend APIs. Our supported OAuth loopback remains untested on iOS hardware.

## Implementation caveats

- We did not obtain the original official Swift source, exact screen layouts, or a running iOS 18 screen capture.
- We did not transplant protected OpenAI binaries/framework assets, private API cookies, or undocumented backend calls.
- Compiled source *still* needs iOS SDK type-checking and an actual device run. Passing Swift parse and portable unit tests is not equivalent to an Xcode build.
