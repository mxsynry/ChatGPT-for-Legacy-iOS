# Stage 9 — UI/UX audit and source changes

## Evidence vs inference
- Analyzed the **actual 2026 supplied IPA inventory** for packaged modules including `ChatGPTMessages_ChatGPTMessageRowParts.bundle`. The IPA confirms modular message-row resources; it **does not give us editable SwiftUI views, runtime screenshots, or an exact specification of long-press menus/model picker**.
- This iteration is an **iOS 16-native UX reconstruction** informed by the reference application's feature set, **not a pixel-exact reproduction of ChatGPT 2026**.
- No private asset or compiled OpenAI component was copied into source.

## Source-level defects found in Stage 8
1. Every message had a persistent 3–5-action toolbar, crowded on a 5.5-inch iPhone 8 Plus. **Fixed**: context menu on long-press, native iOS 16 interaction.
2. No message-specific long-press behavior. **Fixed**: Copy, Share, Edit on user messages; Copy, Share, Regenerate, Read aloud/Stop on assistant messages.
3. `regenerate()` targeted the **last user prompt regardless of the tapped assistant row**. **Fixed**: target assistant message ID; rewind to preceding user message. It discards subsequent turns, like editing earlier conversation history.
4. Model ID required manual text entry in Settings. **Fixed**: model picker in top toolbar + `GET /v1/models`, searchable results, manual override. **Caveat**: model availability in `/v1/models` is not proof of Responses/image/web-search capability.
5. Composer crowded with paperclip, globe, mic, photo button and attachment chips. **Improved**: combine tools into a menu; present attachments and web-search state above composer.
6. Failed network requests could leave an empty assistant message. **Improved**: delete empty placeholder on error; partial outputs remain on cancellation.
7. No visible currently selected model outside Settings. **Improved**: model name displayed in header.

## Still broken/untested / deliberately not claimed
- **Actual 2026 design parity**: cannot certify without runtime captures/screenshots from official iOS 18 client; archive resources do not establish exact current layouts.
- **Swift type checking/Xcode runtime**: `swiftc -frontend -parse` passes on the provided source; Apple iOS SDK compile and real device test have **not** run.
- **Browser-based ChatGPT login / Google / passkeys**: not implemented in this independent project. The picker works with an **API key**, not ChatGPT account models.
- **Model capabilities**: unsupported API model or `web_search_preview` tool may return API errors; capability querying/fallback remains future work.
- **Streaming**: per-token disk writes remain expensive; prefer throttled persistence in future. Message previews currently use Markdown `Text(.init(...))`, not full code blocks/tables.
- **Regeneration**: wipes later turns after chosen assistant response, without confirmation. Improve with a branch/confirmation UI.
- **Edit user message**: currently a system alert with one-line TextField, weak for long prompts. Improve with a multiline sheet.
- **Multiple alerts/sheets attached to same view**: runtime interactions must be tested; migrate to a single coordinated presentation route.
- **Photo import**: decodes large images in memory; downsample before decoding and thumbnail attachment previews.
- **Voice**: dictation/read aloud are Apple's native services, not official realtime voice.

## Manual QA on iPhone 8 Plus / iOS 16.7.16
- Long-press user and assistant bubbles; verify all action labels and target message IDs.
- Regenerate an *earlier* assistant answer and verify later turns are removed from local conversation.
- Open model picker without a key: error shown; with a key: fetch list, search, select, persistence across relaunch.
- Try unsupported model ID and network failure; no permanent empty assistant bubble.
- Keyboard shown in multiline composer; test content clipping, small width, VoiceOver and Dynamic Type.
- Open camera, Photos, PDF importer and web search toggle; ensure available hit areas with 320-414pt widths.
- Turn on app lock and background app; verify no conversation content exposed in app switcher.
