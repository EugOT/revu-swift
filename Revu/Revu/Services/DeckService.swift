@preconcurrency import Foundation

struct DeckService {
    private let storage: Storage
    private let hierarchySeparator = "::"

    init(storage: Storage) {
        self.storage = storage
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    func allDecks(includeArchived: Bool = true) async -> [Deck] {
        var decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []

        if decks.contains(where: shouldMigrateLegacyPathDeck(_:)) {
            await migrateLegacyPathDecksIfNeeded(existingDecks: decks)
            decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        }

        if includeArchived { return decks }
        return decks.filter { !$0.isArchived }
    }

    func deck(withId id: UUID) async -> Deck? {
        guard let dto = try? await storage.deck(withId: id) else { return nil }
        return dto.toDomain()
    }

    func upsert(deck: Deck) async {
        var updated = deck
        updated.dueDate = sanitizedDeckDueDate(updated.dueDate)
        updated.updatedAt = Date()
        try? await storage.upsert(deck: updated.toDTO())
    }

    func setArchiveStatus(deckId: UUID, isArchived: Bool) async {
        guard let root = await deck(withId: deckId) else { return }
        guard root.isArchived != isArchived else { return }

        let decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        let hierarchy = DeckHierarchy(decks: decks)
        let subtree = hierarchy.subtreeDeckIDs(of: deckId)

        for id in subtree {
            guard var deck = hierarchy.deck(id: id) else { continue }
            deck.isArchived = isArchived
            deck.updatedAt = Date()
            try? await storage.upsert(deck: deck.toDTO())
        }

        await applyArchiveSuspension(toDeckIDs: subtree, isArchived: isArchived)

        let planner = StudyPlanService(storage: storage)
        for id in subtree {
            guard let deck = hierarchy.deck(id: id) else { continue }
            _ = await planner.rebuildDeckPlan(forDeckId: id, dueDate: deck.dueDate)
        }
    }

    func delete(deckId: UUID) async {
        let decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        let hierarchy = DeckHierarchy(decks: decks)
        let subtree = hierarchy.subtreeDeckIDs(of: deckId)

        for id in subtree.reversed() {
            try? await storage.deleteDeck(id: id)
        }
    }

    func archiveAllDecks() async {
        let decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        guard !decks.isEmpty else { return }

        let now = Date()

        for deck in decks {
            guard !deck.isArchived else { continue }
            var updated = deck
            updated.isArchived = true
            updated.updatedAt = now
            try? await storage.upsert(deck: updated.toDTO())
        }

        await applyArchiveSuspension(toDeckIDs: decks.map(\.id), isArchived: true)

        let planner = StudyPlanService(storage: storage)
        for deck in decks {
            _ = await planner.rebuildDeckPlan(forDeckId: deck.id, dueDate: deck.dueDate)
        }
    }

    func reparent(deckId: UUID, toParentId parentId: UUID?) async {
        let decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        let hierarchy = DeckHierarchy(decks: decks)
        guard hierarchy.canReparent(deckId: deckId, toParentId: parentId) else { return }
        guard var deck = hierarchy.deck(id: deckId) else { return }
        guard deck.parentId != parentId else { return }
        deck.parentId = parentId
        deck.updatedAt = Date()
        try? await storage.upsert(deck: deck.toDTO())
    }

    private func applyArchiveSuspension(toDeckIDs deckIds: [UUID], isArchived: Bool) async {
        var anyChanged = false
        for deckId in deckIds {
            guard let cardDTOs = try? await storage.cards(deckId: deckId) else { continue }
            print("archive deck \(deckId) cards=\(cardDTOs.count) isArchived=\(isArchived)")
            for dto in cardDTOs {
                var card = dto.toDomain()

                if isArchived {
                    guard !card.isSuspended else { continue }
                    card.isSuspended = true
                    card.suspendedByArchive = true
                    card.updatedAt = Date()
                } else {
                    guard card.suspendedByArchive else { continue }
                    card.isSuspended = false
                    card.suspendedByArchive = false
                    card.updatedAt = Date()
                }

                anyChanged = true
                print("archive update \(card.id) suspended=\(card.isSuspended) archived=\(card.suspendedByArchive)")
                do {
                    try await storage.upsert(card: card.toDTO())
                } catch {
                    print("Failed to update archive suspension for card \(card.id): \(error)")
                }
            }
        }

        guard anyChanged else { return }
    }

    private func sanitizedDeckDueDate(_ dueDate: Date?) -> Date? {
        guard let dueDate else { return nil }
        guard isReferenceSentinelOrNear(dueDate) else { return dueDate }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        if let endOfToday = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfToday) {
            return endOfToday
        }
        return Date()
    }

    private func isReferenceSentinelOrNear(_ date: Date) -> Bool {
        abs(date.timeIntervalSinceReferenceDate) < 172_800
    }

    private func shouldMigrateLegacyPathDeck(_ deck: Deck) -> Bool {
        deck.parentId == nil && deck.name.contains(hierarchySeparator)
    }

    private func migrateLegacyPathDecksIfNeeded(existingDecks: [Deck]) async {
        var decksById = Dictionary(uniqueKeysWithValues: existingDecks.map { ($0.id, $0) })

        func fullPath(for deck: Deck) -> String {
            guard let parentId = deck.parentId else { return deck.name }
            var components: [String] = [deck.name]
            var current = parentId
            var seen: Set<UUID> = [deck.id]
            while let parent = decksById[current] {
                guard seen.insert(parent.id).inserted else { break }
                components.append(parent.name)
                guard let next = parent.parentId else { break }
                current = next
            }
            return components.reversed().joined(separator: hierarchySeparator)
        }

        var pathToDeckId: [String: UUID] = [:]
        for deck in existingDecks {
            pathToDeckId[fullPath(for: deck)] = deck.id
        }

        let candidates = existingDecks.filter(shouldMigrateLegacyPathDeck(_:))
        guard !candidates.isEmpty else { return }

        for deck in candidates {
            let components = deck.name
                .components(separatedBy: hierarchySeparator)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard components.count >= 2 else { continue }

            var currentParentId: UUID? = nil
            for depth in 0..<(components.count - 1) {
                let prefix = components.prefix(depth + 1).joined(separator: hierarchySeparator)
                if let existingId = pathToDeckId[prefix] {
                    currentParentId = existingId
                    continue
                }

                let createdId = StableUUID.deckPathID(prefix)
                let parentDeck = Deck(
                    id: createdId,
                    parentId: currentParentId,
                    name: components[depth],
                    note: nil,
                    dueDate: nil,
                    createdAt: deck.createdAt,
                    updatedAt: Date(),
                    isArchived: deck.isArchived
                )
                try? await storage.upsert(deck: parentDeck.toDTO())
                decksById[parentDeck.id] = parentDeck
                pathToDeckId[prefix] = parentDeck.id
                currentParentId = parentDeck.id
            }

            var updated = deck
            updated.parentId = currentParentId
            updated.name = components.last ?? updated.name
            updated.updatedAt = Date()
            try? await storage.upsert(deck: updated.toDTO())
            decksById[updated.id] = updated

            let originalPath = components.joined(separator: hierarchySeparator)
            pathToDeckId[originalPath] = updated.id
        }
    }
}
