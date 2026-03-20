import Foundation
import Testing
@testable import Revu

@Suite("PomodoroService")
struct PomodoroServiceTests {

    @Test("Initial state is idle")
    @MainActor
    func initialState() {
        let service = PomodoroService()
        #expect(service.phase == .idle)
        #expect(service.remaining == 0)
        #expect(!service.isActive)
        #expect(!service.isRunning)
    }

    @Test("Start begins a work session")
    @MainActor
    func startBeginsWork() {
        let service = PomodoroService()
        service.workDuration = 10
        service.start()
        #expect(service.phase == .working(session: 1))
        #expect(service.remaining == 10)
        #expect(service.isActive)
        #expect(service.isRunning)
    }

    @Test("Pause stops the timer")
    @MainActor
    func pauseStopsTimer() {
        let service = PomodoroService()
        service.start()
        service.pause()
        #expect(service.isPaused)
        #expect(!service.isRunning)
        #expect(service.isActive)
    }

    @Test("Resume restarts the timer")
    @MainActor
    func resumeRestartsTimer() {
        let service = PomodoroService()
        service.start()
        service.pause()
        service.resume()
        #expect(!service.isPaused)
        #expect(service.isRunning)
    }

    @Test("Reset returns to idle")
    @MainActor
    func resetReturnsToIdle() {
        let service = PomodoroService()
        service.start()
        service.reset()
        #expect(service.phase == .idle)
        #expect(service.remaining == 0)
        #expect(service.completedSessions == 0)
    }

    @Test("Skip advances to next phase")
    @MainActor
    func skipAdvancesPhase() {
        let service = PomodoroService()
        service.start()
        service.skip()
        #expect(service.phase == .shortBreak)
        #expect(service.completedSessions == 1)
    }

    @Test("Skip records session in todaySessions")
    @MainActor
    func skipRecordsSession() {
        let service = PomodoroService()
        service.workDuration = 10
        service.start()
        service.skip()
        #expect(service.todaySessions.count == 1)
        #expect(service.todaySessions[0].duration == 10)
    }

    @Test("Reset clears todaySessions")
    @MainActor
    func resetClearsSessions() {
        let service = PomodoroService()
        service.workDuration = 10
        service.start()
        service.skip()
        service.reset()
        #expect(service.todaySessions.isEmpty)
        #expect(service.consecutiveCompleted == 0)
    }

    @Test("totalFocusTimeToday sums work session durations")
    @MainActor
    func totalFocusTimeTodayTest() {
        let service = PomodoroService()
        service.workDuration = 600
        service.shortBreakDuration = 5
        service.start()
        service.skip() // work → short break (records 600s work)
        service.skip() // short break → work (records 5s break)
        #expect(service.totalFocusTimeToday == 600)
    }

    @Test("consecutiveCompleted increments on work phase skip")
    @MainActor
    func consecutiveCompletedIncrements() {
        let service = PomodoroService()
        service.workDuration = 10
        service.start()
        service.skip() // work → short break: consecutive = 1
        #expect(service.consecutiveCompleted == 1)
        service.skip() // short break → work
        service.skip() // work → short break: consecutive = 2
        #expect(service.consecutiveCompleted == 2)
    }

    @Test("Default durations match expected values")
    @MainActor
    func defaultDurations() {
        let service = PomodoroService()
        #expect(service.workDuration == 25 * 60)
        #expect(service.shortBreakDuration == 5 * 60)
        #expect(service.longBreakDuration == 15 * 60)
        #expect(service.sessionsBeforeLongBreak == 4)
    }
}
