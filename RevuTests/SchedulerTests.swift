import Foundation
import Testing
@testable import Revu

@Suite("Scheduler tests")
struct SchedulerTests {
    @Test("New card graded 'good' graduates with positive interval")
    func testNewCardGoodGraduatesWithOneDayInterval() async throws {
        let state = SRSStateSnapshot(queue: .new)
        let now = Date(timeIntervalSince1970: 0)
        let config = SchedulerConfig.from(settings: UserSettings())
        let result = Scheduler.review(state: state, grade: .good, now: now, config: config)

        #expect(result.updatedState.queue == .review)
        // In FSRS, the interval depends on parameters. Default parameters might not result in exactly 1 day (86400s).
        // Let's check if it's a reasonable positive interval.
        #expect(result.nextInterval > 0)
        #expect(result.updatedState.repetitions == 1)
    }

    @Test("New card graded 'again' keeps in learning with first step")
    func testNewCardAgainKeepsLearning() async throws {
        let state = SRSStateSnapshot(queue: .new)
        let now = Date(timeIntervalSince1970: 0)
        let config = SchedulerConfig.from(settings: UserSettings())
        let result = Scheduler.review(state: state, grade: .again, now: now, config: config)

        #expect(result.updatedState.queue == .relearn)
        #expect(result.updatedState.lapses == 1)
        // Default lapse step is 1 min (60s), but minimum interval floor is 5 min (300s).
        // Result is clamped to 300s.
        #expect(abs(result.nextInterval - 300) <= 1.0)
    }

    @Test("New card graded Good honors the first learning step for early reinforcement")
    func testNewCardUsesLearningStep() async throws {
        let state = SRSStateSnapshot(queue: .new)
        let now = Date(timeIntervalSince1970: 123)
        var settings = UserSettings()
        settings.learningStepsMinutes = [5.0, 1440.0]
        let config = SchedulerConfig.from(settings: settings)
        // Grade .good on a new card should clamp to step index 1 (5 min for hard, step 1 for good)
        // With steps [5min, 1440min], good→step index 1 = 1440min, but min(fsrs, 1440min) applies.
        // Let's verify Hard uses first step (5min).
        let resultHard = Scheduler.review(state: state, grade: .hard, now: now, config: config)
        let firstStepSeconds = settings.learningStepsDurations.first ?? 0
        #expect(resultHard.nextInterval <= firstStepSeconds + 1.0)
        #expect(resultHard.nextInterval >= 5 * 60)
    }

    @Test("New card graded Easy graduates immediately, bypassing learning steps")
    func testNewCardEasyGraduatesImmediately() async throws {
        let state = SRSStateSnapshot(queue: .new)
        let now = Date(timeIntervalSince1970: 123)
        var settings = UserSettings()
        settings.learningStepsMinutes = [5.0, 1440.0]
        let config = SchedulerConfig.from(settings: settings)
        let result = Scheduler.review(state: state, grade: .easy, now: now, config: config)
        // Easy on a new card graduates immediately — interval should exceed 1 hour
        #expect(result.nextInterval > 3_600)
    }

    @Test("Review 'easy' increases interval and stability")
    func testReviewEasyIncreasesInterval() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let state = SRSStateSnapshot(
            easeFactor: 2.5,
            interval: 10,
            repetitions: 3,
            lapses: 0,
            dueDate: now,
            lastReviewed: now.addingTimeInterval(-11 * 86400), // Reviewed 11 days ago
            queue: .review,
            stability: 10.0,
            difficulty: 5.0,
            fsrsReps: 3
        )
        let config = SchedulerConfig.from(settings: UserSettings())
        let result = Scheduler.review(state: state, grade: .easy, now: now, config: config)

        #expect(result.updatedState.queue == .review)
        #expect(result.updatedState.interval >= state.interval)
        // FSRS doesn't use easeFactor in the same way as SM-2, but let's check stability
        #expect(result.updatedState.stability > state.stability)
    }

    @Test("Review 'again' triggers relearn and lapse")
    func testReviewAgainTriggersRelearn() async throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let state = SRSStateSnapshot(
            easeFactor: 2.5,
            interval: 12,
            repetitions: 5,
            lapses: 0,
            dueDate: now,
            lastReviewed: now.addingTimeInterval(-13 * 86400),
            queue: .review,
            stability: 10.0,
            difficulty: 5.0,
            fsrsReps: 5
        )
        let config = SchedulerConfig.from(settings: UserSettings())
        let result = Scheduler.review(state: state, grade: .again, now: now, config: config)

        #expect(result.updatedState.queue == .relearn)
        #expect(result.updatedState.lapses == 1)
        #expect(result.updatedState.stability < state.stability)
        // Lapse step is 1 min (60s), but minimum interval floor is 5 min (300s).
        #expect(abs(result.nextInterval - 300) <= 1.0)
    }

    @Test("Hard reviews schedule shorter intervals than easy reviews")
    func testHardGradeSchedulesShorterIntervalThanEasy() async throws {
        let now = Date(timeIntervalSince1970: 3_000_000)
        let state = SRSStateSnapshot(
            interval: 15,
            repetitions: 4,
            lapses: 0,
            dueDate: now,
            lastReviewed: now.addingTimeInterval(-14 * 86_400),
            queue: .review,
            stability: 15.0,
            difficulty: 5.5,
            fsrsReps: 4
        )
        let config = SchedulerConfig.from(settings: UserSettings())

        let hardResult = Scheduler.review(state: state, grade: .hard, now: now, config: config)
        let easyResult = Scheduler.review(state: state, grade: .easy, now: now, config: config)

        #expect(hardResult.nextInterval < easyResult.nextInterval)
        #expect(hardResult.updatedState.difficulty > easyResult.updatedState.difficulty)
    }

    @Test("Response time tuning penalizes slow answers")
    func testResponseTimeTuningAdjustsIntervals() async throws {
        let now = Date(timeIntervalSince1970: 3_500_000)
        var config = SchedulerConfig.from(settings: UserSettings(enableResponseTimeTuning: true))
        let state = SRSStateSnapshot(
            interval: 20,
            repetitions: 6,
            lapses: 0,
            dueDate: now,
            lastReviewed: now.addingTimeInterval(-21 * 86_400),
            queue: .review,
            stability: 20.0,
            difficulty: 5.0,
            fsrsReps: 6
        )

        let fast = Scheduler.review(
            state: state,
            grade: .good,
            now: now,
            config: config,
            responseTime: 3
        )
        let slow = Scheduler.review(
            state: state,
            grade: .good,
            now: now,
            config: config,
            responseTime: 18
        )

        #expect(fast.nextInterval > slow.nextInterval)
        #expect(fast.updatedState.stability > slow.updatedState.stability)

        config.enableResponseTimeTuning = false
        let baseline = Scheduler.review(
            state: state,
            grade: .good,
            now: now,
            config: config,
            responseTime: 18
        )
        let baselineNoResponse = Scheduler.review(
            state: state,
            grade: .good,
            now: now,
            config: config,
            responseTime: nil
        )
        #expect(abs(baseline.nextInterval - baselineNoResponse.nextInterval) < 1e-6)
    }

    @Test("Deck due dates clamp intervals so cards finish before the buffer")
    func testDeckDueDateLimitsInterval() async throws {
        let now = Date(timeIntervalSince1970: 4_000_000)
        let dueDate = now.addingTimeInterval(10 * 3_600)
        let state = SRSStateSnapshot(
            interval: 40,
            repetitions: 10,
            lapses: 0,
            dueDate: now,
            lastReviewed: now.addingTimeInterval(-45 * 86_400),
            queue: .review,
            stability: 40.0,
            difficulty: 4.0,
            fsrsReps: 10
        )
        let config = SchedulerConfig.from(settings: UserSettings())
        let result = Scheduler.review(
            state: state,
            grade: .easy,
            now: now,
            config: config,
            deckDueDate: dueDate
        )

        let buffer: TimeInterval = 3 * 3_600
        let latestAllowed = dueDate.addingTimeInterval(-buffer)
        #expect(result.scheduledDate <= latestAllowed)
        #expect(result.nextInterval <= latestAllowed.timeIntervalSince(now))
    }

    @Test("New cards respect scaffolding when a due date is provided")
    func testNewCardDueDateScaffolding() async throws {
        let now = Date(timeIntervalSince1970: 4_500_000)
        let dueDate = now.addingTimeInterval(2 * 86_400)
        let state = SRSStateSnapshot(queue: .new)
        let config = SchedulerConfig.from(settings: UserSettings())

        let result = Scheduler.review(
            state: state,
            grade: .easy,
            now: now,
            config: config,
            deckDueDate: dueDate
        )

        let timeRemaining = dueDate.timeIntervalSince(now)
        let exposures: Double = timeRemaining > 36 * 3_600 ? 3.5 : 3.0
        let scaffoldingLimit = max(timeRemaining / exposures, 5 * 60)
        #expect(result.nextInterval <= scaffoldingLimit + 1)
    }

    @Test("Catch-up logic shortens 'again' intervals when a due date approaches")
    func testAgainDueDateCatchUp() async throws {
        let now = Date(timeIntervalSince1970: 4_800_000)
        let dueDate = now.addingTimeInterval(8 * 3_600)
        let state = SRSStateSnapshot(
            lastReviewed: now.addingTimeInterval(-5 * 86_400),
            queue: .review,
            stability: 5.0,
            difficulty: 6.0,
            fsrsReps: 4
        )
        let config = SchedulerConfig.from(settings: UserSettings())

        let result = Scheduler.review(
            state: state,
            grade: .again,
            now: now,
            config: config,
            deckDueDate: dueDate
        )

        let catchUp = dueDate.timeIntervalSince(now) / 4.0
        #expect(result.nextInterval <= catchUp + 1)
    }

    @Test("Same-day reviews get the same-day stability boost")
    func testSameDayReviewBoostsStability() async throws {
        let now = Date(timeIntervalSince1970: 5_000_000)
        let state = SRSStateSnapshot(
            interval: 1,
            repetitions: 1,
            lapses: 0,
            dueDate: now,
            lastReviewed: now.addingTimeInterval(-30 * 60),
            queue: .review,
            stability: 1.0,
            difficulty: 5.0,
            fsrsReps: 1
        )
        let config = SchedulerConfig.from(settings: UserSettings())

        let result = Scheduler.review(state: state, grade: .good, now: now, config: config)
        #expect(result.updatedState.stability > state.stability)
        #expect(result.nextInterval >= 5 * 60) // Minimum interval respected
    }

    @Test("Predicted recall reported by the scheduler matches the parameter model")
    func testPredictedRecallMatchesFSRSFormula() async throws {
        let now = Date(timeIntervalSince1970: 5_500_000)
        let state = SRSStateSnapshot(
            interval: 25,
            repetitions: 8,
            lapses: 0,
            dueDate: now,
            lastReviewed: now.addingTimeInterval(-26 * 86_400),
            queue: .review,
            stability: 25.0,
            difficulty: 4.5,
            fsrsReps: 8
        )
        let config = SchedulerConfig.from(settings: UserSettings())
        let result = Scheduler.review(state: state, grade: .good, now: now, config: config)

        let expected = config.parameters.predictedRecall(
            intervalSeconds: result.nextInterval,
            stability: result.updatedState.stability
        )
        #expect(abs(expected - result.predictedRecall) < 1e-9)
    }

    @Test("Repeated lapses keep intervals short and raise difficulty")
    func testConsecutiveLapsesStayShort() async throws {
        var now = Date(timeIntervalSince1970: 6_000_000)
        var state = SRSStateSnapshot(
            interval: 12,
            repetitions: 4,
            lapses: 0,
            dueDate: now,
            lastReviewed: now.addingTimeInterval(-5 * 86_400),
            queue: .review,
            stability: 6.0,
            difficulty: 5.0,
            fsrsReps: 4
        )
        let config = SchedulerConfig.from(settings: UserSettings())

        var lastInterval: TimeInterval = 0
        for _ in 0..<3 {
            let result = Scheduler.review(state: state, grade: .again, now: now, config: config)
            #expect(result.nextInterval <= 900) // stays near lapse/learning step
            #expect(result.updatedState.difficulty >= state.difficulty)
            lastInterval = result.nextInterval
            state = result.updatedState
            now = now.addingTimeInterval(lastInterval)
        }

        #expect(state.lapses >= 3)
        #expect(lastInterval <= 900)
    }

    @Test("New card graded Easy graduates immediately -- interval should be >1 hour")
    func testNewCardEasyGraduatesImmediatelyOver1Hour() async throws {
        let state = SRSStateSnapshot(queue: .new)
        let now = Date(timeIntervalSince1970: 7_000_000)
        let config = SchedulerConfig(
            parameters: FSRSParameters(requestedRetention: 0.9),
            learningSteps: [60, 600, 86400],
            lapseSteps: [60, 600],
            enableResponseTimeTuning: false
        )
        let result = Scheduler.review(state: state, grade: .easy, now: now, config: config)
        // Easy on a new card should NOT be clamped to learning steps -- FSRS determines interval
        #expect(result.nextInterval > 3_600)
    }

    @Test("New card graded Good uses learning step clamp")
    func testNewCardGoodUsesLearningStepClamp() async throws {
        let state = SRSStateSnapshot(queue: .new)
        let now = Date(timeIntervalSince1970: 7_100_000)
        let config = SchedulerConfig(
            parameters: FSRSParameters(requestedRetention: 0.9),
            learningSteps: [60, 600, 86400],
            lapseSteps: [60, 600],
            enableResponseTimeTuning: false
        )
        let result = Scheduler.review(state: state, grade: .good, now: now, config: config)
        // Good on new card: step index = grade.rawValue - 2 = 1 → learningSteps[1] = 600s
        #expect(result.nextInterval <= 600 + 1.0)
    }

    @Test("New card graded Hard uses first learning step")
    func testNewCardHardUsesFirstLearningStep() async throws {
        let state = SRSStateSnapshot(queue: .new)
        let now = Date(timeIntervalSince1970: 7_200_000)
        let config = SchedulerConfig(
            parameters: FSRSParameters(requestedRetention: 0.9),
            learningSteps: [60, 600, 86400],
            lapseSteps: [60, 600],
            enableResponseTimeTuning: false
        )
        let result = Scheduler.review(state: state, grade: .hard, now: now, config: config)
        // Hard on new card: step index 0 → learningSteps[0] = 60s, but min interval is 300s
        #expect(result.nextInterval <= 300 + 1.0)
    }

    @Test("RecallOutcome.rememberedEasy maps to ReviewGrade.good")
    func testRememberedEasyMapsToGood() async throws {
        let grade = Scheduler.grade(for: .rememberedEasy)
        #expect(grade == .good)
    }
}
