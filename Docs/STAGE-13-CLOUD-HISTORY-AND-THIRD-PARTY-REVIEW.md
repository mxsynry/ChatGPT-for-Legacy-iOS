# Stage 13 — Third-party sign-in, ChatGPT account history, and iOS 16 audit

## What the official 2026 IPA actually shows

This stage directly scanned the user's decrypted `1.2026.266` `ChatGPT.framework` Mach-O for readable Swift type/source-path metadata, and compared with the supplied `1.2024.348` framework. See `Forensics/STAGE13-OFFICIAL-2024-2026-EVIDENCE.json` for exact yes/no matches.

Evidence inside the 2026 *compiled* framework:

- `ChatGPTHistory/HistoryViewModel.swift` (also found in the 2024 binary)
- `CalpicoConversationsRepository` (not found in the 2024 binary scan)
- `CalpicoCore/FileCalpicoConversationsCache.swift` (not found in 2024 scan)
- `ChatGPTLogin/NativeAuthPasskey.swift` and `NativeAuthUsernamelessPasskeyLoginCoordinator` (2026)
- `ChatGPTLockedChats/LockedChatsBiometricCredentialStore.swift` (2026)
- `/backend-api` (both binaries)
- `https://auth.openai.com/api/accounts/authorize` (2026)

These names establish real internal client components. They do **not** give us their source code, signing rights, first-party credentials, backend access permissions, or a supported external endpoint contract. They are not a guarantee that a third-party OAuth token is accepted by a first-party backend.

## Clarifying the conversation-history disagreement

- **ChatGPT's official first-party app clearly has conversation retrieval and repository components**: true, supported by compiled metadata.
- **Sign in with ChatGPT's third-party open-source OAuth scope grants ChatGPT cloud history access**: false. The official OSS OAuth docs expressly exclude existing ChatGPT conversations and other account context.
- **The OpenAI `/v1/conversations` resource is your existing ChatGPT sidebar history**: false. It manages API-created conversation objects; it is a separate product contract.
- **Users can access their own ChatGPT history through an export**: true. Official Data Controls exports include conversation history. Our Stage 13 importer reads a user-selected `conversations.json` after extraction from that ZIP.
- **We have live, automatic cross-client ChatGPT cloud synchronization**: no. A first-party private session is not an ordinary authorized third-party OAuth grant; we do not copy user cookies or invoke undocumented first-party endpoints with a mis-scoped token.

Relevant public docs:
- OSS OAuth permissions: https://developers.openai.com/siwc/token-sharing-open-source
- OAuth registration, PKCE and localhost callback: https://developers.openai.com/siwc/token-sharing-open-source/sign-in
- OAuth-supported inference and model selection: https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- OAuth preview limitations: https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations
- Refresh, sign-out and revocation: https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions
- Error/recovery conditions: https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery
- Official ChatGPT data export: https://help.openai.com/en/articles/7260999-how-do-i-export-my-chatgpt-history-and-data
- Google OAuth and webview limitations: https://developers.google.com/identity/protocols/oauth2/javascript-implicit-flow

## Source changes in Stage 13

**OAuth / browser:** Listener now rejects unsolicited or malformed callbacks without ending a legitimate login; it checks exact loopback URI, path, state and duplicate query fields. Partial HTTP receives are handled; Safari Done cancels login instead of leaving a spinner. Login timeout extended to five minutes. Scene inactivity during consent no longer automatically closes Settings and locks the host screen. New-registration and returning-client URL construction is unit-tested. Only the issued client ID is reusable, not `dynamic_agent_client`.

**Credential lifecycle:** Keychain now reports failed writes and updates token records in-place. Refresh requests are single-flight to avoid rotating-refresh-token reuse. A sign-out that occurs mid-refresh cannot silently resurrect the session. Returning account registration is retained while tokens can be removed. A separate Disconnect action attempts server-side refresh-token revocation through OpenAI's OIDC discovery revocation endpoint. Revocation remains untested on device; if it fails the UI explicitly says remote revocation is unconfirmed. A Switch Account action starts fresh authorization.

**Model / inference:** Models are read from the signed-in ChatGPT account's `models[]` catalog (`slug`, `display_name`, `visibility`) or the API-key account's `data[]` catalog; first valid OAuth model is selected when the previous one is unavailable. The Responses request now uses plain-text conversation context, image parts as needed, `store:false`, `stream:true`, and current `web_search`. It accepts error `detail` bodies and handles `response.incomplete`.

**History / performance:** The Data Portability panel can now import the user's *own* `conversations.json`. It follows the selected branch (`current_node` and ancestors), preserves user/assistant text, and deduplicates by exported conversation ID across successive imports. It does not upload the import or fetch undocumented endpoints. Streaming UI updates remain immediate, while disk writes are throttled to reduce iPhone 8 Plus overhead.

## What remains unproven / missing

- No successful Xcode typecheck, iOS app build, TrollStore installation or device login in this environment.
- OAuth loopback within `SFSafariViewController` on iOS 16.7.16, Google selection, and passkey completion are **awaiting real-device testing**, despite more robust implementation and source tests.
- OpenAI's private first-party cloud history remains outside the supported third-party OAuth permissions. The import is a one-time offline copy, **not** cloud sync; embedded images and media cannot be reconstructed from JSON alone.
- Full official iOS 18 UI parity, realtime voice and advanced attachments remain unfinished.
- Sign-in should be exercised only against an account the user owns or authorizes. No preloaded tokens, leaked app secrets or official proprietary binaries are shipped.
