import Foundation

struct SchedulerConfig: Equatable {
    var parameters: FSRSParameters
    var learningSteps: [TimeInterval]
    var lapseSteps: [TimeInterval]
    var enableResponseTimeTuning: Bool

    init(
        parameters: FSRSParameters,
        learningSteps: [TimeInterval],
        lapseSteps: [TimeInterval],
        enableResponseTimeTuning: Bool
    ) {
        self.parameters = parameters
        self.learningSteps = learningSteps
        self.lapseSteps = lapseSteps
        self.enableResponseTimeTuning = enableResponseTimeTuning
    }

    static func from(settings: UserSettings) -> SchedulerConfig {
        SchedulerConfig(
            parameters: FSRSParameters(requestedRetention: settings.retentionTarget),
            learningSteps: settings.learningStepsDurations,
            lapseSteps: settings.lapseStepsDurations,
            enableResponseTimeTuning: settings.enableResponseTimeTuning
        )
    }
}

struct FSRSParameters: Equatable {
    struct Weights: Equatable {
        var initialStabilityAgain: Double = 0.212
        var initialStabilityHard: Double = 1.2931
        var initialStabilityGood: Double = 2.3065
        var initialStabilityEasy: Double = 8.2956
        var initialDifficultyBase: Double = 6.4133
        var initialDifficultySlope: Double = 0.8334
        var lapseDifficultyFloor: Double = 3.0194
        var recallScaling: Double = 0.001
        var recallDifficultyExponent: Double = 1.8722
        var recallStabilityExponent: Double = 0.1666
        var recallRetrievabilitySensitivity: Double = 0.796
        var gradeBase: Double = 1.4835
        var gradeSlope: Double = 0.0614
        var lapseStabilityCoefficient: Double = 0.2629
        var lapseDifficultyExponent: Double = 1.6483
        var lapseStabilityExponent: Double = 0.6014
        var lapseRetrievabilitySensitivity: Double = 1.8729
        var sameDayGrowth: Double = 1.8729
        var sameDayOffset: Double = 0.5425
        var sameDayDamping: Double = 0.0912
        var decayExponent: Double = 0.0658
        var lapseDifficultyPenalty: Double = 0.1542

        var minimumStability: Double = 0.05
        var minimumRetrievability: Double = 0.01

    }

    let requestedRetention: Double
    var weights: Weights = Weights()

    init(requestedRetention: Double) {
        self.requestedRetention = min(max(requestedRetention, 0.7), 0.97)
    }

    var minimumStability: Double { weights.minimumStability }
    private var difficultyRange: ClosedRange<Double> { 1.0...10.0 }
    private var forgettingFactor: Double {
        pow(requestedRetention, -1.0 / weights.decayExponent) - 1.0
    }

    func clampDifficulty(_ value: Double) -> Double {
        min(max(value, difficultyRange.lowerBound), difficultyRange.upperBound)
    }

    func initialDifficulty(for grade: ReviewGrade) -> Double {
        let offset = Double(grade.rawValue) - 3.0
        let candidate = weights.initialDifficultyBase - weights.initialDifficultySlope * offset
        return clampDifficulty(candidate)
    }

    func initialStability(for grade: ReviewGrade) -> Double {
        let base: Double
        switch grade {
        case .again:
            base = weights.initialStabilityAgain
        case .hard:
            base = weights.initialStabilityHard
        case .good:
            base = weights.initialStabilityGood
        case .easy:
            base = weights.initialStabilityEasy
        }
        return max(minimumStability, base)
    }

    func nextDifficulty(from current: Double, grade: ReviewGrade) -> Double {
        let offset = Double(grade.rawValue) - 3.0
        let adjusted = current - weights.initialDifficultySlope * offset
        return clampDifficulty(adjusted)
    }

    func stabilityAfterRecall(
        from stability: Double,
        difficulty: Double,
        grade: ReviewGrade,
        retrievability: Double,
        elapsedDays: Double
    ) -> Double {
        let baseStability = max(minimumStability, stability)
        if elapsedDays < 1.0 {
            let exponent = weights.sameDayGrowth * (Double(grade.rawValue) - 3.0 + weights.sameDayOffset)
            let scale = exp(exponent * pow(baseStability, -weights.sameDayDamping))
            return max(minimumStability, baseStability * max(1.0, scale))
        }

        let difficultyFactor = pow(max(1.0, 11.0 - difficulty), weights.recallDifficultyExponent)
        let stabilityFactor = pow(baseStability, -weights.recallStabilityExponent)
        let retrievalFactor = exp((1.0 - retrievability) * weights.recallRetrievabilitySensitivity) - 1.0
        let gradeFactor = max(0.5, weights.gradeBase + weights.gradeSlope * (Double(grade.rawValue) - 2.0))
        let growth = 1.0 + weights.recallScaling * difficultyFactor * stabilityFactor * max(0.0, retrievalFactor) * gradeFactor
        return max(minimumStability, baseStability * max(1.0, growth))
    }

    func stabilityAfterLapse(
        difficulty: Double,
        previousStability: Double,
        retrievability: Double
    ) -> Double {
        let baseDifficulty = max(1.0, difficulty)
        let baseStability = max(minimumStability, previousStability)
        let degraded = weights.lapseStabilityCoefficient
            * pow(baseDifficulty, -weights.lapseDifficultyExponent)
            * pow(baseStability, weights.lapseStabilityExponent)
            * exp((retrievability - 1.0) * weights.lapseRetrievabilitySensitivity)
        return max(minimumStability, degraded)
    }

    func difficultyAfterLapse(from current: Double) -> Double {
        let base = max(current, weights.lapseDifficultyFloor)
        let headroom = max(0.0, difficultyRange.upperBound - base)
        let increment = headroom * weights.lapseDifficultyPenalty
        return clampDifficulty(base + increment)
    }

    func intervalSeconds(for stability: Double) -> TimeInterval {
        let baseStability = max(minimumStability, stability)
        let retention = max(requestedRetention, 0.5)
        let growth = pow(retention, -1.0 / weights.decayExponent) - 1.0
        let days = max(0.01, baseStability / forgettingFactor * growth)
        return days * 86_400.0
    }

    func retrievability(elapsedDays: Double, stability: Double) -> Double {
        let baseStability = max(minimumStability, stability)
        let ratio = max(0.0, elapsedDays) / baseStability
        let retrievability = pow(1.0 + forgettingFactor * ratio, -weights.decayExponent)
        return min(max(retrievability, weights.minimumRetrievability), 0.999)
    }

    func predictedRecall(intervalSeconds: TimeInterval, stability: Double) -> Double {
        let days = max(0.0, intervalSeconds / 86_400.0)
        return retrievability(elapsedDays: days, stability: stability)
    }

    func legacyEase(from difficulty: Double) -> Double {
        let normalized = (difficultyRange.upperBound - clampDifficulty(difficulty)) / (difficultyRange.upperBound - difficultyRange.lowerBound)
        return min(3.0, max(1.3, 1.3 + normalized * 1.7))
    }
}

enum ReviewGrade: Int, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

enum RecallOutcome: CaseIterable, Hashable {
    case forgot
    case rememberedEasy
}

struct SRSStateSnapshot: Equatable {
    var id: UUID
    var cardId: UUID
    var easeFactor: Double
    var interval: Int
    var repetitions: Int
    var lapses: Int
    var dueDate: Date
    var lastReviewed: Date?
    var queue: SRSState.Queue
    var stability: Double
    var difficulty: Double
    var fsrsReps: Int
    var lastElapsedSeconds: Double?

    init(
        id: UUID = UUID(),
        cardId: UUID = UUID(),
        easeFactor: Double = 2.5,
        interval: Int = 0,
        repetitions: Int = 0,
        lapses: Int = 0,
        dueDate: Date = .distantPast,
        lastReviewed: Date? = nil,
        queue: SRSState.Queue = .new,
        stability: Double = 0.6,
        difficulty: Double = 5.0,
        fsrsReps: Int = 0,
        lastElapsedSeconds: Double? = nil
    ) {
        self.id = id
        self.cardId = cardId
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.lapses = lapses
        self.dueDate = dueDate
        self.lastReviewed = lastReviewed
        self.queue = queue
        self.stability = stability
        self.difficulty = difficulty
        self.fsrsReps = fsrsReps
        self.lastElapsedSeconds = lastElapsedSeconds
    }

    init(model: SRSState) {
        id = model.id
        cardId = model.cardId
        easeFactor = model.easeFactor
        interval = model.interval
        repetitions = model.repetitions
        lapses = model.lapses
        dueDate = model.dueDate
        lastReviewed = model.lastReviewed
        queue = model.queue
        stability = model.stability
        difficulty = model.difficulty
        fsrsReps = model.fsrsReps
        lastElapsedSeconds = model.lastElapsedSeconds
    }

    func applying(to state: inout SRSState) {
        state.id = id
        state.cardId = cardId
        state.easeFactor = easeFactor
        state.interval = interval
        state.repetitions = repetitions
        state.lapses = lapses
        state.dueDate = dueDate
        state.lastReviewed = lastReviewed
        state.queue = queue
        state.stability = stability
        state.difficulty = difficulty
        state.fsrsReps = fsrsReps
        state.lastElapsedSeconds = lastElapsedSeconds
    }
}

struct ScheduleResult: Equatable {
    var updatedState: SRSStateSnapshot
    var nextInterval: TimeInterval
    var predictedRecall: Double
    var scheduledDate: Date
}

enum Scheduler {
    static func preview(
        state: SRSStateSnapshot,
        outcome: RecallOutcome,
        now: Date = .init(),
        settings: UserSettings,
        deckDueDate: Date? = nil,
        responseTime: TimeInterval? = nil
    ) -> ScheduleResult {
        review(
            state: state,
            grade: grade(for: outcome),
            now: now,
            config: .from(settings: settings),
            deckDueDate: deckDueDate,
            responseTime: responseTime
        )
    }

    static func review(
        state: SRSStateSnapshot,
        outcome: RecallOutcome,
        now: Date = .init(),
        settings: UserSettings,
        deckDueDate: Date? = nil,
        responseTime: TimeInterval? = nil
    ) -> ScheduleResult {
        review(
            state: state,
            grade: grade(for: outcome),
            now: now,
            config: .from(settings: settings),
            deckDueDate: deckDueDate,
            responseTime: responseTime
        )
    }

    static func review(
        state: SRSStateSnapshot,
        grade: ReviewGrade,
        now: Date = .init(),
        config: SchedulerConfig,
        deckDueDate: Date? = nil,
        responseTime: TimeInterval? = nil
    ) -> ScheduleResult {
        let parameters = config.parameters
        var updated = state
        updated.lastReviewed = now
        updated.lastElapsedSeconds = responseTime

        let elapsedDays: Double
        if let last = state.lastReviewed {
            elapsedDays = max(0.0, now.timeIntervalSince(last) / 86_400.0)
        } else {
            elapsedDays = 0.0
        }

        var retrievability: Double
        if state.fsrsReps > 0 {
            retrievability = parameters.retrievability(
                elapsedDays: elapsedDays,
                stability: state.stability
            )
        } else {
            retrievability = parameters.requestedRetention
        }

        if config.enableResponseTimeTuning, let response = responseTime {
            let normalized = min(max(response / 12.0, 0.4), 2.2)
            let exponent = 1.0 / normalized
            retrievability = pow(retrievability, exponent)
            retrievability = min(max(retrievability, 0.01), 0.999)
        }

        let isNewCard = state.fsrsReps == 0 && state.repetitions == 0
        var nextIntervalSeconds: TimeInterval
        var predictedRecall: Double

        switch grade {
        case .again:
            let immediate = config.lapseSteps.first ?? config.learningSteps.first ?? 600
            let adjustedInterval = adjustedIntervalSeconds(
                proposed: immediate,
                now: now,
                deckDueDate: deckDueDate,
                isNewCard: isNewCard,
                grade: grade,
                retrievability: retrievability
            )
            updated.queue = .relearn
            updated.lapses = state.lapses + 1
            updated.fsrsReps = max(0, state.fsrsReps - 1)
            updated.repetitions = max(0, state.repetitions - 1)
            let difficulty = parameters.difficultyAfterLapse(from: state.difficulty)
            let stability = parameters.stabilityAfterLapse(
                difficulty: difficulty,
                previousStability: state.stability,
                retrievability: retrievability
            )
            updated.difficulty = difficulty
            updated.stability = stability
            updated.easeFactor = parameters.legacyEase(from: difficulty)
            updated.interval = Int(round(adjustedInterval / 86_400.0))
            updated.dueDate = now.addingTimeInterval(adjustedInterval)
            nextIntervalSeconds = adjustedInterval
            predictedRecall = parameters.predictedRecall(
                intervalSeconds: adjustedInterval,
                stability: stability
            )
        case .hard, .good, .easy:
            let baseDifficulty: Double
            let baseStability: Double
            if isNewCard {
                baseDifficulty = parameters.initialDifficulty(for: grade)
                baseStability = parameters.initialStability(for: grade)
            } else {
                baseDifficulty = parameters.clampDifficulty(state.difficulty)
                baseStability = max(parameters.minimumStability, state.stability)
            }

            let nextDifficulty = parameters.nextDifficulty(from: baseDifficulty, grade: grade)
            let stabilityElapsedDays = isNewCard ? max(1.0, elapsedDays) : elapsedDays
            let nextStability = parameters.stabilityAfterRecall(
                from: baseStability,
                difficulty: nextDifficulty,
                grade: grade,
                retrievability: retrievability,
                elapsedDays: stabilityElapsedDays
            )

            var intervalSeconds = parameters.intervalSeconds(for: nextStability)
            if isNewCard {
                if grade == .easy {
                    // Easy on a new card = graduate immediately — use FSRS interval as-is
                    // No learning step clamp; FSRS has determined the card is learned
                } else {
                    // Hard/Good on a new card: clamp to the appropriate graduated learning step.
                    // grade.rawValue: hard=2, good=3 → step indices 0 and 1 respectively.
                    let stepIndex = Int(grade.rawValue) - 2  // hard→0, good→1
                    let clampedIndex = max(0, min(stepIndex, config.learningSteps.count - 1))
                    let step = config.learningSteps[clampedIndex]
                    intervalSeconds = min(intervalSeconds, step)
                }
            }
            let adjustedInterval = adjustedIntervalSeconds(
                proposed: intervalSeconds,
                now: now,
                deckDueDate: deckDueDate,
                isNewCard: isNewCard,
                grade: grade,
                retrievability: retrievability
            )

            updated.queue = .review
            updated.fsrsReps = state.fsrsReps + 1
            updated.repetitions = state.repetitions + 1
            updated.difficulty = nextDifficulty
            updated.stability = nextStability
            updated.easeFactor = parameters.legacyEase(from: nextDifficulty)
            updated.interval = Int(round(adjustedInterval / 86_400.0))
            updated.dueDate = now.addingTimeInterval(adjustedInterval)
            nextIntervalSeconds = adjustedInterval
            predictedRecall = parameters.predictedRecall(
                intervalSeconds: adjustedInterval,
                stability: nextStability
            )
        }

        if let deckDueDate, updated.dueDate > deckDueDate {
            updated.dueDate = deckDueDate
            nextIntervalSeconds = max(0, deckDueDate.timeIntervalSince(now))
            updated.interval = max(0, Int(round(nextIntervalSeconds / 86_400.0)))
            predictedRecall = parameters.predictedRecall(
                intervalSeconds: nextIntervalSeconds,
                stability: updated.stability
            )
        }

        return ScheduleResult(
            updatedState: updated,
            nextInterval: nextIntervalSeconds,
            predictedRecall: predictedRecall,
            scheduledDate: updated.dueDate
        )
    }

    @discardableResult
    static func review(
        state: inout SRSState,
        outcome: RecallOutcome,
        settings: UserSettings,
        now: Date = .init(),
        deckDueDate: Date? = nil,
        responseTime: TimeInterval? = nil
    ) -> ScheduleResult {
        let snapshot = SRSStateSnapshot(model: state)
        let result = review(
            state: snapshot,
            outcome: outcome,
            now: now,
            settings: settings,
            deckDueDate: deckDueDate,
            responseTime: responseTime
        )
        result.updatedState.applying(to: &state)
        return result
    }

    static func grade(for outcome: RecallOutcome) -> ReviewGrade {
        switch outcome {
        case .forgot:
            return .again
        case .rememberedEasy:
            // Map to .good (not .easy) for less volatile default scheduling.
            // Users who want .easy should use the 4-grade UI via recordGrade(_:).
            return .good
        }
    }

    private static func adjustedIntervalSeconds(
        proposed: TimeInterval,
        now: Date,
        deckDueDate: Date?,
        isNewCard: Bool,
        grade: ReviewGrade,
        retrievability: Double
    ) -> TimeInterval {
        let minimumInterval: TimeInterval = 5 * 60
        var interval = max(proposed, minimumInterval)
        guard let deckDueDate else { return interval }

        let timeRemaining = deckDueDate.timeIntervalSince(now)
        if timeRemaining <= 0 {
            let clamp = max(0, deckDueDate.timeIntervalSince(now))
            return max(0, min(interval, clamp))
        }

        let buffer: TimeInterval = 3 * 60 * 60
        var latestAllowed = deckDueDate.addingTimeInterval(-buffer)
        if latestAllowed <= now {
            latestAllowed = deckDueDate.addingTimeInterval(-buffer / 2)
        }
        var maxInterval = latestAllowed.timeIntervalSince(now)
        if maxInterval <= minimumInterval {
            maxInterval = max(timeRemaining * 0.5, minimumInterval)
        }
        interval = min(interval, maxInterval)

        if isNewCard {
            let exposures: Double = timeRemaining > 36 * 3600 ? 3.5 : 3.0
            let scaffolding = max(timeRemaining / exposures, minimumInterval)
            interval = min(interval, scaffolding)
        } else if retrievability < 0.6 {
            let reinforcement = max(timeRemaining / 2.5, minimumInterval)
            interval = min(interval, reinforcement)
        }

        if grade == .again {
            let catchUp = max(timeRemaining / 4.0, minimumInterval)
            interval = min(interval, catchUp)
        }

        return max(interval, minimumInterval)
    }
}
