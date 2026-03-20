import AppKit
import Combine

@MainActor
@Observable
final class PomodoroSoundService {
    enum CompletionSound: String, CaseIterable, Identifiable {
        case chime = "Glass"
        case bell = "Hero"
        case ding = "Ping"
        case none = "None"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .chime: return "Chime"
            case .bell: return "Bell"
            case .ding: return "Ding"
            case .none: return "None"
            }
        }
    }

    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "pomodoro.notificationsEnabled") }
    }
    var completionSound: CompletionSound {
        didSet { UserDefaults.standard.set(completionSound.rawValue, forKey: "pomodoro.completionSound") }
    }
    var focusTickingEnabled: Bool {
        didSet { UserDefaults.standard.set(focusTickingEnabled, forKey: "pomodoro.focusTickingEnabled") }
    }
    var volume: Double {
        didSet { UserDefaults.standard.set(volume, forKey: "pomodoro.volume") }
    }

    private var tickTimer: AnyCancellable?

    init() {
        let defaults = UserDefaults.standard
        notificationsEnabled = defaults.object(forKey: "pomodoro.notificationsEnabled") as? Bool ?? true
        completionSound = CompletionSound(rawValue: defaults.string(forKey: "pomodoro.completionSound") ?? "") ?? .chime
        focusTickingEnabled = defaults.object(forKey: "pomodoro.focusTickingEnabled") as? Bool ?? false
        let storedVolume = defaults.double(forKey: "pomodoro.volume")
        volume = storedVolume > 0 ? storedVolume : 0.5
    }

    func playCompletionSound() {
        guard completionSound != .none else { return }
        guard let sound = NSSound(named: NSSound.Name(completionSound.rawValue)) else { return }
        sound.volume = Float(volume)
        sound.play()
    }

    func previewSound(_ sound: CompletionSound) {
        guard sound != .none else { return }
        guard let nsSound = NSSound(named: NSSound.Name(sound.rawValue)) else { return }
        nsSound.volume = Float(volume)
        nsSound.play()
    }

    func startTicking() {
        guard focusTickingEnabled else { return }
        tickTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard let sound = NSSound(named: NSSound.Name("Tink")) else { return }
                sound.volume = Float(self.volume * 0.3)
                sound.play()
            }
    }

    func stopTicking() {
        tickTimer?.cancel()
        tickTimer = nil
    }
}
