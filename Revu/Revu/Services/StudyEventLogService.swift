@preconcurrency import Foundation

struct StudyEventLogService {
    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    func recentEvents(limit: Int = 100) async -> [StudyEvent] {
        (try? await storage.recentEvents(limit: limit).map { $0.toDomain() }) ?? []
    }

    func append(_ event: StudyEvent) async {
        try? await storage.append(event: event.toDTO())
    }
}
