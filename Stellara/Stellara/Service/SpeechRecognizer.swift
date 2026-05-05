import Foundation
import Combine
import Speech
import AVFoundation

/// Распознавание речи на лету: даёт partial-результаты в `transcript`.
/// Используется в `OracleView` для ввода вопроса голосом.
@MainActor
final class SpeechRecognizer: ObservableObject {

    @Published private(set) var transcript: String = ""
    @Published private(set) var isRecording: Bool = false
    @Published var errorMessage: String?

    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        // Сначала пробуем язык интерфейса, если недоступен — fallback на en-US.
        self.recognizer = SFSpeechRecognizer(locale: Locale.current)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Public

    /// Запустить запись. Спросит разрешения, если ещё не выданы.
    func start() {
        guard !isRecording else { return }
        errorMessage = nil
        transcript = ""

        Task { [weak self] in
            guard let self else { return }
            let ok = await self.requestPermissions()
            guard ok else {
                self.errorMessage = NSLocalizedString("speech.error.no_permission", comment: "")
                return
            }
            guard let recognizer = self.recognizer, recognizer.isAvailable else {
                self.errorMessage = NSLocalizedString("speech.error.unavailable", comment: "")
                return
            }
            do {
                try self.beginSession(recognizer: recognizer)
                self.isRecording = true
            } catch {
                self.errorMessage = error.localizedDescription
                self.cleanupSession()
            }
        }
    }

    /// Остановить запись (финальный transcript остаётся в `transcript`).
    func stop() {
        guard isRecording else { return }
        cleanupSession()
        isRecording = false
    }

    /// Сбросить накопленный текст (например, после отправки вопроса).
    func resetTranscript() {
        transcript = ""
    }

    // MARK: - Permissions

    private func requestPermissions() async -> Bool {
        // 1. Speech Recognition
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        // 2. Microphone
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Audio session

    private func beginSession(recognizer: SFSpeechRecognizer) throws {
        // Сбрасываем предыдущую задачу, если была.
        task?.cancel()
        task = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .measurement,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if #available(iOS 16.0, *) {
            req.addsPunctuation = true
        }
        self.request = req

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.transcript = text
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    self.cleanupSession()
                    self.isRecording = false
                }
            }
        }
    }

    private func cleanupSession() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }
}
