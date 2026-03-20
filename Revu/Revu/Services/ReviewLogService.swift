@preconcurrency import Foundation

struct ReviewLogService {
    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    func recentLogs(limit: Int = 100) async -> [ReviewLog] {
        (try? await storage.recentLogs(limit: limit).map { $0.toDomain() }) ?? []
    }

    func append(_ log: ReviewLog) async {
        try? await storage.append(log: log.toDTO())
    }
}
