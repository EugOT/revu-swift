import Foundation

@MainActor
struct DeckMergeService {
    enum MergeError: Error {
        case sourceNotFound
        case destinationNotFound
        case sourceHasSubdecks
    }

    struct Result {
        let cardsMoved: Int
    }

    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    func mergeDeck(withId sourceId: UUID, into destinationId: UUID) async throws -> Result {
        guard sourceId != destinationId else { return Result(cardsMoved: 0) }
        guard (try? await storage.deck(withId: sourceId)) != nil else {
            throw MergeError.sourceNotFound
        }
        guard let destinationDeck = try await storage.deck(withId: destinationId) else {
            throw MergeError.destinationNotFound
        }

        let allDecks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        if allDecks.contains(where: { $0.parentId == sourceId }) {
            throw MergeError.sourceHasSubdecks
        }

        let cards = try await storage.cards(deckId: sourceId)
        for var card in cards {
            card.deckId = destinationId
            card.updatedAt = Date()
            try await storage.upsert(card: card)
        }

        try await storage.deleteDeck(id: sourceId)

        _ = await StudyPlanService(storage: storage).rebuildDeckPlan(
            forDeckId: destinationDeck.id,
            dueDate: destinationDeck.dueDate
        )

        return Result(cardsMoved: cards.count)
    }
}
