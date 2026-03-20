@preconcurrency import Foundation

struct CardService {
    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    func cards(deckId: UUID?, includeSubdecks: Bool = true) async -> [Card] {
        if let deckId {
            if includeSubdecks {
                return await cardsInDeckSubtree(rootDeckId: deckId)
            }
            let dtos = (try? await storage.cards(deckId: deckId)) ?? []
            return await mapAndSortByUpdatedAtDescending(dtos)
        }
        let dtos = (try? await storage.allCards()) ?? []
        return await mapAndSortByUpdatedAtDescending(dtos)
    }

    func allCards() async -> [Card] {
        await cards(deckId: nil)
    }

    func searchCards(query: String, deckId: UUID? = nil, tags: Set<String> = []) async -> [Card] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty && tags.isEmpty {
            return await cards(deckId: deckId)
        }
        if let deckId {
            let decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
            let hierarchy = DeckHierarchy(decks: decks)
            let ids = hierarchy.subtreeDeckIDs(of: deckId)
            var collected: [CardDTO] = []
            for id in ids {
                let results = (try? await storage.searchCards(text: text, tags: tags, deckId: id)) ?? []
                collected.append(contentsOf: results)
            }
            var unique: [UUID: CardDTO] = [:]
            for dto in collected {
                unique[dto.id] = dto
            }
            return await mapAndSortByUpdatedAtDescending(Array(unique.values))
        }

        let results = try? await storage.searchCards(text: text, tags: tags, deckId: nil)
        return await mapAndSortByUpdatedAtDescending(results ?? [])
    }

    func upsert(card: Card, updateTimestamp: Bool = true) async {
        let existingDTO = (try? await storage.card(withId: card.id)) ?? nil
        let previousDeckId = existingDTO?.deckId

        var updated = card
        if updateTimestamp {
            updated.updatedAt = Date()
        }

        try? await storage.upsert(card: updated.toDTO())

        let planner = StudyPlanService(storage: storage)

        func deckDueDate(for deckId: UUID) async -> Date? {
            guard let deckDTO = (try? await storage.deck(withId: deckId)) ?? nil else { return nil }
            return deckDTO.dueDate
        }

        if let priorDeck = previousDeckId, priorDeck != updated.deckId {
            let dueDate = await deckDueDate(for: priorDeck)
            _ = await planner.rebuildDeckPlan(forDeckId: priorDeck, dueDate: dueDate)
        }

        if let deckId = updated.deckId {
            let shouldReplan = existingDTO == nil || previousDeckId != deckId
            guard shouldReplan else { return }
            let dueDate = await deckDueDate(for: deckId)
            _ = await planner.rebuildDeckPlan(forDeckId: deckId, dueDate: dueDate)
        }
    }

    func delete(cardId: UUID) async {
        try? await storage.deleteCard(id: cardId)
    }
}

private extension CardService {
    func cardsInDeckSubtree(rootDeckId: UUID) async -> [Card] {
        let decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        let hierarchy = DeckHierarchy(decks: decks)
        let ids = hierarchy.subtreeDeckIDs(of: rootDeckId)

        var collected: [CardDTO] = []
        for id in ids {
            let cards = (try? await storage.cards(deckId: id)) ?? []
            collected.append(contentsOf: cards)
        }

        var unique: [UUID: CardDTO] = [:]
        for dto in collected {
            unique[dto.id] = dto
        }
        return await mapAndSortByUpdatedAtDescending(Array(unique.values))
    }

    func mapAndSortByUpdatedAtDescending(_ dtos: [CardDTO]) async -> [Card] {
        let mapped = dtos.map { $0.toDomain() }
        return await Task.detached(priority: .userInitiated) {
            mapped.sorted { $0.updatedAt > $1.updatedAt }
        }.value
    }
}
