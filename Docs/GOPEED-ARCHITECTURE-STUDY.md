# Gopeed architecture study — transferable ideas

Reference: https://github.com/GopeedLab/gopeed
Documentation: https://gopeed.com/docs
Extensions: https://gopeed.com/docs/dev-extension

Gopeed's design separates a cross-platform Flutter UI from a Go core, exposes APIs, supports multiple protocols, and allows JavaScript extensions. Its 2.0 beta documents mobile/desktop native FFI integration.

Our **proposed** analogous separation (not Gopeed source reuse):
- `UI`: SwiftUI chat/navigation; zero provider-specific API parsing.
- `Core`: conversation lifecycle, request cancellation, task progress, local storage.
- `Providers`: OpenAI Responses, optional future standards-compliant endpoints; explicit capabilities.
- `Identity`: API-key Keychain, browser-based ChatGPT sign-in if supported.
- `Plugins`: optional sandboxed actions with explicit permissions; do not execute untrusted remote JavaScript inside privileged app context.
- `Transfers`: background attachment downloads/uploads with resumable task state, limits, cancellation and per-task errors.

Gopeed's extension ecosystem is useful as a *design pattern*, but do not automatically copy Gopeed's GPLv3 source into a differently licensed client. The architecture is not a claim that official ChatGPT uses Gopeed's code.

Proposed core interfaces:
- `AIProvider`: capabilities(), authenticate(), send(messages, options), cancel(task)
- `ConversationRepository`: list(), load(id), save(), delete()
- `TransferTask`: id, kind, progress, status, error, retry()
- `Capability`: text, vision, files, webSearch, imageGeneration, audio
- `Permission`: fileRead, networkDomain, clipboard, notifications

**Mobile API-key feature:** user may enter an API key locally, select a documented API model, and chat via HTTPS. The key must not be hardcoded into the IPA, uploaded to analytics, or placed in UserDefaults. Do not expose a local unauthenticated HTTP server by default.

## Next implementation order
1. Compile Stage 2 on macOS Xcode; fix any compiler errors.
2. Add request cancellation and response routing by conversation ID.
3. Replace nonstreaming transport with SSE, without fade animation.
4. Add local biometric lock and privacy/retention controls.
5. Implement supported browser account login with correct callback handling.
6. Add file attachments and background transfer queue.
