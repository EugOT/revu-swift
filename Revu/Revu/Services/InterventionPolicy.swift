import Foundation

struct PendingIntervention: Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        case nudge
        case hint
        case socratic
        case explain

        var buttonTitle: String {
            switch self {
            case .nudge: return "Need help?"
            case .hint: return "Hint"
            case .socratic: return "Coach me"
            case .explain: return "Explain"
            }
        }
    }

    struct Context: Equatable, Sendable {
        var deckId: UUID?
        var deckName: String?
        var cardId: UUID
        var cardFront: String
        var cardBack: String
        var conceptKeys: [String]
        var elapsedMs: Int?
        var predictedRecallAtStart: Double?
        var grade: Int?
    }

    var id: UUID
    var kind: Kind
    var score: Double
    var reasons: [ConfusionDetector.Reason]
    var createdAt: Date
    var context: Context

    init(
        id: UUID = UUID(),
        kind: Kind,
        score: Double,
        reasons: [ConfusionDetector.Reason],
        createdAt: Date = Date(),
        context: Context
    ) {
        self.id = id
        self.kind = kind
        self.score = score
        self.reasons = reasons
        self.createdAt = createdAt
        self.context = context
    }
}

/// Pure policy: decides whether to offer an intervention and which ladder rung to use.
struct InterventionPolicy: Sendable {
    struct Input: Sendable {
        var now: Date
        var settings: UserSettings
        var confusion: ConfusionDetector.Result
        var consecutiveFailures: Int
        var lastOfferedAt: Date?
        var suppressedThisSession: Bool
        var outcome: RecallOutcome

        init(
            now: Date = Date(),
            settings: UserSettings,
            confusion: ConfusionDetector.Result,
            consecutiveFailures: Int,
            lastOfferedAt: Date?,
            suppressedThisSession: Bool,
            outcome: RecallOutcome
        ) {
            self.now = now
            self.settings = settings
            self.confusion = confusion
            self.consecutiveFailures = max(0, consecutiveFailures)
            self.lastOfferedAt = lastOfferedAt
            self.suppressedThisSession = suppressedThisSession
            self.outcome = outcome
        }
    }

    func decide(input: Input) -> PendingIntervention.Kind? {
        guard input.settings.proactiveInterventionsEnabled else { return nil }
        guard !input.suppressedThisSession else { return nil }

        let cooldownSeconds = TimeInterval(max(0, input.settings.interventionCooldownMinutes) * 60)
        if let last = input.lastOfferedAt, input.now.timeIntervalSince(last) < cooldownSeconds {
            return nil
        }

        let threshold = threshold(for: input.settings.interventionSensitivity)
        guard input.confusion.score >= threshold else { return nil }

        let isWrong = (input.outcome == .forgot)

        // Ladder selection: nudge → hint → socratic → explain
        if input.consecutiveFailures >= 3 || input.confusion.score >= 0.92 {
            return .explain
        }

        if input.consecutiveFailures >= 2 || (isWrong && input.confusion.score >= threshold + 0.20) {
            return .socratic
        }

        if isWrong && input.confusion.score >= threshold + 0.08 {
            return .hint
        }

        return .nudge
    }

    private func threshold(for sensitivity: InterventionSensitivity) -> Double {
        switch sensitivity {
        case .low:
            return 0.75
        case .medium:
            return 0.60
        case .high:
            return 0.45
        }
    }
}

