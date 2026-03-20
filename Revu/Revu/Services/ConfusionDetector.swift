import Foundation

/// Pure scorer that estimates how "stuck" a learner is based on multiple signals.
struct ConfusionDetector: Sendable {
    struct Input: Sendable {
        var outcome: RecallOutcome
        var elapsedMs: Int?
        var predictedRecallAtStart: Double?
        var consecutiveFailures: Int
        var repeatedConcept: Bool

        init(
            outcome: RecallOutcome,
            elapsedMs: Int? = nil,
            predictedRecallAtStart: Double? = nil,
            consecutiveFailures: Int = 0,
            repeatedConcept: Bool = false
        ) {
            self.outcome = outcome
            self.elapsedMs = elapsedMs
            self.predictedRecallAtStart = predictedRecallAtStart
            self.consecutiveFailures = max(0, consecutiveFailures)
            self.repeatedConcept = repeatedConcept
        }
    }

    struct Result: Sendable, Equatable {
        var score: Double
        var reasons: [Reason]
    }

    enum Reason: String, CaseIterable, Codable, Sendable {
        case wrongAnswer
        case expectationGap
        case highExpectationMiss
        case slowResponse
        case slowWrongAnswer
        case consecutiveFailures
        case repeatedConcept
    }

    var expectedResponseMs: Int

    init(expectedResponseMs: Int = 16_000) {
        self.expectedResponseMs = max(2_000, expectedResponseMs)
    }

    func score(input: Input) -> Result {
        var score: Double = 0
        var reasons: [Reason] = []

        let isWrong = (input.outcome == .forgot)

        if isWrong {
            score += 0.45
            reasons.append(.wrongAnswer)
        }

        if isWrong, let predicted = input.predictedRecallAtStart {
            if predicted >= 0.85 {
                score += 0.25
                reasons.append(.highExpectationMiss)
            } else if predicted >= 0.70 {
                score += 0.15
                reasons.append(.expectationGap)
            }
        }

        if let elapsedMs = input.elapsedMs {
            let ratio = Double(max(0, elapsedMs)) / Double(expectedResponseMs)
            if isWrong, ratio >= 1.25 {
                score += 0.15
                reasons.append(.slowWrongAnswer)
            } else if ratio >= 1.5 {
                score += 0.08
                reasons.append(.slowResponse)
            } else if isWrong, ratio >= 0.9 {
                score += 0.06
                reasons.append(.slowResponse)
            }
        }

        if input.consecutiveFailures >= 2 {
            score += min(0.22, 0.08 * Double(input.consecutiveFailures - 1))
            reasons.append(.consecutiveFailures)
        }

        if input.repeatedConcept {
            score += 0.08
            reasons.append(.repeatedConcept)
        }

        return Result(score: min(1, max(0, score)), reasons: reasons)
    }
}

