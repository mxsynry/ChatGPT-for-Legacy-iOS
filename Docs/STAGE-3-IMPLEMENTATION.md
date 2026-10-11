# Stage 3 — streaming and request lifecycle

Implemented in native Swift source:
- OpenAI Responses `stream: true` with `URLSession.bytes(for:)` (iOS 15+).
- SSE `data:` parsing and typed `response.output_text.delta`, `response.completed`, `response.failed`, `error` events.
- Cancel/stop button; task cancellation checks; no text fade animation.
- Responses bound to the originating conversation ID and message ID, not the currently selected conversation.
- Per-request UUID prevents a cancelled old request from overwriting the state of a newer request.
- Local delete-all history confirmation; API key remains in Keychain until separately removed.
- Stage 2 Swift source syntax fix: literal escaped newline sequences in `RootView.swift` corrected.

Known limitations:
- Streaming parser uses `AsyncBytes.lines` and handles normal SSE event framing, not every possible unusual server encoding.
- Frequent persistence per delta may cause disk I/O and performance pressure; next iteration should throttle disk writes while keeping UI updates immediate.
- No Xcode/iOS SDK in this environment: build status unverified.
- No browser-based ChatGPT/Google account sign-in in this independent source yet.
- No passkey/app-lock integration yet.
- No real attachment UI yet.
- No automated on-device tests.

API reference: https://developers.openai.com/api/docs/guides/streaming-responses
