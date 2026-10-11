# Stage 8: iOS 16 native voice capabilities

Source: `App/VoiceServices.swift` (new), changes in `App/RootView.swift` and `project.yml`.

## Features implemented in source
- Tap microphone in the composer; request Speech Recognition and Microphone permissions via Apple APIs.
- Partial dictation is updated in memory while recording; tapping again places recognized text in the message composer. It is **not automatically sent**.
- Prefer on-device speech recognition *if the selected locale recognizer supports it*. Otherwise Apple speech processing may use network services (subject to iOS policies). The app does not force on-device mode when unsupported.
- Read an assistant message aloud with `AVSpeechSynthesizer`. Tap stop to end speech.
- Stop dictation and playback when the app becomes inactive or locks.
- The iPhone 8 Plus on iOS 16 supports these public framework entry points, but runtime permission/audio routing tests remain required.

## Not equivalent to the official 2026 voice stack
- This is **speech-to-text plus text-to-speech**, not GPT realtime duplex voice, nor speaker diarization, nor voice conversation streaming.
- The 2026 IPA has LiveKitWebRTC and voice-related resources, but its proprietary implementation is not ported.
- No device build was executed; syntax parsing is only a preliminary test.

## Device test checklist
1. Fresh install displays Microphone and Speech Recognition prompts.
2. Rejecting either permission reports an error without crashing.
3. Dictate in English, Vietnamese, then switch between them.
4. Start/stop dictation repeatedly without `AVAudioEngine` tap crashes.
5. Enter background and return; mic is off, app lock still works.
6. Test playback over earpiece, speaker, Bluetooth and silent mode.
7. Confirm no transcription content is sent until the user taps send.
8. Confirm dictation permissions and microphone disclosure copy are visible.

## Remaining P0
- Working official-account authentication: supported OAuth authorization, refresh, token storage, callback verification, passkeys handled by OpenAI browser surface.
- macOS Xcode **typecheck/build**, followed by real iOS 16.7.16 installation.
