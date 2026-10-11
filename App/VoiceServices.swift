import Foundation
import Combine
import AVFoundation
import Speech

@MainActor
final class VoiceServices: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var recording = false
    @Published private(set) var speaking = false
    @Published var recognizedText = ""
    @Published var errorMessage: String?

    private let speechSynthesizer = AVSpeechSynthesizer()
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var tapInstalled = false

    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    func beginDictation() async {
        guard !recording else { return }
        guard await requestPermission() else {
            errorMessage = "Enable Microphone and Speech Recognition access in Settings."
            return
        }
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not currently available for this language."
            return
        }
        stopDictation()
        recognizedText = ""
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if speechRecognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            recognitionRequest = request
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            tapInstalled = true
            audioEngine.prepare()
            try audioEngine.start()
            recording = true
            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    if let result = result { self.recognizedText = result.bestTranscription.formattedString }
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        self.stopDictation()
                    } else if result?.isFinal == true {
                        self.stopDictation()
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            stopDictation()
        }
    }

    func stopDictation() {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func readAloud(_ text: String) {
        stopDictation()
        speechSynthesizer.stopSpeaking(at: .immediate)
        guard !text.isEmpty else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { errorMessage = error.localizedDescription }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speaking = true
        speechSynthesizer.speak(utterance)
    }

    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        speaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }

    private func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
