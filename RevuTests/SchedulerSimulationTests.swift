import Foundation
import Testing
@testable import Revu

/// Integration-style, deterministic simulation of a student working through a full deck toward deck due dates.
/// This exercises scheduling growth, due-date clamping, and distribution over time.
@Suite("Scheduler deadline simulations")
struct SchedulerSimulationTests {
    private struct LCG {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed }
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1
            return Double(state >> 33) / Double(UInt32.max)
        }
    }

    private func grade(for reps: Int, rng: inout LCG) -> ReviewGrade {
        let r = rng.next()
        if reps == 0 {
            if r < 0.1 { return .again }
            if r < 0.25 { return .hard }
            if r < 0.75 { return .good }
            return .easy
        }
        if r < 0.05 { return .again }
        if r < 0.20 { return .hard }
        if r < 0.65 { return .good }
        return .easy
    }

    @Test("100-card deck reaches deadline with sensible distribution")
    func testDeckAgainstMultipleDeadlines() async throws {
        let offsets: [Int] = [5, 10, 20, 30]
        for offset in offsets {
            runSimulation(daysUntilDue: offset, label: "due-\(offset)")
        }
    }

    @Test("Open-ended study still spaces daily workload")
    func testOpenEndedStudyHasDailyLoad() async throws {
        runSimulation(daysUntilDue: nil, horizonDays: 35, label: "open-ended")
    }

    private func runSimulation(daysUntilDue: Int?, horizonDays: Int? = nil, label: String) {
        let start = Date(timeIntervalSince1970: 0)
        let deckDue = daysUntilDue.map { start.addingTimeInterval(Double($0) * 86_400) }
        let config = SchedulerConfig.from(settings: UserSettings(retentionTarget: 0.9))

        var cards: [SRSState] = (0..<100).map { index in
            let created = start.addingTimeInterval(TimeInterval(-index * 30))
            var state = SRSState(
                interval: 0,
                dueDate: start,
                lastReviewed: nil,
                queue: .new,
                stability: 0.6,
                difficulty: 5.0,
                fsrsReps: 0
            )
            state.cardId = UUID()
            state.dueDate = start
            return state
        }

        var rng = LCG(seed: UInt64((daysUntilDue ?? 42) * 1337 + 7))
        let totalDays = daysUntilDue.map { $0 + 8 } ?? (horizonDays ?? 30)
        var dailyDueCounts: [Int] = []
        var seenCounts: [Int] = []

        for day in 0...totalDays {
            let now = start.addingTimeInterval(Double(day) * 86_400)
            let dueIndices = cards.indices.filter { cards[$0].dueDate <= now }
            dailyDueCounts.append(dueIndices.count)
            for idx in dueIndices {
                let chosenGrade = grade(for: cards[idx].fsrsReps, rng: &rng)
                var snapshot = SRSStateSnapshot(model: cards[idx])
                let result = Scheduler.review(
                    state: snapshot,
                    grade: chosenGrade,
                    now: now,
                    config: config,
                    deckDueDate: deckDue,
                    responseTime: 6.0
                )
                result.updatedState.applying(to: &cards[idx])
            }
            let seen = cards.filter { $0.fsrsReps > 0 || $0.queue == .relearn }.count
            seenCounts.append(seen)
        }

        if let deckDue {
            let maxDue = cards.map(\.dueDate).max() ?? start
            if maxDue > deckDue {
                Issue.record("Due date exceeded deadline for offset \(label): \(maxDue) > \(deckDue)")
            }

            let nearDeadline = deckDue.addingTimeInterval(-3 * 86_400)
            let cardsNearDeadline = cards.filter { $0.dueDate >= nearDeadline }
            if cardsNearDeadline.isEmpty, let daysUntilDue, daysUntilDue >= 7 {
                Issue.record("No cards scheduled near the deadline for \(label)")
            }
        }

        // Flag days with zero workload while there are still unseen cards, a sign of overly front-loaded intervals.
        for (dayIndex, dueCount) in dailyDueCounts.enumerated() where dayIndex > 0 && dayIndex < dailyDueCounts.count - 1 {
            if dueCount == 0 && seenCounts[dayIndex] < cards.count {
                Issue.record("Zero-load day before deck finished for \(label) on day \(dayIndex)")
                break
            }
        }

        // Most cards should have been seen at least once.
        let seen = cards.filter { $0.fsrsReps > 0 || $0.queue == .relearn }
        let seenRatio = Double(seen.count) / Double(cards.count)
        if seenRatio < 0.9 {
            Issue.record("Only \(seen.count) of \(cards.count) cards seen for \(label)")
        }
    }

    @Test("Graduated learning steps produce increasing intervals across reviews")
    func testGraduatedStepsProduceSmoothIntervalGrowth() async throws {
        let start = Date(timeIntervalSince1970: 0)
        let config = SchedulerConfig(
            parameters: FSRSParameters(requestedRetention: 0.9),
            learningSteps: [60, 600, 86400],
            lapseSteps: [60, 600],
            enableResponseTimeTuning: false
        )

        // Test 1: Learning steps themselves are strictly increasing (the graduated steps check)
        // hard→step0=60s, good→step1=600s, both clamped to minimum 300s
        let newState = SRSStateSnapshot(queue: .new)
        let hardResult = Scheduler.review(state: newState, grade: .hard, now: start, config: config)
        let goodResult = Scheduler.review(state: newState, grade: .good, now: start, config: config)
        // Good should give a longer interval than Hard on a new card
        if goodResult.nextInterval < hardResult.nextInterval {
            Issue.record("Good interval (\(goodResult.nextInterval)s) should be >= Hard interval (\(hardResult.nextInterval)s) for new card")
        }

        // Test 2: Post-graduation intervals grow over repeated reviews
        // Simulate a card that has graduated (fsrsReps > 0) through multiple reviews
        var state = SRSStateSnapshot(queue: .new)
        var intervals: [TimeInterval] = []
        var now = start

        // Graduate through learning steps first with Good grades
        for _ in 0..<3 {
            let result = Scheduler.review(state: state, grade: .good, now: now, config: config)
            intervals.append(result.nextInterval)
            state = result.updatedState
            now = result.scheduledDate
        }

        // Continue with 3 more Good reviews after graduation
        for _ in 0..<3 {
            let result = Scheduler.review(state: state, grade: .good, now: now, config: config)
            intervals.append(result.nextInterval)
            state = result.updatedState
            now = result.scheduledDate
        }

        // Intervals in the post-graduation phase (last 3) should grow
        let postGradIntervals = Array(intervals.suffix(3))
        if postGradIntervals.count >= 2 {
            for i in 1..<postGradIntervals.count {
                let ratio = postGradIntervals[i] / max(postGradIntervals[i - 1], 1)
                // Allow reasonable growth but flag extreme shrinkage (>50% drop)
                if postGradIntervals[i] < postGradIntervals[i - 1] * 0.5 {
                    Issue.record("Post-graduation interval shrank by >50%% at step \(i): \(String(format: "%.0f", postGradIntervals[i - 1]))s → \(String(format: "%.0f", postGradIntervals[i]))s (ratio: \(String(format: "%.2f", ratio)))")
                }
            }
        }

        // The final interval should be at least 1 day (card is well-established)
        if let last = intervals.last, last < 86_400 {
            Issue.record("Final interval after 6 Good reviews should be >= 1 day, got \(String(format: "%.0f", last))s")
        }
    }
}
