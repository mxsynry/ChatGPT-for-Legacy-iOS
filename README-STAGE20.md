# Stage 20 — Large iOS 16 backport consolidation

**Status: source release. No Xcode SDK build, iPhone installation, Google/passkey login or ChatGPT-plan inference session was performed in this environment.** All work is independent code built for iOS 16 from public APIs and metadata/identifier-based comparison of the user's decrypted 2024 and 2026 official ChatGPT frameworks. We have **not** recovered or transplanted the proprietary application's Swift implementation.

## What changed (implemented in Stage 20 source)

| Area | Change | Why it matters |
|---|---|---|
| **Navigation** | Pin/unpin chats; archive/restore chats; Recent/Pinned/Archived filters | Sidebar no longer devolves into an unmanageable list. |
| **Privacy** | Local **lock individual chats** with Touch ID/passcode; anonymous titles and no searchable message text until authorized | Mirrors the feature category evidenced by `ChatGPTLockedChats` and `LockedChatsBiometricCredentialStore`. Does not authenticate an OpenAI account. |
| **Privacy** | Revoke private-chat unlocks on app inactivity, conceal the composer, and shield inactive app content | Reduces unintended disclosure via switching/snapshot; device testing still required. |
| **Privacy** | Reauthenticate before JSON export if any locally locked chats are present | Protects against bypassing the private-chat viewer via export. |
| **Text rendering** | Native fenced-code blocks, horizontal scroll, copy-code action; prose Markdown remains selectable | Better than rendering all code as one paragraph; no WKWebView needed. |
| **Composer** | Remember web-search enablement **per conversation and branch** | Switching chats does not unexpectedly inherit a tool choice. |
| **Streaming** | Display real response phase (`Generating`, `Searching web`, `Writing response`) when observed | Long searches or reasoning no longer appear as a frozen blank reply. No fake time-to-completion. |
| **OAuth** | Validate HTTP loopback method, Host, request path, and 16-KB header bound before accepting a callback | Hardens the existing PKCE/state checked local callback listener. |
| **OAuth** | Settings → **Test local callback listener** | Tests local listener networking without an OpenAI account or exposing any secrets. **Does not** prove Safari, Google or passkeys work. |
| **Sources** | Block non-HTTPS, loopback/local/private-address citation links | Avoids offering misleading/unsafe local source links. |
| **Reliability** | Save drafts before background privacy wipe; do not let locked content leak into sidebar search or inactive composer | Fixes Stage 19 navigation/privacy regressions. |
| **Testing** | Two portable Foundation modules + expanded regression tests, Stage 20 UI/backend wiring tests | Catches more mistakes without pretending a Swift syntax parse is an Xcode build. |
| **Build workflow** | Simulator and device SDK builds; always upload compiler diagnostics; package unsigned IPA candidate only if builds pass | Makes the next necessary native build easier to debug. |

## What's different in the supplied official 2026 binary?

`Forensics/STAGE20-OFFICIAL-BINARY-INDICATORS.json` contains literal identifier hit offsets and comparison to 2024. Highlights found in the 2026 binary include `LockedChatsBiometricCredentialStore`, `ConversationDraftLifecycleTracker`, `ComposerModelPickerUIKitMenuBuilder`, `ConversationBranchingService`, `UsageLimitsDashboardViewModel`, `MessageEditingAttachmentRestorer` and `CalpicoMessageActionsSheet`. In contrast, `MessageSourcesView` and `MessageRowContextMenuPart` also occur in the 2024 binary. These are **observed strings**, not decompiled source, and their presence alone does **not** establish how Apple/iOS UI controls were implemented.

The corresponding Stage 20 implementations are **independent approximations**, not copied private modules. The official 2026 binary still requires iOS 18; we have not lowered its deployment target or redistributed proprietary binaries.

## Continue with ChatGPT (Google/passkeys)

The prior experimental loopback OAuth/PKCE implementation remains. Stage 20 adds a strict HTTP request parser and a foreground **self-test**. The self-test sends a synthetic callback to the loopback listener and verifies its own response; it never contacts OpenAI, so it must not be presented as successful third-party authentication. A working Google/passkey sign-in still requires iOS 16 Safari and provider verification and a valid OpenAI-authorized session.

A ChatGPT OAuth token does not grant a public third-party app full access to the first-party chat history service. Offline `conversations.json` import remains the supported history workaround.

## Security boundary and remaining limits

- Locking, pinning and archiving are **local metadata** in this independently built client. Their status is not synced to official ChatGPT.
- Locked chats protect the **app UI**, not a separately encrypted database. Storage still uses iOS file-protection mechanisms; stronger at-rest encryption is future work.
- Export files are sensitive and can leave the device after the user explicitly chooses Share.
- No fake subscription quota or private `/backend-api` traffic is implemented.
- Image/file attachments and native iOS dictation were built in earlier stages. Full realtime voice, first-party Work runtime, widgets and live official cloud-history synchronization remain absent.
- OS-level and UIKit/SwiftUI behaviors cannot be validated with a Linux `swiftc -frontend -parse` check.

## How to verify

```sh
# Linux/macOS portable checks (Swift toolchain required)
bash Scripts/preflight.sh

# On a macOS build host with Xcode, XcodeGen and an iOS SDK:
xcodegen generate
xcodebuild -project ChatGPTReconstructed.xcodeproj -scheme ChatGPTReconstructed \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ChatGPTReconstructed.xcodeproj -scheme ChatGPTReconstructed \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

The `.github/workflows/ios-build.yml` workflow performs these checks and collects the error logs. Install the resulting candidate on the target iPhone **only after an actual successful macOS Xcode build**.

### Suggested device smoke tests

1. New chat → API-key mode → streaming text → stop → regenerate; confirm no phantom messages.
2. Continue with ChatGPT → Google/passkey → callback → token stored → authenticated model request. Record failures without sharing tokens or authorization codes.
3. Foreground loopback self-test; then full browser sign-in separately (the tests are not equivalent).
4. Pin/archive/restore; search inside unlocked chats; verify locked chat text never surfaces in search or the app-switcher snapshot.
5. Enter a draft, background/foreground, switch chats rapidly; confirm draft and per-chat tool state survive.
6. Stream a code block and use Copy Code; open citations; verify blocked local URLs never appear as trusted sources.
7. Export with locked chat(s) → Touch ID gate → share; delete exported file afterwards.

## Still required before claiming a working iOS 16 backport

- Native Xcode compilation with the exact installed SDK, followed by fixing any compiler diagnostics.
- iPhone 8 Plus / iOS 16.7.16 performance and OAuth authentication verification.
- Account token refresh during long user sessions and explicit sign-out verification.
- Further native UI fidelity testing against **actual screenshots and interaction recordings** of the official 2026 app; binary strings cannot establish pixel-perfect layout.
