# Binary-evidenced modules: 2024 vs 2026

**Method:** inspected the two supplied decrypted IPAs, their `ChatGPT.framework` Mach-O load commands, and nested `.bundle` resource module names. A bundle name is **evidence of packaging**, not proof of UI behavior or of a backportable implementation.

- Official 2024 framework: ARM64, Mach-O min iOS **16.4**.
- Official 2026 framework: ARM64, Mach-O min iOS **18.0**.
- 2026 ChatGPT.framework embeds **45** named resource bundles; 2024 embeds **0** in the same structure.

| 2026 observed bundled module | Feature hypothesis | Proposed iOS 16 reconstruction |
|---|---|---|
| `ChatGPTLogin_ChatGPTLogin.bundle` | Account login | AuthenticationServices + approved OAuth provider; PKCE and state |
| `ChatGPTLockedChats_ChatGPTLockedChats.bundle` | Locked chats | LocalAuthentication and per-chat lock; avoid equating with OpenAI account security |
| `ChatGPTMessages_ChatGPTMessageRowParts.bundle` | Message components | SwiftUI message rows, structured content, code highlighting |
| `OAIMarkdown_OAIMarkdown.bundle` | Rich Markdown | AttributedString parsing and code blocks |
| `ChatGPTAudioAttachments_ChatGPTAudioAttachments.bundle` | Audio attachments | AVFoundation voice recording + documented transcription endpoints |
| `ChatGPTVoice_ChatGPTVoice.bundle` | Voice mode | AVAudioSession, compatible realtime API |
| `ChatGPTSharing_ChatGPTSharing.bundle` | Sharing | ShareLink/UIActivityViewController and Share Extension |
| `ChatGPTMemory_ChatGPTMemory.bundle` | Memory | Account feature; cannot access official memory through API key alone |
| `ChatGPTConnectors_ChatGPTConnectors.bundle` | Connectors | Public provider APIs and user permission boundaries |
| `ChatGPTWritingBlocks_ChatGPTWritingBlocks.bundle` | Editable writing blocks | Editable content state, copy/export |
| `ChatGPTMedia_ChatGPTMedia.bundle` | Media handling | PhotosPicker + camera/document picker |
| `ChatGPTDisclosures_ChatGPTDisclosures.bundle` | Disclosure UX | Privacy and permission panels |
| `CodexRemote_CodexRemoteCore.bundle` | Coding integration | Optional future public integration |
| `ChatGPTFinance_ChatGPTFinance.bundle` | Finance | Feature-gated; no private/entitlement-dependent port |
| `ChatGPTHealth_ChatGPTHealth.bundle` | Health | Out of scope until explicit user opt-in and supported API |

### Additional real bundle names

`Assets_Assets.bundle`, `ChatGPTAudioAttachments_ChatGPTAudioAttachmentsInterface.bundle`, `ChatGPTAvatar_ChatGPTAvatar.bundle`, `ChatGPTBeacons_ChatGPTBeacons.bundle`, `ChatGPTBirthday_ChatGPTBirthday.bundle`, `ChatGPTCalpico_CalpicoCoreUI.bundle`, `ChatGPTSkills_ChatGPTSkillsDirectory.bundle`, `ChatGPTVoice_ChatGPTVoiceAudio.bundle`, `ChatGPTWallet_ChatGPTWallet.bundle`, `CodexRemote_CodexRemoteThread.bundle`, `Device_DeviceHaptics.bundle`, `DotBall_DotBall.bundle`, `EmojiKit_EmojiKit.bundle`, `Factory_FactoryKit.bundle`, `Highlightr_Highlightr.bundle`, `Kingfisher_Kingfisher.bundle`, `OrbitCharacters_OrbitCharacters.bundle`, `PhoneNumberKit_PhoneNumberKit.bundle`, `RevenueCat_RevenueCat_CustomEntitlementComputation.bundle`, `Segment_Segment.bundle`, `Stripe_StripeCore.bundle`, `Stripe_StripePaymentSheet.bundle`, `Stripe_StripePayments.bundle`, `Stripe_StripePaymentsUI.bundle`, `Stripe_StripeUICore.bundle`, `Styleguide_SwiftUIStyleguide.bundle`, `SwiftCSV_SwiftCSV.bundle`, `TibroCore_TibroCore.bundle`, `mathFonts.bundle`, `swift-nio_NIOPosix.bundle`

### Limits
- No executable source code was recovered from these Mach-O images.
- No private OpenAI API paths, tokens, signing material, executable code or copyrighted assets were copied to the output.
- The 2026 binary reports min iOS 18.0 via `LC_BUILD_VERSION`; changing `MinimumOSVersion` alone would not satisfy runtime linking.
- The 2024 binary being older is **not** evidence that private binaries can be mixed across app versions.
- Login/passkeys and cloud history cannot simply be inherited from proprietary bundle contents.

### Important disparity in the 2024 IPA
The 2024 app Info.plist declares `MinimumOSVersion = 10.0`, but the embedded `ChatGPT.framework` Mach-O `LC_BUILD_VERSION` declares **minos 16.4**. The latter is the decisive linked-framework floor for compatibility; describing the 2024 framework as iOS 10 compatible would be false.
