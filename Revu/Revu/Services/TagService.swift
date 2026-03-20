@preconcurrency import Foundation

struct TagService {
    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    func allTags() async -> [String] {
        if let appStorage = storage as? LocalStore {
            return await appStorage.tagsSnapshot()
        }
        let cards = (try? await storage.allCards()) ?? []
        let unique = Set(cards.flatMap(\.tags))
        return unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
