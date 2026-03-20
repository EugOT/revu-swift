import Foundation
import Testing
@testable import Revu

@Suite("FSRS parameter sanity checks")
struct FSRSParametersTests {
    @Test("Initial difficulty decreases with easier grades")
    func testInitialDifficultyOrdering() throws {
        let parameters = FSRSParameters(requestedRetention: 0.9)
        let again = parameters.initialDifficulty(for: .again)
        let easy = parameters.initialDifficulty(for: .easy)

        #expect(again > easy)
        #expect((1.0...10.0).contains(again))
        #expect((1.0...10.0).contains(easy))
    }

    @Test("Recall boosts stability and better grades grow it more")
    func testStabilityAfterRecallOrdering() throws {
        let parameters = FSRSParameters(requestedRetention: 0.9)
        let retrievability = parameters.retrievability(elapsedDays: 10, stability: 10)

        let hardStability = parameters.stabilityAfterRecall(
            from: 10,
            difficulty: 6,
            grade: .hard,
            retrievability: retrievability,
            elapsedDays: 10
        )
        let easyStability = parameters.stabilityAfterRecall(
            from: 10,
            difficulty: 4,
            grade: .easy,
            retrievability: retrievability,
            elapsedDays: 10
        )

        #expect(hardStability > 10)
        #expect(easyStability > hardStability)
    }

    @Test("Lapses increase difficulty but stay clamped")
    func testDifficultyAfterLapseClamps() throws {
        let parameters = FSRSParameters(requestedRetention: 0.9)
        let nearTop = parameters.difficultyAfterLapse(from: 9.9)
        let lower = parameters.difficultyAfterLapse(from: 4.0)

        #expect(nearTop <= 10.0)
        #expect(nearTop >= 9.9)
        #expect(lower > 4.0)
    }

    @Test("Lapse stability depends on retrievability sensitivity")
    func testStabilityAfterLapseRespondsToRetrievability() throws {
        let parameters = FSRSParameters(requestedRetention: 0.9)
        let forgiving = parameters.stabilityAfterLapse(
            difficulty: 3,
            previousStability: 30,
            retrievability: 0.85
        )
        let harsh = parameters.stabilityAfterLapse(
            difficulty: 3,
            previousStability: 30,
            retrievability: 0.2
        )

        #expect(harsh < forgiving)
        #expect(forgiving > parameters.minimumStability)
    }

    @Test("Intervals grow with higher target retention")
    func testIntervalsReflectRetentionTarget() throws {
        let conservative = FSRSParameters(requestedRetention: 0.85)
        let ambitious = FSRSParameters(requestedRetention: 0.97)

        let conservativeInterval = conservative.intervalSeconds(for: 12)
        let ambitiousInterval = ambitious.intervalSeconds(for: 12)

        #expect(ambitiousInterval < conservativeInterval)
    }

    @Test("Retrievability stays within configured clamps")
    func testRetrievabilityClamping() throws {
        let parameters = FSRSParameters(requestedRetention: 0.9)
        let minRetr = parameters.retrievability(elapsedDays: 10_000, stability: 0.2)
        let maxRetr = parameters.retrievability(elapsedDays: 0, stability: 100)

        #expect(minRetr >= parameters.weights.minimumRetrievability)
        #expect(maxRetr <= 0.999)
    }
}
