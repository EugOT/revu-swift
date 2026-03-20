@preconcurrency import Foundation

// MARK: - DTO Models

struct DeckDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var parentId: UUID?
    var courseId: UUID?
    var originLessonId: UUID?
    var kind: Deck.Kind
    var name: String
    var note: String?
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case parentId
        case courseId
        case originLessonId
        case kind
        case name
        case note
        case dueDate
        case createdAt
        case updatedAt
        case isArchived
    }

    init(
        id: UUID,
        parentId: UUID? = nil,
        courseId: UUID? = nil,
        originLessonId: UUID? = nil,
        kind: Deck.Kind = .deck,
        name: String,
        note: String?,
        dueDate: Date?,
        createdAt: Date,
        updatedAt: Date,
        isArchived: Bool = false
    ) {
        self.id = id
        self.parentId = parentId
        self.courseId = courseId
        self.originLessonId = originLessonId
        self.kind = kind
        self.name = name
        self.note = note
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        courseId = try container.decodeIfPresent(UUID.self, forKey: .courseId)
        originLessonId = try container.decodeIfPresent(UUID.self, forKey: .originLessonId)
        kind = try container.decodeIfPresent(Deck.Kind.self, forKey: .kind) ?? .deck
        name = try container.decode(String.self, forKey: .name)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encodeIfPresent(courseId, forKey: .courseId)
        try container.encodeIfPresent(originLessonId, forKey: .originLessonId)
        try container.encode(kind, forKey: .kind)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        if isArchived {
            try container.encode(isArchived, forKey: .isArchived)
        }
    }
}

struct CardDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable {
        case basic
        case cloze
        case multipleChoice
    }

    var id: UUID
    var deckId: UUID?
    var kind: Kind
    var front: String
    var back: String
    var clozeSource: String?
    var choices: [String]
    var correctChoiceIndex: Int?
    var tags: [String]
    var sourceRef: String?
    var media: [URL]
    var createdAt: Date
    var updatedAt: Date
    var isSuspended: Bool
    var suspendedByArchive: Bool
    var srs: SRSStateDTO

    enum CodingKeys: String, CodingKey {
        case id
        case deckId
        case kind
        case front
        case back
        case clozeSource
        case choices
        case correctChoiceIndex
        case tags
        case sourceRef
        case media
        case createdAt
        case updatedAt
        case isSuspended
        case suspendedByArchive
        case srs
    }

    init(
        id: UUID,
        deckId: UUID?,
        kind: Kind,
        front: String,
        back: String,
        clozeSource: String?,
        choices: [String] = [],
        correctChoiceIndex: Int?,
        tags: [String],
        sourceRef: String? = nil,
        media: [URL],
        createdAt: Date,
        updatedAt: Date,
        isSuspended: Bool,
        suspendedByArchive: Bool = false,
        srs: SRSStateDTO
    ) {
        self.id = id
        self.deckId = deckId
        self.kind = kind
        self.front = front
        self.back = back
        self.clozeSource = clozeSource
        self.choices = choices
        self.correctChoiceIndex = correctChoiceIndex
        self.tags = tags
        self.sourceRef = sourceRef
        self.media = media
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSuspended = isSuspended
        self.suspendedByArchive = suspendedByArchive
        self.srs = srs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        deckId = try container.decodeIfPresent(UUID.self, forKey: .deckId)
        kind = try container.decode(Kind.self, forKey: .kind)
        front = try container.decode(String.self, forKey: .front)
        back = try container.decode(String.self, forKey: .back)
        clozeSource = try container.decodeIfPresent(String.self, forKey: .clozeSource)
        choices = try container.decodeIfPresent([String].self, forKey: .choices) ?? []
        correctChoiceIndex = try container.decodeIfPresent(Int.self, forKey: .correctChoiceIndex)
        tags = try container.decode([String].self, forKey: .tags)
        sourceRef = try container.decodeIfPresent(String.self, forKey: .sourceRef)
        media = try container.decode([URL].self, forKey: .media)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isSuspended = try container.decode(Bool.self, forKey: .isSuspended)
        suspendedByArchive = try container.decodeIfPresent(Bool.self, forKey: .suspendedByArchive) ?? false
        srs = try container.decode(SRSStateDTO.self, forKey: .srs)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(deckId, forKey: .deckId)
        try container.encode(kind, forKey: .kind)
        try container.encode(front, forKey: .front)
        try container.encode(back, forKey: .back)
        try container.encodeIfPresent(clozeSource, forKey: .clozeSource)
        if !choices.isEmpty {
            try container.encode(choices, forKey: .choices)
        }
        try container.encodeIfPresent(correctChoiceIndex, forKey: .correctChoiceIndex)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(sourceRef, forKey: .sourceRef)
        try container.encode(media, forKey: .media)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isSuspended, forKey: .isSuspended)
        if suspendedByArchive {
            try container.encode(suspendedByArchive, forKey: .suspendedByArchive)
        }
        try container.encode(srs, forKey: .srs)
    }
}

struct SRSStateDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    enum Queue: String, Codable {
        case new
        case learning
        case review
        case relearn
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

    enum CodingKeys: String, CodingKey {
        case id
        case cardId
        case easeFactor
        case interval
        case repetitions
        case lapses
        case dueDate
        case lastReviewed
        case queue
        case stability
        case difficulty
        case fsrsReps
        case lastElapsedSeconds
    }

    init(
        id: UUID,
        cardId: UUID,
        easeFactor: Double,
        interval: Int,
        repetitions: Int,
        lapses: Int,
        dueDate: Date,
        lastReviewed: Date?,
        queue: Queue,
        stability: Double,
        difficulty: Double,
        fsrsReps: Int,
        lastElapsedSeconds: Double?
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        cardId = try container.decode(UUID.self, forKey: .cardId)
        easeFactor = try container.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 0
        repetitions = try container.decodeIfPresent(Int.self, forKey: .repetitions) ?? 0
        lapses = try container.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) ?? Date()
        lastReviewed = try container.decodeIfPresent(Date.self, forKey: .lastReviewed)
        queue = try container.decodeIfPresent(Queue.self, forKey: .queue) ?? .new
        stability = try container.decodeIfPresent(Double.self, forKey: .stability) ?? 0.6
        difficulty = try container.decodeIfPresent(Double.self, forKey: .difficulty) ?? 5.0
        fsrsReps = try container.decodeIfPresent(Int.self, forKey: .fsrsReps) ?? repetitions
        lastElapsedSeconds = try container.decodeIfPresent(Double.self, forKey: .lastElapsedSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cardId, forKey: .cardId)
        try container.encode(easeFactor, forKey: .easeFactor)
        try container.encode(interval, forKey: .interval)
        try container.encode(repetitions, forKey: .repetitions)
        try container.encode(lapses, forKey: .lapses)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(lastReviewed, forKey: .lastReviewed)
        try container.encode(queue, forKey: .queue)
        try container.encode(stability, forKey: .stability)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(fsrsReps, forKey: .fsrsReps)
        try container.encodeIfPresent(lastElapsedSeconds, forKey: .lastElapsedSeconds)
    }
}

@preconcurrency struct ReviewLogDTO: Identifiable, Equatable, Hashable, Sendable {
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
    enum CodingKeys: String, CodingKey {
        case id
        case cardId
        case timestamp
        case grade
        case elapsedMs
        case prevInterval
        case nextInterval
        case prevEase
        case nextEase
        case prevStability
        case nextStability
        case prevDifficulty
        case nextDifficulty
        case predictedRecall
        case requestedRetention
    }

    init(
        id: UUID,
        cardId: UUID,
        timestamp: Date,
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

extension ReviewLogDTO: Codable {
    nonisolated(unsafe) init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardId = try container.decode(UUID.self, forKey: .cardId)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        grade = try container.decodeIfPresent(Int.self, forKey: .grade) ?? 0
        elapsedMs = try container.decodeIfPresent(Int.self, forKey: .elapsedMs) ?? 0
        prevInterval = try container.decodeIfPresent(Int.self, forKey: .prevInterval) ?? 0
        nextInterval = try container.decodeIfPresent(Int.self, forKey: .nextInterval) ?? 0
        prevEase = try container.decodeIfPresent(Double.self, forKey: .prevEase) ?? 2.5
        nextEase = try container.decodeIfPresent(Double.self, forKey: .nextEase) ?? prevEase
        prevStability = try container.decodeIfPresent(Double.self, forKey: .prevStability) ?? 0.6
        nextStability = try container.decodeIfPresent(Double.self, forKey: .nextStability) ?? prevStability
        prevDifficulty = try container.decodeIfPresent(Double.self, forKey: .prevDifficulty) ?? 5.0
        nextDifficulty = try container.decodeIfPresent(Double.self, forKey: .nextDifficulty) ?? prevDifficulty
        predictedRecall = try container.decodeIfPresent(Double.self, forKey: .predictedRecall) ?? 0.0
        requestedRetention = try container.decodeIfPresent(Double.self, forKey: .requestedRetention) ?? AppSettingsDefaults.retentionTarget
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cardId, forKey: .cardId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(grade, forKey: .grade)
        try container.encode(elapsedMs, forKey: .elapsedMs)
        try container.encode(prevInterval, forKey: .prevInterval)
        try container.encode(nextInterval, forKey: .nextInterval)
        try container.encode(prevEase, forKey: .prevEase)
        try container.encode(nextEase, forKey: .nextEase)
        try container.encode(prevStability, forKey: .prevStability)
        try container.encode(nextStability, forKey: .nextStability)
        try container.encode(prevDifficulty, forKey: .prevDifficulty)
        try container.encode(nextDifficulty, forKey: .nextDifficulty)
        try container.encode(predictedRecall, forKey: .predictedRecall)
        try container.encode(requestedRetention, forKey: .requestedRetention)
    }
}

@preconcurrency struct UserSettingsDTO: Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var dailyNewLimit: Int
    var dailyReviewLimit: Int
    var learningStepsMinutes: [Double]
    var lapseStepsMinutes: [Double]
    var easeMin: Double
    var burySiblings: Bool
    var keyboardHints: Bool
    var autoAdvance: Bool
    var retentionTarget: Double
    var enableResponseTimeTuning: Bool
    var proactiveInterventionsEnabled: Bool
    var interventionSensitivity: String?
    var interventionCooldownMinutes: Int
    var challengeModeDefaultEnabled: Bool?
    var celebrationIntensity: String?
    var dailyGoalTarget: Int?
    var useCloudSync: Bool
    var notificationsEnabled: Bool
    var notificationHour: Int
    var notificationMinute: Int
    var dataLocationBookmark: Data?
    var appearanceMode: String?
    var deckSortOrder: [UUID]?
    var deckSortMode: String?
    var hasCompletedOnboarding: Bool?
    var userName: String?
    var studyGoal: String?

    enum CodingKeys: String, CodingKey {
        case id
        case dailyNewLimit
        case dailyReviewLimit
        case learningStepsMinutes
        case lapseStepsMinutes
        case easeMin
        case burySiblings
        case keyboardHints
        case autoAdvance
        case retentionTarget
        case enableResponseTimeTuning
        case proactiveInterventionsEnabled
        case interventionSensitivity
        case interventionCooldownMinutes
        case challengeModeDefaultEnabled
        case celebrationIntensity
        case dailyGoalTarget
        case useCloudSync
        case notificationsEnabled
        case notificationHour
        case notificationMinute
        case dataLocationBookmark
        case appearanceMode
        case deckSortOrder
        case deckSortMode
        case hasCompletedOnboarding
        case userName
        case studyGoal
    }

    init(
        id: UUID,
        dailyNewLimit: Int,
        dailyReviewLimit: Int,
        learningStepsMinutes: [Double],
        lapseStepsMinutes: [Double],
        easeMin: Double,
        burySiblings: Bool,
        keyboardHints: Bool,
        autoAdvance: Bool,
        retentionTarget: Double,
        enableResponseTimeTuning: Bool,
        proactiveInterventionsEnabled: Bool,
        interventionSensitivity: String?,
        interventionCooldownMinutes: Int,
        challengeModeDefaultEnabled: Bool? = nil,
        celebrationIntensity: String? = nil,
        dailyGoalTarget: Int? = nil,
        useCloudSync: Bool,
        notificationsEnabled: Bool,
        notificationHour: Int,
        notificationMinute: Int,
        dataLocationBookmark: Data?,
        appearanceMode: String?,
        deckSortOrder: [UUID]?,
        deckSortMode: String?,
        hasCompletedOnboarding: Bool?,
        userName: String?,
        studyGoal: String?
    ) {
        self.id = id
        self.dailyNewLimit = dailyNewLimit
        self.dailyReviewLimit = dailyReviewLimit
        self.learningStepsMinutes = learningStepsMinutes
        self.lapseStepsMinutes = lapseStepsMinutes
        self.easeMin = easeMin
        self.burySiblings = burySiblings
        self.keyboardHints = keyboardHints
        self.autoAdvance = autoAdvance
        self.retentionTarget = retentionTarget
        self.enableResponseTimeTuning = enableResponseTimeTuning
        self.proactiveInterventionsEnabled = proactiveInterventionsEnabled
        self.interventionSensitivity = interventionSensitivity
        self.interventionCooldownMinutes = interventionCooldownMinutes
        self.challengeModeDefaultEnabled = challengeModeDefaultEnabled
        self.celebrationIntensity = celebrationIntensity
        self.dailyGoalTarget = dailyGoalTarget
        self.useCloudSync = useCloudSync
        self.notificationsEnabled = notificationsEnabled
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.dataLocationBookmark = dataLocationBookmark
        self.appearanceMode = appearanceMode
        self.deckSortOrder = deckSortOrder
        self.deckSortMode = deckSortMode
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.userName = userName
        self.studyGoal = studyGoal
    }

}

extension UserSettingsDTO: Codable {
    nonisolated(unsafe) init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        dailyNewLimit = try container.decodeIfPresent(Int.self, forKey: .dailyNewLimit) ?? AppSettingsDefaults.dailyNewLimit
        dailyReviewLimit = try container.decodeIfPresent(Int.self, forKey: .dailyReviewLimit) ?? AppSettingsDefaults.dailyReviewLimit
        learningStepsMinutes = try container.decodeIfPresent([Double].self, forKey: .learningStepsMinutes) ?? AppSettingsDefaults.learningStepsMinutes
        lapseStepsMinutes = try container.decodeIfPresent([Double].self, forKey: .lapseStepsMinutes) ?? AppSettingsDefaults.lapseStepsMinutes
        easeMin = try container.decodeIfPresent(Double.self, forKey: .easeMin) ?? AppSettingsDefaults.easeMin
        burySiblings = try container.decodeIfPresent(Bool.self, forKey: .burySiblings) ?? AppSettingsDefaults.burySiblings
        keyboardHints = try container.decodeIfPresent(Bool.self, forKey: .keyboardHints) ?? AppSettingsDefaults.keyboardHints
        autoAdvance = try container.decodeIfPresent(Bool.self, forKey: .autoAdvance) ?? AppSettingsDefaults.autoAdvance
        retentionTarget = try container.decodeIfPresent(Double.self, forKey: .retentionTarget) ?? AppSettingsDefaults.retentionTarget
        enableResponseTimeTuning = try container.decodeIfPresent(Bool.self, forKey: .enableResponseTimeTuning) ?? AppSettingsDefaults.enableResponseTimeTuning
        proactiveInterventionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .proactiveInterventionsEnabled) ?? AppSettingsDefaults.proactiveInterventionsEnabled
        interventionSensitivity = try container.decodeIfPresent(String.self, forKey: .interventionSensitivity) ?? AppSettingsDefaults.interventionSensitivity.rawValue
        interventionCooldownMinutes = try container.decodeIfPresent(Int.self, forKey: .interventionCooldownMinutes) ?? AppSettingsDefaults.interventionCooldownMinutes
        challengeModeDefaultEnabled = try container.decodeIfPresent(Bool.self, forKey: .challengeModeDefaultEnabled) ?? AppSettingsDefaults.challengeModeDefaultEnabled
        celebrationIntensity = try container.decodeIfPresent(String.self, forKey: .celebrationIntensity) ?? AppSettingsDefaults.celebrationIntensity.rawValue
        dailyGoalTarget = try container.decodeIfPresent(Int.self, forKey: .dailyGoalTarget) ?? AppSettingsDefaults.dailyGoalTarget
        useCloudSync = try container.decodeIfPresent(Bool.self, forKey: .useCloudSync) ?? AppSettingsDefaults.useCloudSync
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? AppSettingsDefaults.notificationsEnabled
        notificationHour = try container.decodeIfPresent(Int.self, forKey: .notificationHour) ?? AppSettingsDefaults.notificationHour
        notificationMinute = try container.decodeIfPresent(Int.self, forKey: .notificationMinute) ?? AppSettingsDefaults.notificationMinute
        dataLocationBookmark = try container.decodeIfPresent(Data.self, forKey: .dataLocationBookmark)
        appearanceMode = try container.decodeIfPresent(String.self, forKey: .appearanceMode)
        deckSortOrder = try container.decodeIfPresent([UUID].self, forKey: .deckSortOrder)
        deckSortMode = try container.decodeIfPresent(String.self, forKey: .deckSortMode)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? true
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? AppSettingsDefaults.userName
        studyGoal = try container.decodeIfPresent(String.self, forKey: .studyGoal) ?? AppSettingsDefaults.studyGoal
    }

    nonisolated(unsafe) func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dailyNewLimit, forKey: .dailyNewLimit)
        try container.encode(dailyReviewLimit, forKey: .dailyReviewLimit)
        try container.encode(learningStepsMinutes, forKey: .learningStepsMinutes)
        try container.encode(lapseStepsMinutes, forKey: .lapseStepsMinutes)
        try container.encode(easeMin, forKey: .easeMin)
        try container.encode(burySiblings, forKey: .burySiblings)
        try container.encode(keyboardHints, forKey: .keyboardHints)
        try container.encode(autoAdvance, forKey: .autoAdvance)
        try container.encode(retentionTarget, forKey: .retentionTarget)
        try container.encode(enableResponseTimeTuning, forKey: .enableResponseTimeTuning)
        try container.encode(proactiveInterventionsEnabled, forKey: .proactiveInterventionsEnabled)
        try container.encodeIfPresent(interventionSensitivity, forKey: .interventionSensitivity)
        try container.encode(interventionCooldownMinutes, forKey: .interventionCooldownMinutes)
        try container.encodeIfPresent(challengeModeDefaultEnabled, forKey: .challengeModeDefaultEnabled)
        try container.encodeIfPresent(celebrationIntensity, forKey: .celebrationIntensity)
        try container.encodeIfPresent(dailyGoalTarget, forKey: .dailyGoalTarget)
        try container.encode(useCloudSync, forKey: .useCloudSync)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(notificationHour, forKey: .notificationHour)
        try container.encode(notificationMinute, forKey: .notificationMinute)
        try container.encodeIfPresent(dataLocationBookmark, forKey: .dataLocationBookmark)
        try container.encodeIfPresent(appearanceMode, forKey: .appearanceMode)
        try container.encodeIfPresent(deckSortOrder, forKey: .deckSortOrder)
        try container.encodeIfPresent(deckSortMode, forKey: .deckSortMode)
        try container.encodeIfPresent(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encodeIfPresent(userName, forKey: .userName)
        try container.encodeIfPresent(studyGoal, forKey: .studyGoal)
    }
}

@preconcurrency struct MetadataDTO: Equatable, Hashable, Sendable {
    var schema: String
    var version: Int
    var createdAt: Date
    var lastCompaction: Date
    var instanceId: UUID

    enum CodingKeys: String, CodingKey {
        case schema
        case version
        case createdAt
        case lastCompaction
        case instanceId
    }
}

extension MetadataDTO: Codable {
    nonisolated(unsafe) init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decode(String.self, forKey: .schema)
        version = try container.decode(Int.self, forKey: .version)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastCompaction = try container.decode(Date.self, forKey: .lastCompaction)
        instanceId = try container.decode(UUID.self, forKey: .instanceId)
    }

    nonisolated(unsafe) func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(version, forKey: .version)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastCompaction, forKey: .lastCompaction)
        try container.encode(instanceId, forKey: .instanceId)
    }
}

// MARK: - ExamDTO

struct ExamDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    struct ConfigDTO: Codable, Equatable, Hashable, Sendable {
        var timeLimit: Int?
        var shuffleQuestions: Bool

        enum CodingKeys: String, CodingKey {
            case timeLimit
            case shuffleQuestions
        }

        init(timeLimit: Int? = nil, shuffleQuestions: Bool = true) {
            self.timeLimit = timeLimit
            self.shuffleQuestions = shuffleQuestions
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            timeLimit = try container.decodeIfPresent(Int.self, forKey: .timeLimit)
            shuffleQuestions = try container.decodeIfPresent(Bool.self, forKey: .shuffleQuestions) ?? true
        }
    }

    struct QuestionDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
        var id: UUID
        var prompt: String
        var choices: [String]
        var correctChoiceIndex: Int

        enum CodingKeys: String, CodingKey {
            case id
            case prompt
            case choices
            case correctChoiceIndex
        }

        init(id: UUID = UUID(), prompt: String, choices: [String] = [], correctChoiceIndex: Int = 0) {
            self.id = id
            self.prompt = prompt
            self.choices = choices
            self.correctChoiceIndex = correctChoiceIndex
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            prompt = try container.decode(String.self, forKey: .prompt)
            choices = try container.decodeIfPresent([String].self, forKey: .choices) ?? []
            correctChoiceIndex = try container.decodeIfPresent(Int.self, forKey: .correctChoiceIndex) ?? 0
        }
    }

    var id: UUID
    var parentFolderId: UUID?
    var courseId: UUID?
    var originLessonId: UUID?
    var title: String
    var config: ConfigDTO
    var questions: [QuestionDTO]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case parentFolderId
        case courseId
        case originLessonId
        case title
        case config
        case questions
        case createdAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        parentFolderId: UUID? = nil,
        courseId: UUID? = nil,
        originLessonId: UUID? = nil,
        title: String,
        config: ConfigDTO = ConfigDTO(),
        questions: [QuestionDTO] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.parentFolderId = parentFolderId
        self.courseId = courseId
        self.originLessonId = originLessonId
        self.title = title
        self.config = config
        self.questions = questions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentFolderId = try container.decodeIfPresent(UUID.self, forKey: .parentFolderId)
        courseId = try container.decodeIfPresent(UUID.self, forKey: .courseId)
        originLessonId = try container.decodeIfPresent(UUID.self, forKey: .originLessonId)
        title = try container.decode(String.self, forKey: .title)
        config = try container.decodeIfPresent(ConfigDTO.self, forKey: .config) ?? ConfigDTO()
        questions = try container.decodeIfPresent([QuestionDTO].self, forKey: .questions) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(parentFolderId, forKey: .parentFolderId)
        try container.encodeIfPresent(courseId, forKey: .courseId)
        try container.encodeIfPresent(originLessonId, forKey: .originLessonId)
        try container.encode(title, forKey: .title)
        try container.encode(config, forKey: .config)
        if !questions.isEmpty {
            try container.encode(questions, forKey: .questions)
        }
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    func toDomain() -> Exam {
        Exam(
            id: id,
            parentFolderId: parentFolderId,
            courseId: courseId,
            originLessonId: originLessonId,
            title: title,
            config: Exam.Config(
                timeLimit: config.timeLimit,
                shuffleQuestions: config.shuffleQuestions
            ),
            questions: questions.map { q in
                Exam.Question(
                    id: q.id,
                    prompt: q.prompt,
                    choices: q.choices,
                    correctChoiceIndex: q.correctChoiceIndex
                )
            },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension Exam {
    func toDTO() -> ExamDTO {
        ExamDTO(
            id: id,
            parentFolderId: parentFolderId,
            courseId: courseId,
            originLessonId: originLessonId,
            title: title,
            config: ExamDTO.ConfigDTO(
                timeLimit: config.timeLimit,
                shuffleQuestions: config.shuffleQuestions
            ),
            questions: questions.map { q in
                ExamDTO.QuestionDTO(
                    id: q.id,
                    prompt: q.prompt,
                    choices: q.choices,
                    correctChoiceIndex: q.correctChoiceIndex
                )
            },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - StudyGuideDTO

struct StudyGuideAttachmentDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var filename: String
    var relativePath: String
    var mimeType: String
    var sizeBytes: Int64
    var createdAt: Date

    init(
        id: UUID = UUID(),
        filename: String,
        relativePath: String,
        mimeType: String,
        sizeBytes: Int64,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.filename = filename
        self.relativePath = relativePath
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
    }

    func toDomain() -> StudyGuideAttachment {
        StudyGuideAttachment(
            id: id,
            filename: filename,
            relativePath: relativePath,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            createdAt: createdAt
        )
    }
}

extension StudyGuideAttachment {
    func toDTO() -> StudyGuideAttachmentDTO {
        StudyGuideAttachmentDTO(
            id: id,
            filename: filename,
            relativePath: relativePath,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            createdAt: createdAt
        )
    }
}

struct StudyGuideDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var parentFolderId: UUID?
    var courseId: UUID?
    var originLessonId: UUID?
    var title: String
    var markdownContent: String
    var attachments: [StudyGuideAttachmentDTO]
    var tags: [String]
    var createdAt: Date
    var lastEditedAt: Date
    var updatedAt: Date {
        get { lastEditedAt }
        set { lastEditedAt = newValue }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case parentFolderId
        case courseId
        case originLessonId
        case title
        case markdownContent
        case attachments
        case tags
        case createdAt
        case lastEditedAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        parentFolderId: UUID? = nil,
        courseId: UUID? = nil,
        originLessonId: UUID? = nil,
        title: String,
        markdownContent: String = "",
        attachments: [StudyGuideAttachmentDTO] = [],
        tags: [String] = [],
        createdAt: Date = Date(),
        lastEditedAt: Date
    ) {
        self.id = id
        self.parentFolderId = parentFolderId
        self.courseId = courseId
        self.originLessonId = originLessonId
        self.title = title
        self.markdownContent = markdownContent
        self.attachments = attachments
        self.tags = tags
        self.createdAt = createdAt
        self.lastEditedAt = lastEditedAt
    }

    init(
        id: UUID = UUID(),
        parentFolderId: UUID? = nil,
        courseId: UUID? = nil,
        originLessonId: UUID? = nil,
        title: String,
        markdownContent: String = "",
        attachments: [StudyGuideAttachmentDTO] = [],
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(
            id: id,
            parentFolderId: parentFolderId,
            courseId: courseId,
            originLessonId: originLessonId,
            title: title,
            markdownContent: markdownContent,
            attachments: attachments,
            tags: tags,
            createdAt: createdAt,
            lastEditedAt: updatedAt
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentFolderId = try container.decodeIfPresent(UUID.self, forKey: .parentFolderId)
        courseId = try container.decodeIfPresent(UUID.self, forKey: .courseId)
        originLessonId = try container.decodeIfPresent(UUID.self, forKey: .originLessonId)
        title = try container.decode(String.self, forKey: .title)
        markdownContent = try container.decodeIfPresent(String.self, forKey: .markdownContent) ?? ""
        attachments = try container.decodeIfPresent([StudyGuideAttachmentDTO].self, forKey: .attachments) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        let decodedLastEditedAt = try container.decodeIfPresent(Date.self, forKey: .lastEditedAt)
        let decodedUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        lastEditedAt = decodedLastEditedAt ?? decodedUpdatedAt ?? createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(parentFolderId, forKey: .parentFolderId)
        try container.encodeIfPresent(courseId, forKey: .courseId)
        try container.encodeIfPresent(originLessonId, forKey: .originLessonId)
        try container.encode(title, forKey: .title)
        if !markdownContent.isEmpty {
            try container.encode(markdownContent, forKey: .markdownContent)
        }
        if !attachments.isEmpty {
            try container.encode(attachments, forKey: .attachments)
        }
        if !tags.isEmpty {
            try container.encode(tags, forKey: .tags)
        }
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastEditedAt, forKey: .lastEditedAt)
        try container.encode(lastEditedAt, forKey: .updatedAt)
    }

    func toDomain() -> StudyGuide {
        StudyGuide(
            id: id,
            parentFolderId: parentFolderId,
            courseId: courseId,
            originLessonId: originLessonId,
            title: title,
            markdownContent: markdownContent,
            attachments: attachments.map { $0.toDomain() },
            tags: tags,
            createdAt: createdAt,
            lastEditedAt: lastEditedAt
        )
    }
}

extension StudyGuide {
    func toDTO() -> StudyGuideDTO {
        StudyGuideDTO(
            id: id,
            parentFolderId: parentFolderId,
            courseId: courseId,
            originLessonId: originLessonId,
            title: title,
            markdownContent: markdownContent,
            attachments: attachments.map { $0.toDTO() },
            tags: tags,
            createdAt: createdAt,
            lastEditedAt: lastEditedAt
        )
    }
}

// MARK: - StudyEventDTO

@preconcurrency struct StudyEventDTO: Identifiable, Equatable, Hashable, Sendable {
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case sessionId
        case kind
        case deckId
        case cardId
        case queueMode
        case attemptIndex
        case conceptsAtTime
        case elapsedMs
        case grade
        case predictedRecallAtStart
        case confusionScore
        case confusionReasons
        case interventionKind
        case interventionAction
        case adaptiveSuccessRate
        case adaptiveTargetPSuccess
        case adaptiveChosenPSuccess
        case xpAmount
        case xpReason
        case streakAtAward
        case celebrationType
        case threshold
        case intensity
        case nudgeType
        case nudgeScore
        case source
        case cooldownRemainingSec
        case nudgeActionValue
        case hintLevel
        case entryPoint
        case challengeModeActionValue
        case predictedRecallBucket
        case badgeId
        case badgeTier
        case progressBefore
        case progressAfter
        case conceptCount
        case wasSuccessful
    }
    
    init(
        id: UUID,
        timestamp: Date,
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

extension StudyEventDTO: Codable {
    nonisolated(unsafe) init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        kind = try container.decode(Kind.self, forKey: .kind)
        deckId = try container.decodeIfPresent(UUID.self, forKey: .deckId)
        cardId = try container.decodeIfPresent(UUID.self, forKey: .cardId)
        queueMode = try container.decodeIfPresent(String.self, forKey: .queueMode)
        attemptIndex = try container.decodeIfPresent(Int.self, forKey: .attemptIndex)
        conceptsAtTime = try container.decodeIfPresent([String].self, forKey: .conceptsAtTime)
        elapsedMs = try container.decodeIfPresent(Int.self, forKey: .elapsedMs)
        grade = try container.decodeIfPresent(Int.self, forKey: .grade)
        predictedRecallAtStart = try container.decodeIfPresent(Double.self, forKey: .predictedRecallAtStart)
        confusionScore = try container.decodeIfPresent(Double.self, forKey: .confusionScore)
        confusionReasons = try container.decodeIfPresent([String].self, forKey: .confusionReasons)
        interventionKind = try container.decodeIfPresent(String.self, forKey: .interventionKind)
        interventionAction = try container.decodeIfPresent(String.self, forKey: .interventionAction)
        adaptiveSuccessRate = try container.decodeIfPresent(Double.self, forKey: .adaptiveSuccessRate)
        adaptiveTargetPSuccess = try container.decodeIfPresent(Double.self, forKey: .adaptiveTargetPSuccess)
        adaptiveChosenPSuccess = try container.decodeIfPresent(Double.self, forKey: .adaptiveChosenPSuccess)
        xpAmount = try container.decodeIfPresent(Int.self, forKey: .xpAmount)
        xpReason = try container.decodeIfPresent(String.self, forKey: .xpReason)
        streakAtAward = try container.decodeIfPresent(Int.self, forKey: .streakAtAward)
        celebrationType = try container.decodeIfPresent(String.self, forKey: .celebrationType)
        threshold = try container.decodeIfPresent(Int.self, forKey: .threshold)
        intensity = try container.decodeIfPresent(String.self, forKey: .intensity)
        nudgeType = try container.decodeIfPresent(String.self, forKey: .nudgeType)
        nudgeScore = try container.decodeIfPresent(Double.self, forKey: .nudgeScore)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        cooldownRemainingSec = try container.decodeIfPresent(Int.self, forKey: .cooldownRemainingSec)
        nudgeActionValue = try container.decodeIfPresent(String.self, forKey: .nudgeActionValue)
        hintLevel = try container.decodeIfPresent(Int.self, forKey: .hintLevel)
        entryPoint = try container.decodeIfPresent(String.self, forKey: .entryPoint)
        challengeModeActionValue = try container.decodeIfPresent(String.self, forKey: .challengeModeActionValue)
        predictedRecallBucket = try container.decodeIfPresent(String.self, forKey: .predictedRecallBucket)
        badgeId = try container.decodeIfPresent(String.self, forKey: .badgeId)
        badgeTier = try container.decodeIfPresent(String.self, forKey: .badgeTier)
        progressBefore = try container.decodeIfPresent(Double.self, forKey: .progressBefore)
        progressAfter = try container.decodeIfPresent(Double.self, forKey: .progressAfter)
        conceptCount = try container.decodeIfPresent(Int.self, forKey: .conceptCount)
        wasSuccessful = try container.decodeIfPresent(Bool.self, forKey: .wasSuccessful)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(deckId, forKey: .deckId)
        try container.encodeIfPresent(cardId, forKey: .cardId)
        try container.encodeIfPresent(queueMode, forKey: .queueMode)
        try container.encodeIfPresent(attemptIndex, forKey: .attemptIndex)
        try container.encodeIfPresent(conceptsAtTime, forKey: .conceptsAtTime)
        try container.encodeIfPresent(elapsedMs, forKey: .elapsedMs)
        try container.encodeIfPresent(grade, forKey: .grade)
        try container.encodeIfPresent(predictedRecallAtStart, forKey: .predictedRecallAtStart)
        try container.encodeIfPresent(confusionScore, forKey: .confusionScore)
        try container.encodeIfPresent(confusionReasons, forKey: .confusionReasons)
        try container.encodeIfPresent(interventionKind, forKey: .interventionKind)
        try container.encodeIfPresent(interventionAction, forKey: .interventionAction)
        try container.encodeIfPresent(adaptiveSuccessRate, forKey: .adaptiveSuccessRate)
        try container.encodeIfPresent(adaptiveTargetPSuccess, forKey: .adaptiveTargetPSuccess)
        try container.encodeIfPresent(adaptiveChosenPSuccess, forKey: .adaptiveChosenPSuccess)
        try container.encodeIfPresent(xpAmount, forKey: .xpAmount)
        try container.encodeIfPresent(xpReason, forKey: .xpReason)
        try container.encodeIfPresent(streakAtAward, forKey: .streakAtAward)
        try container.encodeIfPresent(celebrationType, forKey: .celebrationType)
        try container.encodeIfPresent(threshold, forKey: .threshold)
        try container.encodeIfPresent(intensity, forKey: .intensity)
        try container.encodeIfPresent(nudgeType, forKey: .nudgeType)
        try container.encodeIfPresent(nudgeScore, forKey: .nudgeScore)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(cooldownRemainingSec, forKey: .cooldownRemainingSec)
        try container.encodeIfPresent(nudgeActionValue, forKey: .nudgeActionValue)
        try container.encodeIfPresent(hintLevel, forKey: .hintLevel)
        try container.encodeIfPresent(entryPoint, forKey: .entryPoint)
        try container.encodeIfPresent(challengeModeActionValue, forKey: .challengeModeActionValue)
        try container.encodeIfPresent(predictedRecallBucket, forKey: .predictedRecallBucket)
        try container.encodeIfPresent(badgeId, forKey: .badgeId)
        try container.encodeIfPresent(badgeTier, forKey: .badgeTier)
        try container.encodeIfPresent(progressBefore, forKey: .progressBefore)
        try container.encodeIfPresent(progressAfter, forKey: .progressAfter)
        try container.encodeIfPresent(conceptCount, forKey: .conceptCount)
        try container.encodeIfPresent(wasSuccessful, forKey: .wasSuccessful)
    }
    
    func toDomain() -> StudyEvent {
        StudyEvent(
            id: id,
            timestamp: timestamp,
            sessionId: sessionId,
            kind: StudyEvent.Kind(rawValue: kind.rawValue) ?? .sessionStarted,
            deckId: deckId,
            cardId: cardId,
            queueMode: queueMode,
            attemptIndex: attemptIndex,
            conceptsAtTime: conceptsAtTime,
            elapsedMs: elapsedMs,
            grade: grade,
            predictedRecallAtStart: predictedRecallAtStart,
            confusionScore: confusionScore,
            confusionReasons: confusionReasons,
            interventionKind: interventionKind,
            interventionAction: interventionAction,
            adaptiveSuccessRate: adaptiveSuccessRate,
            adaptiveTargetPSuccess: adaptiveTargetPSuccess,
            adaptiveChosenPSuccess: adaptiveChosenPSuccess,
            xpAmount: xpAmount,
            xpReason: xpReason,
            streakAtAward: streakAtAward,
            celebrationType: celebrationType,
            threshold: threshold,
            intensity: intensity,
            nudgeType: nudgeType,
            nudgeScore: nudgeScore,
            source: source,
            cooldownRemainingSec: cooldownRemainingSec,
            nudgeActionValue: nudgeActionValue,
            hintLevel: hintLevel,
            entryPoint: entryPoint,
            challengeModeActionValue: challengeModeActionValue,
            predictedRecallBucket: predictedRecallBucket,
            badgeId: badgeId,
            badgeTier: badgeTier,
            progressBefore: progressBefore,
            progressAfter: progressAfter,
            conceptCount: conceptCount,
            wasSuccessful: wasSuccessful
        )
    }
}

extension StudyEvent {
    func toDTO() -> StudyEventDTO {
        StudyEventDTO(
            id: id,
            timestamp: timestamp,
            sessionId: sessionId,
            kind: StudyEventDTO.Kind(rawValue: kind.rawValue) ?? .sessionStarted,
            deckId: deckId,
            cardId: cardId,
            queueMode: queueMode,
            attemptIndex: attemptIndex,
            conceptsAtTime: conceptsAtTime,
            elapsedMs: elapsedMs,
            grade: grade,
            predictedRecallAtStart: predictedRecallAtStart,
            confusionScore: confusionScore,
            confusionReasons: confusionReasons,
            interventionKind: interventionKind,
            interventionAction: interventionAction,
            adaptiveSuccessRate: adaptiveSuccessRate,
            adaptiveTargetPSuccess: adaptiveTargetPSuccess,
            adaptiveChosenPSuccess: adaptiveChosenPSuccess,
            xpAmount: xpAmount,
            xpReason: xpReason,
            streakAtAward: streakAtAward,
            celebrationType: celebrationType,
            threshold: threshold,
            intensity: intensity,
            nudgeType: nudgeType,
            nudgeScore: nudgeScore,
            source: source,
            cooldownRemainingSec: cooldownRemainingSec,
            nudgeActionValue: nudgeActionValue,
            hintLevel: hintLevel,
            entryPoint: entryPoint,
            challengeModeActionValue: challengeModeActionValue,
            predictedRecallBucket: predictedRecallBucket,
            badgeId: badgeId,
            badgeTier: badgeTier,
            progressBefore: progressBefore,
            progressAfter: progressAfter,
            conceptCount: conceptCount,
            wasSuccessful: wasSuccessful
        )
    }
}

// MARK: - CourseDTO

struct CourseDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var courseCode: String?
    var examDate: Date?
    var weeklyTimeBudgetMinutes: Int?
    var colorHex: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case courseCode
        case examDate
        case weeklyTimeBudgetMinutes
        case colorHex
        case createdAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        courseCode: String? = nil,
        examDate: Date? = nil,
        weeklyTimeBudgetMinutes: Int? = nil,
        colorHex: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.courseCode = courseCode
        self.examDate = examDate
        self.weeklyTimeBudgetMinutes = weeklyTimeBudgetMinutes
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        courseCode = try container.decodeIfPresent(String.self, forKey: .courseCode)
        examDate = try container.decodeIfPresent(Date.self, forKey: .examDate)
        weeklyTimeBudgetMinutes = try container.decodeIfPresent(Int.self, forKey: .weeklyTimeBudgetMinutes)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(courseCode, forKey: .courseCode)
        try container.encodeIfPresent(examDate, forKey: .examDate)
        try container.encodeIfPresent(weeklyTimeBudgetMinutes, forKey: .weeklyTimeBudgetMinutes)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    func toDomain() -> Course {
        Course(
            id: id,
            name: name,
            courseCode: courseCode,
            examDate: examDate,
            weeklyTimeBudgetMinutes: weeklyTimeBudgetMinutes,
            colorHex: colorHex,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension Course {
    func toDTO() -> CourseDTO {
        CourseDTO(
            id: id,
            name: name,
            courseCode: courseCode,
            examDate: examDate,
            weeklyTimeBudgetMinutes: weeklyTimeBudgetMinutes,
            colorHex: colorHex,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - LessonDTO

struct LessonDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var courseId: UUID
    var title: String
    var summary: String?
    var createdAt: Date
    var updatedAt: Date
    var sourceType: LessonSourceType
    var status: LessonStatus

    enum CodingKeys: String, CodingKey {
        case id
        case courseId
        case title
        case summary
        case createdAt
        case updatedAt
        case sourceType
        case status
    }

    init(
        id: UUID = UUID(),
        courseId: UUID,
        title: String,
        summary: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceType: LessonSourceType = .upload,
        status: LessonStatus = .ready
    ) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceType = sourceType
        self.status = status
    }

    func toDomain() -> Lesson {
        Lesson(
            id: id,
            courseId: courseId,
            title: title,
            summary: summary,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sourceType: sourceType,
            status: status
        )
    }
}

extension Lesson {
    func toDTO() -> LessonDTO {
        LessonDTO(
            id: id,
            courseId: courseId,
            title: title,
            summary: summary,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sourceType: sourceType,
            status: status
        )
    }
}

// MARK: - LessonGenerationJobDTO

struct LessonGenerationJobDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var lessonId: UUID
    var kind: LessonArtifactKind
    var status: ArtifactStatus
    var itemCount: Int
    var errorMessage: String?
    var startedAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case lessonId
        case kind
        case status
        case itemCount
        case errorMessage
        case startedAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        lessonId: UUID,
        kind: LessonArtifactKind,
        status: ArtifactStatus,
        itemCount: Int = 0,
        errorMessage: String? = nil,
        startedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.lessonId = lessonId
        self.kind = kind
        self.status = status
        self.itemCount = itemCount
        self.errorMessage = errorMessage
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }
}

// MARK: - CourseTopicDTO

struct CourseTopicDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var courseId: UUID
    var name: String
    var sortOrder: Int
    var sourceDescription: String?

    enum CodingKeys: String, CodingKey {
        case id
        case courseId
        case name
        case sortOrder
        case sourceDescription
    }

    init(
        id: UUID = UUID(),
        courseId: UUID,
        name: String,
        sortOrder: Int = 0,
        sourceDescription: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.name = name
        self.sortOrder = sortOrder
        self.sourceDescription = sourceDescription
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        name = try container.decode(String.self, forKey: .name)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        sourceDescription = try container.decodeIfPresent(String.self, forKey: .sourceDescription)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(courseId, forKey: .courseId)
        try container.encode(name, forKey: .name)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encodeIfPresent(sourceDescription, forKey: .sourceDescription)
    }

    func toDomain() -> CourseTopic {
        CourseTopic(
            id: id,
            courseId: courseId,
            name: name,
            sortOrder: sortOrder,
            sourceDescription: sourceDescription
        )
    }
}

extension CourseTopic {
    func toDTO() -> CourseTopicDTO {
        CourseTopicDTO(
            id: id,
            courseId: courseId,
            name: name,
            sortOrder: sortOrder,
            sourceDescription: sourceDescription
        )
    }
}

// MARK: - CourseMaterialDTO

struct CourseMaterialDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var courseId: UUID
    var topicId: UUID?
    var lessonId: UUID?
    var filename: String
    var fileType: String
    var extractedText: String?
    var wordCount: Int?
    var processingStatus: CourseMaterialProcessingStatus
    var processingError: String?
    var processedAt: Date?
    var importedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case courseId
        case topicId
        case lessonId
        case filename
        case fileType
        case extractedText
        case wordCount
        case processingStatus
        case processingError
        case processedAt
        case importedAt
    }

    init(
        id: UUID = UUID(),
        courseId: UUID,
        topicId: UUID? = nil,
        lessonId: UUID? = nil,
        filename: String,
        fileType: String,
        extractedText: String? = nil,
        wordCount: Int? = nil,
        processingStatus: CourseMaterialProcessingStatus = .ready,
        processingError: String? = nil,
        processedAt: Date? = nil,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.topicId = topicId
        self.lessonId = lessonId
        self.filename = filename
        self.fileType = fileType
        self.extractedText = extractedText
        self.wordCount = wordCount
        self.processingStatus = processingStatus
        self.processingError = processingError
        self.processedAt = processedAt
        self.importedAt = importedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        topicId = try container.decodeIfPresent(UUID.self, forKey: .topicId)
        lessonId = try container.decodeIfPresent(UUID.self, forKey: .lessonId)
        filename = try container.decode(String.self, forKey: .filename)
        fileType = try container.decode(String.self, forKey: .fileType)
        extractedText = try container.decodeIfPresent(String.self, forKey: .extractedText)
        wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount)
        processingStatus = try container.decodeIfPresent(CourseMaterialProcessingStatus.self, forKey: .processingStatus) ?? .ready
        processingError = try container.decodeIfPresent(String.self, forKey: .processingError)
        processedAt = try container.decodeIfPresent(Date.self, forKey: .processedAt)
        importedAt = try container.decodeIfPresent(Date.self, forKey: .importedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(courseId, forKey: .courseId)
        try container.encodeIfPresent(topicId, forKey: .topicId)
        try container.encodeIfPresent(lessonId, forKey: .lessonId)
        try container.encode(filename, forKey: .filename)
        try container.encode(fileType, forKey: .fileType)
        try container.encodeIfPresent(extractedText, forKey: .extractedText)
        try container.encodeIfPresent(wordCount, forKey: .wordCount)
        try container.encode(processingStatus, forKey: .processingStatus)
        try container.encodeIfPresent(processingError, forKey: .processingError)
        try container.encodeIfPresent(processedAt, forKey: .processedAt)
        try container.encode(importedAt, forKey: .importedAt)
    }

    func toDomain() -> CourseMaterial {
        CourseMaterial(
            id: id,
            courseId: courseId,
            topicId: topicId,
            lessonId: lessonId,
            filename: filename,
            fileType: fileType,
            extractedText: extractedText,
            wordCount: wordCount,
            processingStatus: processingStatus,
            processingError: processingError,
            processedAt: processedAt,
            importedAt: importedAt
        )
    }
}

extension CourseMaterial {
    func toDTO() -> CourseMaterialDTO {
        CourseMaterialDTO(
            id: id,
            courseId: courseId,
            topicId: topicId,
            lessonId: lessonId,
            filename: filename,
            fileType: fileType,
            extractedText: extractedText,
            wordCount: wordCount,
            processingStatus: processingStatus,
            processingError: processingError,
            processedAt: processedAt,
            importedAt: importedAt
        )
    }
}
