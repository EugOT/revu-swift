import Foundation
import Combine
import UserNotifications

@MainActor
@Observable
final class PomodoroService {
    enum Phase: Equatable {
        case idle
        case working(session: Int)
        case shortBreak
        case longBreak
    }

    struct SessionRecord {
        let phase: Phase
        let startedAt: Date
        let duration: TimeInterval
    }

    // MARK: - Duration settings (UserDefaults-backed)

    private static let defaultWorkDuration: TimeInterval = 25 * 60
    private static let defaultShortBreakDuration: TimeInterval = 5 * 60
    private static let defaultLongBreakDuration: TimeInterval = 15 * 60
    private static let defaultSessionsBeforeLongBreak: Int = 4

    var workDuration: TimeInterval
    var shortBreakDuration: TimeInterval
    var longBreakDuration: TimeInterval
    var sessionsBeforeLongBreak: Int

    // MARK: - Timer state

    private(set) var phase: Phase = .idle
    private(set) var remaining: TimeInterval = 0
    private(set) var isPaused: Bool = false
    private(set) var completedSessions: Int = 0

    // MARK: - Session history

    private(set) var todaySessions: [SessionRecord] = []
    private(set) var consecutiveCompleted: Int = 0
    private var currentPhaseStartedAt: Date?

    var totalFocusTimeToday: TimeInterval {
        todaySessions
            .filter { if case .working = $0.phase { return true }; return false }
            .reduce(0) { $0 + $1.duration }
    }

    // MARK: - Computed

    private var timerCancellable: AnyCancellable?
    private var lastTick: Date?

    var isRunning: Bool { phase != .idle && !isPaused }
    var isActive: Bool { phase != .idle }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        workDuration = defaults.double(forKey: "pomodoro.workDuration").nonZeroOr(Self.defaultWorkDuration)
        shortBreakDuration = defaults.double(forKey: "pomodoro.shortBreakDuration").nonZeroOr(Self.defaultShortBreakDuration)
        longBreakDuration = defaults.double(forKey: "pomodoro.longBreakDuration").nonZeroOr(Self.defaultLongBreakDuration)
        let storedSessions = defaults.integer(forKey: "pomodoro.sessionsBeforeLongBreak")
        sessionsBeforeLongBreak = storedSessions > 0 ? storedSessions : Self.defaultSessionsBeforeLongBreak
    }

    // MARK: - Persistence

    func saveDurationPreferences() {
        let defaults = UserDefaults.standard
        defaults.set(workDuration, forKey: "pomodoro.workDuration")
        defaults.set(shortBreakDuration, forKey: "pomodoro.shortBreakDuration")
        defaults.set(longBreakDuration, forKey: "pomodoro.longBreakDuration")
        defaults.set(sessionsBeforeLongBreak, forKey: "pomodoro.sessionsBeforeLongBreak")
    }

    // MARK: - Controls

    func start() {
        let session = completedSessions + 1
        phase = .working(session: session)
        remaining = workDuration
        isPaused = false
        currentPhaseStartedAt = Date()
        startTimer()
    }

    func pause() {
        isPaused = true
        stopTimer()
    }

    func resume() {
        isPaused = false
        startTimer()
    }

    func skip() {
        stopTimer()
        switch phase {
        case .working:
            completedSessions += 1
            advancePhase()
        case .shortBreak, .longBreak:
            advancePhase()
        case .idle:
            break
        }
    }

    func reset() {
        stopTimer()
        phase = .idle
        remaining = 0
        isPaused = false
        completedSessions = 0
        todaySessions = []
        consecutiveCompleted = 0
        currentPhaseStartedAt = nil
    }

    // MARK: - Timer

    private func startTimer() {
        lastTick = Date()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.tick(now)
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        lastTick = nil
    }

    private func tick(_ now: Date) {
        guard let last = lastTick else { return }
        let elapsed = now.timeIntervalSince(last)
        lastTick = now
        remaining = max(0, remaining - elapsed)

        if remaining <= 0 {
            stopTimer()
            handlePhaseComplete()
        }
    }

    private func handlePhaseComplete() {
        switch phase {
        case .working:
            completedSessions += 1
            sendNotification(title: "Work session complete!", body: "Time for a break.")
            advancePhase()
        case .shortBreak, .longBreak:
            sendNotification(title: "Break's over!", body: "Ready for another session?")
            advancePhase()
        case .idle:
            break
        }
    }

    private func advancePhase() {
        // Record completed phase
        let completedDuration: TimeInterval
        switch phase {
        case .working:
            completedDuration = workDuration
            consecutiveCompleted += 1
        case .shortBreak:
            completedDuration = shortBreakDuration
        case .longBreak:
            completedDuration = longBreakDuration
        case .idle:
            completedDuration = 0
        }
        if phase != .idle {
            todaySessions.append(SessionRecord(
                phase: phase,
                startedAt: currentPhaseStartedAt ?? Date(),
                duration: completedDuration
            ))
        }

        // Advance to next phase
        switch phase {
        case .working:
            if completedSessions % sessionsBeforeLongBreak == 0 {
                phase = .longBreak
                remaining = longBreakDuration
            } else {
                phase = .shortBreak
                remaining = shortBreakDuration
            }
            currentPhaseStartedAt = Date()
            startTimer()
        case .shortBreak, .longBreak:
            let session = completedSessions + 1
            phase = .working(session: session)
            remaining = workDuration
            currentPhaseStartedAt = Date()
            startTimer()
        case .idle:
            break
        }
    }

    // MARK: - Notifications

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "pomodoro-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double {
        self > 0 ? self : fallback
    }
}
