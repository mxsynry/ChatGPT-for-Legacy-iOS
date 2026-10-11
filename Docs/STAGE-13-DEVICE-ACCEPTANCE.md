# iPhone 8 Plus / iOS 16.7.16 acceptance checklist

**Before claims of compatibility:** Push the Stage 13 source to a new repo/branch with the included GitHub Actions workflow; wait for a successful Xcode build; install the resulting unsigned IPA via TrollStore only after checking its bundle and entitlements.

### Native build

1. CI shows `PASS: 62 source regression checks` and no `swiftc` parse errors.
2. `xcodegen generate` produces a project without errors.
3. `xcodebuild ... -sdk iphoneos -destination 'generic/platform=iOS' ... build` exits 0.
4. TrollStore installation and cold start on iOS 16.7.16 succeeds; no scene-configuration, permission or keychain crash.

### First-time browser login

1. Open Settings → Continue with ChatGPT.
2. Observe a trusted `auth.openai.com` login, not an in-app password collection form.
3. Select Google only if OpenAI offers it. If passkeys are configured, separately test the OpenAI-provided passkey path.
4. Confirm the browser returns to the *same app* through `127.0.0.1:<port>/auth/callback`, and the app reports an authorized session.
5. Dismiss Safari while sign-in is incomplete: spinner should stop immediately, no session saved.
6. Test network failure, incorrect auth, declined consent and login timeout separately. No secret values in logs.

### Usage / rotation / account selection

1. Open model picker after authorizing ChatGPT-plan usage. Verify account-specific display names and valid slugs.
2. Send one short message and wait for `response.completed` (not just first streamed tokens).
3. Switch chats during generation; partial responses must remain with their original conversation.
4. Stop generation, background the app, and reopen without an app-lock or draft freeze.
5. Wait for access-token expiry and confirm only one refresh is attempted even with concurrent model/chat requests.
6. Sign out during a refresh; verify no session returns. Test Disconnect and confirm server revocation or visible failure warning.
7. Switch Google/ChatGPT account, then return to prior account (multiple registrations retained; only one active token session stored).
8. Test with an eligible and an ineligible ChatGPT plan; failures must not silently bill an API-key fallback.

### History and privacy

1. Request a ChatGPT data export in ChatGPT Settings → Data Controls, unzip it in Files, choose `conversations.json` in this app's Settings → Data portability.
2. Verify history titles and chronological active-branch messages. Repeat import and confirm duplicate conversations are not created.
3. Check that the import remains local and never automatically appears in the official ChatGPT account.
4. Test Touch ID/passcode app lock and backgrounding during Google/passkey flow; the login should not be prematurely dismissed.
5. Test photos, files, voice dictation and read-aloud separately; they are not proof of real-time official voice compatibility.

**Do not mark any device test as passed unless its actual result is recorded.**
