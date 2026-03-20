@preconcurrency import Foundation

enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

enum DeckSortMode: String, Codable, CaseIterable, Sendable {
    case manual = "Manual"
    case nameAscending = "Name A-Z"
    case nameDescending = "Name Z-A"
    case dateModifiedNewest = "Date Modified (Newest)"
    case dateModifiedOldest = "Date Modified (Oldest)"
    case dateCreatedNewest = "Date Created (Newest)"
    case dateCreatedOldest = "Date Created (Oldest)"
    
    var displayName: String {
        rawValue
    }
}

enum InterventionSensitivity: String, Codable, CaseIterable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var displayName: String { rawValue }
}

enum CelebrationIntensity: String, Codable, CaseIterable, Sendable {
    case subtle = "Subtle"
    case balanced = "Balanced"
    case lively = "Lively"

    var displayName: String { rawValue }
}

struct UserSettings: Identifiable, Codable, Equatable, Hashable, Sendable {
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
    var interventionSensitivity: InterventionSensitivity
    var interventionCooldownMinutes: Int
    var challengeModeDefaultEnabled: Bool
    var celebrationIntensity: CelebrationIntensity
    var dailyGoalTarget: Int
    var useCloudSync: Bool
    var notificationsEnabled: Bool
    var notificationHour: Int
    var notificationMinute: Int
    var dataLocationBookmark: Data?
    var appearanceMode: AppearanceMode
    var deckSortOrder: [UUID]
    var deckSortMode: DeckSortMode
    var hasCompletedOnboarding: Bool
    var userName: String
    var studyGoal: String
    

    init(
        id: UUID = UUID(),
        dailyNewLimit: Int = AppSettingsDefaults.dailyNewLimit,
        dailyReviewLimit: Int = AppSettingsDefaults.dailyReviewLimit,
        learningStepsMinutes: [Double] = AppSettingsDefaults.learningStepsMinutes,
        lapseStepsMinutes: [Double] = AppSettingsDefaults.lapseStepsMinutes,
        easeMin: Double = AppSettingsDefaults.easeMin,
        burySiblings: Bool = AppSettingsDefaults.burySiblings,
        keyboardHints: Bool = AppSettingsDefaults.keyboardHints,
        autoAdvance: Bool = AppSettingsDefaults.autoAdvance,
        retentionTarget: Double = AppSettingsDefaults.retentionTarget,
        enableResponseTimeTuning: Bool = AppSettingsDefaults.enableResponseTimeTuning,
        proactiveInterventionsEnabled: Bool = AppSettingsDefaults.proactiveInterventionsEnabled,
        interventionSensitivity: InterventionSensitivity = AppSettingsDefaults.interventionSensitivity,
        interventionCooldownMinutes: Int = AppSettingsDefaults.interventionCooldownMinutes,
        challengeModeDefaultEnabled: Bool = AppSettingsDefaults.challengeModeDefaultEnabled,
        celebrationIntensity: CelebrationIntensity = AppSettingsDefaults.celebrationIntensity,
        dailyGoalTarget: Int = AppSettingsDefaults.dailyGoalTarget,
        useCloudSync: Bool = AppSettingsDefaults.useCloudSync,
        notificationsEnabled: Bool = AppSettingsDefaults.notificationsEnabled,
        notificationHour: Int = AppSettingsDefaults.notificationHour,
        notificationMinute: Int = AppSettingsDefaults.notificationMinute,
        dataLocationBookmark: Data? = nil,
        appearanceMode: AppearanceMode = AppSettingsDefaults.appearanceMode,
        deckSortOrder: [UUID] = [],
        deckSortMode: DeckSortMode = AppSettingsDefaults.deckSortMode,
        hasCompletedOnboarding: Bool = AppSettingsDefaults.hasCompletedOnboarding,
        userName: String = AppSettingsDefaults.userName,
        studyGoal: String = AppSettingsDefaults.studyGoal
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
        self.retentionTarget = min(max(retentionTarget, 0.8), 0.95)
        self.enableResponseTimeTuning = enableResponseTimeTuning
        self.proactiveInterventionsEnabled = proactiveInterventionsEnabled
        self.interventionSensitivity = interventionSensitivity
        self.interventionCooldownMinutes = max(0, interventionCooldownMinutes)
        self.challengeModeDefaultEnabled = challengeModeDefaultEnabled
        self.celebrationIntensity = celebrationIntensity
        self.dailyGoalTarget = max(1, dailyGoalTarget)
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

enum AppSettingsDefaults {
    static let dailyNewLimit = 20
    static let dailyReviewLimit = 200
    static let learningStepsMinutes: [Double] = [1.0, 10.0, 1440.0]
    static let lapseStepsMinutes: [Double] = [1.0, 10.0]
    static let easeMin = 1.3
    static let burySiblings = true
    static let keyboardHints = true
    static let autoAdvance = false
    static let retentionTarget: Double = 0.9
    static let enableResponseTimeTuning = true
    static let proactiveInterventionsEnabled = true
    static let interventionSensitivity: InterventionSensitivity = .medium
    static let interventionCooldownMinutes = 10
    static let challengeModeDefaultEnabled = false
    static let celebrationIntensity: CelebrationIntensity = .balanced
    static let dailyGoalTarget = 30
    static let useCloudSync = false
    static let notificationsEnabled = false
    static let notificationHour = 9
    static let notificationMinute = 0
    static let appearanceMode = AppearanceMode.system
    static let deckSortMode = DeckSortMode.manual
    static let hasCompletedOnboarding = false
    static let userName = "Welcome"
    static let studyGoal = "University"
}
