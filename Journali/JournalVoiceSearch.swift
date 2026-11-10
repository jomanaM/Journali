import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class JournalVoiceSearch: ObservableObject {
    @Published private(set) var isListening = false

    private var sessionID: UUID?
    private var audioEngine: AVAudioEngine?
    private var audioSessionIsActive = false
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordingLimit: Task<Void, Never>?
    private var hasTranscript = false

    func toggle(
        onTranscript: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        if isListening {
            stop()
            return
        }

        guard let recognizer = SFSpeechRecognizer(locale: .current),
              recognizer.supportsOnDeviceRecognition else {
            onError("On-device voice search is unavailable for this language or device.")
            return
        }

        let id = UUID()
        sessionID = id
        isListening = true

        Task { [weak self] in
            let speechAuthorized = await Self.requestSpeechAuthorization()
            guard self?.sessionID == id else { return }
            guard speechAuthorized else {
                self?.stop()
                onError("Allow Speech Recognition for Journali in Settings to use voice search.")
                return
            }

            let microphoneAuthorized = await AVAudioApplication.requestRecordPermission()
            guard let self, self.sessionID == id else { return }
            guard microphoneAuthorized else {
                self.stop()
                onError("Allow Microphone access for Journali in Settings to use voice search.")
                return
            }
            guard recognizer.isAvailable else {
                self.stop()
                onError("Voice search is temporarily unavailable. Try again in a moment.")
                return
            }

            do {
                try self.startRecording(
                    with: recognizer, sessionID: id, onTranscript: onTranscript, onError: onError
                )
            } catch {
                self.stop()
                onError("Journali couldn’t start the microphone. Try again when it’s available.")
            }
        }
    }

    func stop() {
        sessionID = nil
        isListening = false
        hasTranscript = false
        recordingLimit?.cancel()
        recordingLimit = nil

        if let audioEngine {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            self.audioEngine = nil
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognizer = nil

        if audioSessionIsActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioSessionIsActive = false
        }
    }

    private func startRecording(
        with recognizer: SFSpeechRecognizer,
        sessionID id: UUID,
        onTranscript: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)
        audioSessionIsActive = true

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceSearchError.missingAudioInput
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .search
        Self.installTap(on: input, format: format, request: request)

        audioEngine = engine
        recognitionRequest = request
        self.recognizer = recognizer
        recognitionTask = Self.recognize(with: recognizer, request: request) { [weak self] transcript, finished, failed in
            guard let self, self.sessionID == id else { return }
            if let transcript, !transcript.isEmpty {
                self.hasTranscript = true
                onTranscript(transcript)
            }
            if finished || failed {
                let shouldShowError = !self.hasTranscript
                self.stop()
                if shouldShowError {
                    onError("Journali didn’t catch that. Try speaking again.")
                }
            }
        }

        engine.prepare()
        try engine.start()
        recordingLimit = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, self.sessionID == id else { return }
            let shouldShowError = !self.hasTranscript
            self.stop()
            if shouldShowError {
                onError("Journali didn’t catch that. Try speaking again.")
            }
        }
    }

    private static func requestSpeechAuthorization() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default:
            return false
        }
    }

    // The audio engine calls the tap from an audio thread.
    private nonisolated static func installTap(
        on input: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func recognize(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        receive: @escaping @MainActor (String?, Bool, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            let transcript = result?.bestTranscription.formattedString
            let finished = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                receive(transcript, finished, failed)
            }
        }
    }

    private enum VoiceSearchError: Error {
        case missingAudioInput
    }
}
