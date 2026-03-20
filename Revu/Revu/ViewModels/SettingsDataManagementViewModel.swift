import Combine
import Foundation

@MainActor
final class SettingsDataManagementViewModel: ObservableObject {
    @Published private(set) var isWorking: Bool = false

    private let storage: Storage

    init(storage: Storage? = nil) {
        self.storage = storage ?? DataController.shared.storage
    }

    func deleteAllLocalData() async throws {
        try await perform {
            NotificationService.shared.cancelReminders()

            if let appStorage = storage as? LocalStore {
                try await appStorage.wipeAllLocalData()
                return
            }

            try await removeAllDecksFallback()
            try await resetSettingsFallback()
        }
    }

    func removeAllDecks() async throws {
        try await perform {
            try await removeAllDecksFallback()
        }
    }

    func archiveAllDecks() async throws {
        try await perform {
            await DeckService(storage: storage).archiveAllDecks()
        }
    }

    private func perform(_ operation: () async throws -> Void) async throws {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        try await operation()
    }

    private func removeAllDecksFallback() async throws {
        let decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        guard !decks.isEmpty else { return }
        let rootDeckIDs = decks.filter { $0.parentId == nil }.map(\.id)
        let service = DeckService(storage: storage)
        for id in rootDeckIDs {
            await service.delete(deckId: id)
        }
    }

	    private func resetSettingsFallback() async throws {
	        let defaults = UserSettingsDTO(
	            id: UUID(),
	            dailyNewLimit: AppSettingsDefaults.dailyNewLimit,
	            dailyReviewLimit: AppSettingsDefaults.dailyReviewLimit,
	            learningStepsMinutes: AppSettingsDefaults.learningStepsMinutes,
	            lapseStepsMinutes: AppSettingsDefaults.lapseStepsMinutes,
	            easeMin: AppSettingsDefaults.easeMin,
	            burySiblings: AppSettingsDefaults.burySiblings,
	            keyboardHints: AppSettingsDefaults.keyboardHints,
	            autoAdvance: AppSettingsDefaults.autoAdvance,
	            retentionTarget: AppSettingsDefaults.retentionTarget,
	            enableResponseTimeTuning: AppSettingsDefaults.enableResponseTimeTuning,
	            proactiveInterventionsEnabled: AppSettingsDefaults.proactiveInterventionsEnabled,
	            interventionSensitivity: AppSettingsDefaults.interventionSensitivity.rawValue,
	            interventionCooldownMinutes: AppSettingsDefaults.interventionCooldownMinutes,
	            challengeModeDefaultEnabled: AppSettingsDefaults.challengeModeDefaultEnabled,
	            celebrationIntensity: AppSettingsDefaults.celebrationIntensity.rawValue,
	            dailyGoalTarget: AppSettingsDefaults.dailyGoalTarget,
	            useCloudSync: AppSettingsDefaults.useCloudSync,
	            notificationsEnabled: AppSettingsDefaults.notificationsEnabled,
	            notificationHour: AppSettingsDefaults.notificationHour,
	            notificationMinute: AppSettingsDefaults.notificationMinute,
	            dataLocationBookmark: nil,
	            appearanceMode: nil,
	            deckSortOrder: [],
	            deckSortMode: AppSettingsDefaults.deckSortMode.rawValue,
	            hasCompletedOnboarding: AppSettingsDefaults.hasCompletedOnboarding,
	            userName: AppSettingsDefaults.userName,
	            studyGoal: AppSettingsDefaults.studyGoal
	        )
	        try? await storage.save(settings: defaults)
	    }
}
