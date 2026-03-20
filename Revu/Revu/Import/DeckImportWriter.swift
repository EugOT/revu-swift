import Foundation

final class DeckImportWriter {
    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    func importDocument(
        _ document: ImportedDocument,
        mergePlan: DeckMergePlan? = nil,
        rebuildStudyPlans: Bool = true
    ) async throws -> ImportResult {
        let effectiveMergePlan = mergePlan ?? DeckMergePlan()
        if let appStorage = storage as? LocalStore {
            return try await appStorage.withBatchUpdates {
                try await importDocumentInternal(document, mergePlan: effectiveMergePlan, rebuildStudyPlans: rebuildStudyPlans)
            }
        }
        return try await importDocumentInternal(document, mergePlan: effectiveMergePlan, rebuildStudyPlans: rebuildStudyPlans)
    }

    private func importDocumentInternal(
        _ document: ImportedDocument,
        mergePlan: DeckMergePlan,
        rebuildStudyPlans: Bool
    ) async throws -> ImportResult {
        var decksInserted = 0
        var decksUpdated = 0
        var cardsInserted = 0
        var cardsUpdated = 0
        var cardsSkipped = 0
        var errors: [ImportErrorDetail] = []

        let decksToProcess = combineDecks(document.decks.map { mergePlan.applying(to: $0) })

        for deck in decksToProcess {
            do {
                let outcome = try await importDeck(deck, rebuildStudyPlans: rebuildStudyPlans)
                decksInserted += outcome.decksInserted
                decksUpdated += outcome.decksUpdated
                cardsInserted += outcome.cardsInserted
                cardsUpdated += outcome.cardsUpdated
                cardsSkipped += outcome.cardsSkipped
            } catch let detail as ImportErrorDetail {
                errors.append(detail)
            }
        }

        return ImportResult(
            decksInserted: decksInserted,
            decksUpdated: decksUpdated,
            cardsInserted: cardsInserted,
            cardsUpdated: cardsUpdated,
            cardsSkipped: cardsSkipped,
            errors: errors
        )
    }

    private func combineDecks(_ decks: [ImportedDeck]) -> [ImportedDeck] {
        var grouped: [UUID: ImportedDeck] = [:]
        var order: [UUID] = []

        for deck in decks {
            if var existing = grouped[deck.id] {
                existing = ImportedDeck(
                    id: existing.id,
                    parentId: existing.parentId ?? deck.parentId,
                    name: existing.name,
                    note: existing.note,
                    dueDate: existing.dueDate,
                    dueDateProvided: existing.dueDateProvided,
                    isArchived: existing.isArchived,
                    cards: existing.cards + deck.cards,
                    token: existing.token
                )
                grouped[deck.id] = existing
            } else {
                grouped[deck.id] = deck
                order.append(deck.id)
            }
        }

        return order.compactMap { grouped[$0] }
    }

    private func importDeck(
        _ deck: ImportedDeck,
        rebuildStudyPlans: Bool
    ) async throws -> (decksInserted: Int, decksUpdated: Int, cardsInserted: Int, cardsUpdated: Int, cardsSkipped: Int) {
        var decksInserted = 0
        var decksUpdated = 0
        var cardsInserted = 0
        var cardsUpdated = 0
        var cardsSkipped = 0

        let existingDeckDTO = try await storage.deck(withId: deck.id)
        var deckModel: Deck
        if let existingDeckDTO {
            deckModel = existingDeckDTO.toDomain()
            deckModel.parentId = deck.parentId
            deckModel.name = deck.name
            deckModel.note = deck.note
            if deck.dueDateProvided {
                deckModel.dueDate = deck.dueDate
            }
            deckModel.isArchived = deck.isArchived
            decksUpdated += 1
        } else {
            deckModel = Deck(
                id: deck.id,
                parentId: deck.parentId,
                name: deck.name,
                note: deck.note,
                isArchived: deck.isArchived
            )
            if deck.dueDateProvided {
                deckModel.dueDate = deck.dueDate
            }
            decksInserted += 1
        }
        try await storage.upsert(deck: deckModel.toDTO())

        for card in deck.cards {
            let outcome = try await importCard(card, deck: deckModel)
            cardsInserted += outcome.cardsInserted
            cardsUpdated += outcome.cardsUpdated
            cardsSkipped += outcome.cardsSkipped
        }

        let storedCards = try await storage.cards(deckId: deck.id)
        if let minCreated = storedCards.map(\.createdAt).min() {
            deckModel.createdAt = minCreated
        }
        if let maxUpdated = storedCards.map(\.updatedAt).max() {
            deckModel.updatedAt = maxUpdated
        }
        try await storage.upsert(deck: deckModel.toDTO())

        if rebuildStudyPlans {
            _ = await StudyPlanService(storage: storage).rebuildDeckPlan(
                forDeckId: deckModel.id,
                dueDate: deckModel.dueDate
            )
        }

        return (decksInserted, decksUpdated, cardsInserted, cardsUpdated, cardsSkipped)
    }

    private func importCard(_ card: ImportedCard, deck: Deck) async throws -> (cardsInserted: Int, cardsUpdated: Int, cardsSkipped: Int) {
        let existingDTO = try await storage.card(withId: card.id)
        let tags = card.tags
        let media = card.media.filter { $0.isFileURL || $0.scheme != nil }
        let kind = card.kind
        let importedIsSuspended = card.isSuspended
        let importedSRS = card.srs

        let prompt: String
        let answer: String
        if kind == .cloze, let source = card.clozeSource {
            prompt = ClozeRenderer.prompt(from: source)
            answer = card.back ?? existingDTO?.back ?? ""
        } else {
            prompt = card.front ?? existingDTO?.front ?? ""
            answer = card.back ?? existingDTO?.back ?? ""
        }

        let choices: [String]
        if kind == .multipleChoice {
            choices = card.choices
        } else {
            choices = []
        }

        let rawAnswerIndex = kind == .multipleChoice ? card.correctChoiceIndex : nil
        let answerIndex: Int?
        if let index = rawAnswerIndex, choices.indices.contains(index) {
            answerIndex = index
        } else {
            answerIndex = nil
        }

        if let existingDTO {
            var existing = existingDTO.toDomain()
            if existing.updatedAt >= card.updatedAt {
                return (0, 0, 1)
            }
            existing.kind = kind
            existing.front = prompt
            existing.back = answer
            existing.clozeSource = card.clozeSource
            existing.choices = choices
            existing.correctChoiceIndex = answerIndex
            existing.tags = tags
            existing.media = media
            existing.updatedAt = card.updatedAt
            existing.deckId = deck.id
            if let importedIsSuspended {
                existing.isSuspended = importedIsSuspended
                if !importedIsSuspended {
                    existing.suspendedByArchive = false
                }
            }
            if let importedSRS {
                var state = importedSRS
                state.cardId = existing.id
                existing.srs = state
            }
            try await storage.upsert(card: existing.toDTO())
            return (0, 1, 0)
        } else {
            let resolvedSuspended = importedIsSuspended ?? false
            let resolvedSRS: SRSState = {
                if let importedSRS {
                    var state = importedSRS
                    state.cardId = card.id
                    return state
                }
                return SRSState(cardId: card.id, dueDate: Date())
            }()
            let model = Card(
                id: card.id,
                deckId: deck.id,
                kind: kind,
                front: prompt,
                back: answer,
                clozeSource: card.clozeSource,
                choices: choices,
                correctChoiceIndex: answerIndex,
                tags: tags,
                media: media,
                createdAt: card.createdAt,
                updatedAt: card.updatedAt,
                isSuspended: resolvedSuspended,
                suspendedByArchive: false,
                srs: resolvedSRS
            )
            try await storage.upsert(card: model.toDTO())
            return (1, 0, 0)
        }
    }
}
