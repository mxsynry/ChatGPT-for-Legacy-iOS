# Official IPA asset and motion audit

Evidence from user-provided decrypted IPAs. This is static resource inspection,
**not a claim that every packaged module is functional, that animation curves
were recovered from compiled code, or that server-dependent features can be ported.**

## ChatGPT-1.2024.348.ipa

- App version: `1.2024.348`
- App minimum iOS (metadata): `10.0`
- Framework minimum iOS: `16.4`
- Inventory: 568 files, 20 feature bundles, 3 extensions, 0 proprietary 3D assets
- SHA-256: `c3c26fc2f8ac02ec344bedf7b86a17e3a90e229cc9de32b7eef28b9321405324`

### Motion resources

| Resource | Type | Timing / structure |
|---|---|---|
| `TrickleTap.ahap` | .ahap |  |
| `Boop.ahap` | .ahap | 2 haptic events, 2 parameter curves |
| `Hangup.ahap` | .ahap | 2 haptic events, 0 parameter curves |
| `FastSwoop.ahap` | .ahap | 2 haptic events, 2 parameter curves |

### Feature bundles / extensions

Bundles: `Apollo_Apollo.bundle`, `Apollo_ApolloAPI.bundle`, `Apollo_ApolloWebSocket.bundle`, `Assets_Assets.bundle`, `Auth0_Auth0.bundle`, `ChatGPTCore_ChatGPTVoiceCore.bundle`, `ChatGPT_ChatGPTDisclosures.bundle`, `ChatGPT_ChatGPTVoice.bundle`, `Datadog_DatadogCore.bundle`, `Device_DeviceHaptics.bundle`, `Factory_Factory.bundle`, `Highlightr_Highlightr.bundle`, `Kingfisher_Kingfisher.bundle`, `LiveKit_LiveKit.bundle`, `RevenueCat_RevenueCat_CustomEntitlementComputation.bundle`, `Segment_Segment.bundle`, `SnapKit_SnapKit.bundle`, `SwiftCSV_SwiftCSV.bundle`, `SwiftProtobuf_SwiftProtobuf.bundle`, `iosMath_iosMath.bundle`

Extensions: `ShareExtension.appex`, `VoiceScreenSharing.appex`, `Widgets.appex`

## com.openai.chat_1.2026.266_und3fined.ipa

- App version: `1.2026.266`
- App minimum iOS (metadata): `18.0`
- Framework minimum iOS: `18.0`
- Inventory: 2156 files, 47 feature bundles, 8 extensions, 225 proprietary 3D assets
- SHA-256: `8a0e2289e35b45f40606e9ed1350c333356425bcf39a649bc0a25a2ebb35cecd`

### Motion resources

| Resource | Type | Timing / structure |
|---|---|---|
| `birthday-bottom-sheet-in.lottie` | .lottie | 60.0 fps; 0.983 s |
| `birthday-bottom-sheet-loop.lottie` | .lottie | 60.0 fps; 0.817 s |
| `orbit-creation-motion.json` | .json | 60 fps; 47.25 s |
| `PhoneGestureAccepted.ahap` | .ahap | 2 haptic events, 0 parameter curves |
| `WidgetAttention.ahap` | .ahap | 2 haptic events, 0 parameter curves |
| `TrickleTap.ahap` | .ahap |  |
| `VoiceConnection.ahap` | .ahap | 4 haptic events, 0 parameter curves |
| `Boop.ahap` | .ahap | 2 haptic events, 2 parameter curves |
| `Hangup.ahap` | .ahap | 2 haptic events, 0 parameter curves |
| `FastSwoop.ahap` | .ahap | 2 haptic events, 2 parameter curves |
| `birthday-splash.lottie` | .lottie | 60.0 fps; 2.65 s |

### Feature bundles / extensions

Bundles: `Assets_Assets.bundle`, `ChatGPTAudioAttachments_ChatGPTAudioAttachments.bundle`, `ChatGPTAudioAttachments_ChatGPTAudioAttachmentsInterface.bundle`, `ChatGPTAvatar_ChatGPTAvatar.bundle`, `ChatGPTBeacons_ChatGPTBeacons.bundle`, `ChatGPTBirthday_ChatGPTBirthday.bundle`, `ChatGPTCalpico_CalpicoCoreUI.bundle`, `ChatGPTConnectors_ChatGPTConnectors.bundle`, `ChatGPTDisclosures_ChatGPTDisclosures.bundle`, `ChatGPTFinance_ChatGPTFinance.bundle`, `ChatGPTHealth_ChatGPTHealth.bundle`, `ChatGPTLockedChats_ChatGPTLockedChats.bundle`, `ChatGPTLogin_ChatGPTLogin.bundle`, `ChatGPTMedia_ChatGPTMedia.bundle`, `ChatGPTMemory_ChatGPTMemory.bundle`, `ChatGPTMessages_ChatGPTMessageRowParts.bundle`, `ChatGPTSharing_ChatGPTSharing.bundle`, `ChatGPTSkills_ChatGPTSkillsDirectory.bundle`, `ChatGPTVoice_ChatGPTVoice.bundle`, `ChatGPTVoice_ChatGPTVoiceAudio.bundle`, `ChatGPTWallet_ChatGPTWallet.bundle`, `ChatGPTWritingBlocks_ChatGPTWritingBlocks.bundle`, `CodexRemote_CodexRemoteCore.bundle`, `CodexRemote_CodexRemoteThread.bundle`, `Device_DeviceHaptics.bundle`, `DotBall_DotBall.bundle`, `EmojiKit_EmojiKit.bundle`, `Factory_FactoryKit.bundle`, `Highlightr_Highlightr.bundle`, `Kingfisher_Kingfisher.bundle`, `Localization_Localization.bundle`, `OAIMarkdown_OAIMarkdown.bundle`, `OrbitCharacters_OrbitCharacters.bundle`, `PhoneNumberKit_PhoneNumberKit.bundle`, `RevenueCat_RevenueCat_CustomEntitlementComputation.bundle`, `Segment_Segment.bundle`, `Stripe_StripeCore.bundle`, `Stripe_StripePaymentSheet.bundle`, `Stripe_StripePayments.bundle`, `Stripe_StripePaymentsUI.bundle`, `Stripe_StripeUICore.bundle`, `Styleguide_SwiftUIStyleguide.bundle`, `SwiftCSV_SwiftCSV.bundle`, `Threads_Threads.bundle`, `TibroCore_TibroCore.bundle`, `mathFonts.bundle`, `swift-nio_NIOPosix.bundle`

Extensions: `AskChatGPTActionExtension.appex`, `ChatGPTSearchSafariExtension.appex`, `FinanceKitBackgroundDeliveryExtension.appex`, `MessagesExtension.appex`, `NotificationServiceExtension.appex`, `ShareExtension.appex`, `VoiceScreenSharing.appex`, `Widgets.appex`

## Porting decisions

- Actual `.lottie` packages were found only in 2026, associated with birthday UI; they are **not** the general navigation animation system.
- `orbit-creation-motion.json`, `.orbitmesh` and `.orbitfaces` describe a proprietary visual pipeline; data files alone are not a working iOS 16 animation engine.
- 2024 and 2026 AHAP haptics can be mapped to system haptic feedback, but require on-device hardware checks.
- Built-in SwiftUI sheets, view transitions, and app state changes are compiled code, not extractable keyframe assets. Our `BackportMotion.swift` is an **independent iOS 16 approximation**.
- Official animation files stay as optional private research references. They are not automatically added to a public repository or bundled as if supported.
