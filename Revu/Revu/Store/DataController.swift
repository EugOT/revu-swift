@preconcurrency import Foundation

@MainActor
final class DataController {
    static let shared = DataController()

    let storage: LocalStore
    let events: StoreEvents

    init(
        rootURL: URL? = nil,
        storage: LocalStore? = nil
    ) {
        do {
            if let storage {
                self.storage = storage
            } else {
                self.storage = try SQLiteStorage(rootURL: rootURL)
            }
            self.events = self.storage.storeEvents()
            Task {
                _ = try? await self.storage.loadSettings()
            }
        } catch {
            fatalError("Failed to bootstrap SQLite storage: \(error)")
        }
    }

    func loadSettings() async throws -> UserSettings {
        try await storage.loadSettings().toDomain()
    }

    func save(settings: UserSettings) async {
        do {
            try await storage.save(settings: settings.toDTO())
            events.notify() // Notify observers that settings changed
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    func flush() async {
        try? await storage.flush()
    }
}

extension DataController {
    static func previewController() -> DataController {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            let storage = try SQLiteStorage(rootURL: temporary)
            let controller = DataController(storage: storage)
            Task {
                let deck = Deck(name: "Preview Deck", note: nil)
                try await controller.storage.upsert(deck: deck.toDTO())
                let card = Card(deckId: deck.id, kind: .basic, front: "Sample", back: "Answer")
                try await controller.storage.upsert(card: card.toDTO())
            }
            return controller
        } catch {
            fatalError("Failed to create preview controller: \(error)")
        }
    }
}
