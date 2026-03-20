import XCTest
@testable import Revu

final class ConfusionDetectorTests: XCTestCase {

    func testHighPredictedRecallWrongScoresHigherThanLowPredictedRecallWrong() {
        let detector = ConfusionDetector(expectedResponseMs: 16_000)

        let highExpected = detector.score(input: .init(
            outcome: .forgot,
            elapsedMs: 4_000,
            predictedRecallAtStart: 0.92,
            consecutiveFailures: 0,
            repeatedConcept: false
        ))

        let lowExpected = detector.score(input: .init(
            outcome: .forgot,
            elapsedMs: 4_000,
            predictedRecallAtStart: 0.20,
            consecutiveFailures: 0,
            repeatedConcept: false
        ))

        XCTAssertGreaterThan(highExpected.score, lowExpected.score)
        XCTAssertTrue(highExpected.reasons.contains(.highExpectationMiss) || highExpected.reasons.contains(.expectationGap))
    }

    func testSlowWrongScoresHigherThanFastWrong() {
        let detector = ConfusionDetector(expectedResponseMs: 10_000)

        let slowWrong = detector.score(input: .init(
            outcome: .forgot,
            elapsedMs: 30_000,
            predictedRecallAtStart: 0.70,
            consecutiveFailures: 0,
            repeatedConcept: false
        ))

        let fastWrong = detector.score(input: .init(
            outcome: .forgot,
            elapsedMs: 1_500,
            predictedRecallAtStart: 0.70,
            consecutiveFailures: 0,
            repeatedConcept: false
        ))

        XCTAssertGreaterThan(slowWrong.score, fastWrong.score)
        XCTAssertTrue(slowWrong.reasons.contains(.slowWrongAnswer) || slowWrong.reasons.contains(.slowResponse))
    }

    func testConsecutiveFailuresIncreaseScore() {
        let detector = ConfusionDetector(expectedResponseMs: 16_000)

        let singleFailure = detector.score(input: .init(
            outcome: .forgot,
            elapsedMs: 5_000,
            predictedRecallAtStart: 0.60,
            consecutiveFailures: 1,
            repeatedConcept: false
        ))

        let streakFailures = detector.score(input: .init(
            outcome: .forgot,
            elapsedMs: 5_000,
            predictedRecallAtStart: 0.60,
            consecutiveFailures: 3,
            repeatedConcept: false
        ))

        XCTAssertGreaterThan(streakFailures.score, singleFailure.score)
        XCTAssertTrue(streakFailures.reasons.contains(.consecutiveFailures))
    }
}

