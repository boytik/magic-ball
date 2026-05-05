import Foundation
import AVFoundation
import Combine

/// Фоновая музыка для атмосферы. Луп, плавные fade-in/out.
///
/// Категория аудио-сессии — `.ambient` с `.mixWithOthers`, чтобы:
/// - мы не глушили чужую музыку (Spotify/Apple Music);
/// - наш трек уходил в тишину при включённом silent switch.
///
/// Тоггл `isEnabled` персистится в UserDefaults.
@MainActor
final class MusicPlayer: ObservableObject {

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: enabledKey)
            if isEnabled {
                play()
            } else {
                stop()
            }
        }
    }

    private let enabledKey = "stellara.music.enabled.v1"
    private let defaults: UserDefaults
    private var player: AVAudioPlayer?
    private var stopTask: Task<Void, Never>?

    /// Целевая громкость, до которой делаем fade-in.
    private let targetVolume: Float = 0.30

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // По умолчанию музыка включена.
        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(true, forKey: enabledKey)
        }
        self.isEnabled = defaults.bool(forKey: enabledKey)
        prepare()
    }

    // MARK: - Public

    /// Запустить (если включено и не играет).
    func play() {
        guard isEnabled else { return }
        guard let player else {
            // Если ранее не получилось подготовиться — попробуем ещё раз.
            prepare()
            guard let p = self.player else { return }
            startFadeIn(p)
            return
        }
        // Если в процессе остановки — отменяем.
        stopTask?.cancel()
        stopTask = nil

        if !player.isPlaying {
            startFadeIn(player)
        }
    }

    /// Остановить с фейдом.
    func stop() {
        guard let player, player.isPlaying else { return }
        player.setVolume(0.0, fadeDuration: 0.6)

        stopTask?.cancel()
        stopTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.player?.pause()
        }
    }

    // MARK: - Setup

    private func prepare() {
        guard let url = Bundle.main.url(forResource: "MagicMusic", withExtension: "mp3") else {
            #if DEBUG
            print("MusicPlayer: MagicMusic.mp3 not found in bundle")
            #endif
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)

            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0.0
            p.prepareToPlay()
            self.player = p
        } catch {
            #if DEBUG
            print("MusicPlayer prepare error:", error)
            #endif
        }
    }

    private func startFadeIn(_ player: AVAudioPlayer) {
        player.volume = 0.0
        player.play()
        player.setVolume(targetVolume, fadeDuration: 1.5)
    }
}
