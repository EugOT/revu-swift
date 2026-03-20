@preconcurrency import Foundation

struct SRSState: Identifiable, Codable, Equatable, Hashable, Sendable {
    enum Queue: String, Codable, CaseIterable, Identifiable {
        case new
        case learning
        case review
        case relearn

        var id: String { rawValue }
    }

    var id: UUID
    var cardId: UUID
    var easeFactor: Double
    var interval: Int
    var repetitions: Int
    var lapses: Int
    var dueDate: Date
    var lastReviewed: Date?
    var queue: Queue
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
        dueDate: Date = Date(),
        lastReviewed: Date? = nil,
        queue: Queue = .new,
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
}

extension SRSState {
    func predictedRecall(on date: Date = Date(), retentionTarget: Double) -> Double {
        let referenceDate = lastReviewed ?? date
        let elapsedDays = max(0.0, date.timeIntervalSince(referenceDate) / 86_400.0)
        let parameters = FSRSParameters(requestedRetention: retentionTarget)
        return parameters.retrievability(
            elapsedDays: elapsedDays,
            stability: stability
        )
    }

    func predictedRecallAtScheduled(retentionTarget: Double) -> Double {
        predictedRecall(on: dueDate, retentionTarget: retentionTarget)
    }
}
