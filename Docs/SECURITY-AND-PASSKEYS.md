# Passkeys, privacy and security

Public OpenAI documentation:
- https://help.openai.com/en/articles/20001039-passkeys-to-secure-your-openai-account
- https://help.openai.com/en/articles/8304786-keeping-your-openai-account-secure

**Account passkeys:** OpenAI controls registration, challenges, relying-party identity and credential verification. Our app should launch the supported browser authentication flow; OpenAI's own sign-in page may offer a passkey, Google or other account method. A locally added Touch ID button is **not** an OpenAI passkey.

**App privacy lock:** a separate local `LocalAuthentication` gate can protect opening the app on an unlocked phone. It must not pretend to authenticate the user's OpenAI account.

**Credentials:** API keys in Keychain with ThisDeviceOnly accessibility; never in UserDefaults or export files. A future OAuth token store should use the same security model, plus rotation/revocation.

**Privacy:** store local conversations under Application Support; add an explicit delete-all control, privacy mode, backup/export policy, and redaction before production. Stage 2 currently stores conversation JSON locally without encryption beyond iOS filesystem defaults and does not yet implement app lock or deletion UI.

**Network:** HTTPS via URLSession; default trust validation. No arbitrary script execution, custom trust bypass or hidden credential harvesting.
