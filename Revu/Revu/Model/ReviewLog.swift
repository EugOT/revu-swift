@preconcurrency import Foundation

struct ReviewLog: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var cardId: UUID
    var timestamp: Date
    var grade: Int
    var elapsedMs: Int
    var prevInterval: Int
    var nextInterval: Int
    var prevEase: Double
    var nextEase: Double
    var prevStability: Double
    var nextStability: Double
    var prevDifficulty: Double
    var nextDifficulty: Double
    var predictedRecall: Double
    var requestedRetention: Double

    init(
        id: UUID = UUID(),
        cardId: UUID,
        timestamp: Date = Date(),
        grade: Int,
        elapsedMs: Int,
        prevInterval: Int,
        nextInterval: Int,
        prevEase: Double,
        nextEase: Double,
        prevStability: Double,
        nextStability: Double,
        prevDifficulty: Double,
        nextDifficulty: Double,
        predictedRecall: Double,
        requestedRetention: Double
    ) {
        self.id = id
        self.cardId = cardId
        self.timestamp = timestamp
        self.grade = grade
        self.elapsedMs = elapsedMs
        self.prevInterval = prevInterval
        self.nextInterval = nextInterval
        self.prevEase = prevEase
        self.nextEase = nextEase
        self.prevStability = prevStability
        self.nextStability = nextStability
        self.prevDifficulty = prevDifficulty
        self.nextDifficulty = nextDifficulty
        self.predictedRecall = predictedRecall
        self.requestedRetention = requestedRetention
    }
}
