# Stage 6 — practical iOS 18-like features implemented for iOS 16

Source implementation (NOT confirmed by an Xcode/device build):

- Native SwiftUI chat UI, sidebar/search, model text field, local history, new conversation.
- Streaming SSE through public OpenAI Responses API; stop/cancel; text appears without fade animation.
- Markdown text via SwiftUI `Text(AttributedString)` interpolation (`Text(.init(...))`), basic only; no rich code highlighting.
- Copy/share message; edit user message and regenerate from that turn; regenerate last answer.
- Swipe to rename/delete conversation; temporary local chat that is excluded from disk persistence and export.
- PhotosPicker image attachment, resized to JPEG quality 0.65 and limited to 5 MB; submitted as input_image data URL. No camera or document picker yet.
- Optional web search request tool (`web_search_preview`) using the API key; availability/billing/model support vary.
- Keychain API key, Touch ID/passcode app lock, local export/delete, no automatic backup of conversation JSON.

## Compatibility and caveats

- Existing Stage 5 conversation JSON loads through custom `Decodable` defaults for new fields.
- Image attachments are embedded as base64 inside local JSON. This is a prototype, not efficient large-scale storage. For production, move image bytes into protected file storage and persist references.
- The application has **not** been compiled by Xcode or installed on the iPhone 8 Plus; Swift parse-only checks are not typechecking.
- The supplied official iOS 18 IPA was **not** decompiled into equivalent source. UI behavior is an independent approximation.
- Google/ChatGPT account login, OpenAI account passkeys, official cloud history, advanced voice, screen share, camera, document upload, push notifications, Work, widgets, and full model capabilities are **not** implemented.
- API keys are a separate billing/authorization method from ChatGPT subscriptions.
- Optional web search may incur separate API costs.
- Temporary mode here only means **not stored in this app's local JSON** and `store:false` API calls; it is not equivalent to the official ChatGPT temporary-chat policy.

## Remaining must-have order

1. Run GitHub Actions compile, resolve errors, install on iOS 16.7.16, test auth/Keychain, streaming and image memory usage.
2. Implement supported ChatGPT account sign-in only after confirming OAuth registration and iOS redirect support; do not invent login credentials or intercept OpenAI/Google password pages.
3. Add protected attachment file storage and document picker, upload progress, background transfer cancellation.
4. Upgrade message rendering: syntax highlighting, markdown tables, citations, image previews, selectable code blocks.
5. Add speech-to-text/voice input, read-aloud, accessibility and settings parity.
6. Consider widgets/share extension only after core features are stable.

## Test cases

- Stage 5 conversations still decode after upgrading.
- Switching chats mid-stream never appends into the newly selected chat.
- Cancelling a request preserves partial response and prevents further deltas.
- Temporary chat is not present in persisted JSON or exported JSON.
- Editing a user turn discards all subsequent turns and regenerates correctly.
- Delete-all clears local conversations but leaves Keychain credential intact until explicitly removed.
- Photo picker failure does not crash; very large images are rejected.
- Unsupported model/web search returns a visible API error rather than fake assistant text.
