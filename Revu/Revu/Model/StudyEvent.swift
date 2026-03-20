@preconcurrency import Foundation

struct StudyEvent: Identifiable, Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable {
        case sessionStarted
        case cardPresented
        case cardAnswered
        case interventionOffered
        case interventionAction
        case xpAwarded
        case celebrationShown
        case nudgeOffered
        case nudgeAction
        case hintRequested
        case challengeModeAction
        case badgeUnlocked
        case bossCardAttempted
    }
    
    var id: UUID
    var timestamp: Date
    var sessionId: UUID
    var kind: Kind
    
    // Optional context
    var deckId: UUID?
    var cardId: UUID?
    var queueMode: String?
    var attemptIndex: Int?
    var conceptsAtTime: [String]?
    
    // Optional signals
    var elapsedMs: Int?
    var grade: Int?
    var predictedRecallAtStart: Double?

    // Intervention diagnostics (optional)
    var confusionScore: Double?
    var confusionReasons: [String]?
    var interventionKind: String?
    var interventionAction: String?
    
    // Adaptive difficulty diagnostics (optional, for tuning)
    var adaptiveSuccessRate: Double?
    var adaptiveTargetPSuccess: Double?
    var adaptiveChosenPSuccess: Double?

    // Session engagement telemetry (optional, Kind-specific)
    var xpAmount: Int?
    var xpReason: String?
    var streakAtAward: Int?
    var celebrationType: String?
    var threshold: Int?
    var intensity: String?
    var nudgeType: String?
    var nudgeScore: Double?
    var source: String?
    var cooldownRemainingSec: Int?
    var nudgeActionValue: String?
    var hintLevel: Int?
    var entryPoint: String?
    var challengeModeActionValue: String?
    var predictedRecallBucket: String?
    var badgeId: String?
    var badgeTier: String?
    var progressBefore: Double?
    var progressAfter: Double?
    var conceptCount: Int?
    var wasSuccessful: Bool?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: UUID,
        kind: Kind,
        deckId: UUID? = nil,
        cardId: UUID? = nil,
        queueMode: String? = nil,
        attemptIndex: Int? = nil,
        conceptsAtTime: [String]? = nil,
        elapsedMs: Int? = nil,
        grade: Int? = nil,
        predictedRecallAtStart: Double? = nil,
        confusionScore: Double? = nil,
        confusionReasons: [String]? = nil,
        interventionKind: String? = nil,
        interventionAction: String? = nil,
        adaptiveSuccessRate: Double? = nil,
        adaptiveTargetPSuccess: Double? = nil,
        adaptiveChosenPSuccess: Double? = nil,
        xpAmount: Int? = nil,
        xpReason: String? = nil,
        streakAtAward: Int? = nil,
        celebrationType: String? = nil,
        threshold: Int? = nil,
        intensity: String? = nil,
        nudgeType: String? = nil,
        nudgeScore: Double? = nil,
        source: String? = nil,
        cooldownRemainingSec: Int? = nil,
        nudgeActionValue: String? = nil,
        hintLevel: Int? = nil,
        entryPoint: String? = nil,
        challengeModeActionValue: String? = nil,
        predictedRecallBucket: String? = nil,
        badgeId: String? = nil,
        badgeTier: String? = nil,
        progressBefore: Double? = nil,
        progressAfter: Double? = nil,
        conceptCount: Int? = nil,
        wasSuccessful: Bool? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.kind = kind
        self.deckId = deckId
        self.cardId = cardId
        self.queueMode = queueMode
        self.attemptIndex = attemptIndex
        self.conceptsAtTime = conceptsAtTime
        self.elapsedMs = elapsedMs
        self.grade = grade
        self.predictedRecallAtStart = predictedRecallAtStart
        self.confusionScore = confusionScore
        self.confusionReasons = confusionReasons
        self.interventionKind = interventionKind
        self.interventionAction = interventionAction
        self.adaptiveSuccessRate = adaptiveSuccessRate
        self.adaptiveTargetPSuccess = adaptiveTargetPSuccess
        self.adaptiveChosenPSuccess = adaptiveChosenPSuccess
        self.xpAmount = xpAmount
        self.xpReason = xpReason
        self.streakAtAward = streakAtAward
        self.celebrationType = celebrationType
        self.threshold = threshold
        self.intensity = intensity
        self.nudgeType = nudgeType
        self.nudgeScore = nudgeScore
        self.source = source
        self.cooldownRemainingSec = cooldownRemainingSec
        self.nudgeActionValue = nudgeActionValue
        self.hintLevel = hintLevel
        self.entryPoint = entryPoint
        self.challengeModeActionValue = challengeModeActionValue
        self.predictedRecallBucket = predictedRecallBucket
        self.badgeId = badgeId
        self.badgeTier = badgeTier
        self.progressBefore = progressBefore
        self.progressAfter = progressAfter
        self.conceptCount = conceptCount
        self.wasSuccessful = wasSuccessful
    }
}
