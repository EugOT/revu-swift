@preconcurrency import Foundation

final class JSONImporter: DeckImporter {
    private let storage: Storage
    private let writer: DeckImportWriter

    init(storage: Storage) {
        self.storage = storage
        self.writer = DeckImportWriter(storage: storage)
    }

    func loadPreview(from source: ImportSource) async throws -> ImportPreviewDetails {
        let decoded = try decodeDocument(from: source.data)
        let errors = validate(document: decoded, sourceData: source.data)
        let deckLookup = Dictionary(uniqueKeysWithValues: decoded.decks.map { ($0.id, $0) })

        func fullPath(for deck: JSONDeck) -> String {
            var components: [String] = [deck.name]
            var current = deck.parentId
            var seen: Set<UUID> = [deck.id]
            while let id = current, let parent = deckLookup[id], seen.insert(id).inserted {
                components.append(parent.name)
                current = parent.parentId
            }
            return components.reversed().joined(separator: "::")
        }

        let deckSummaries = decoded.decks.enumerated().map { index, deck in
            ImportPreview.DeckSummary(
                id: deck.id,
                name: fullPath(for: deck),
                cardCount: deck.cards.count,
                token: ImportDeckToken(sourceIndex: index, originalID: deck.id)
            )
        }
        return ImportPreviewDetails(
            deckCount: decoded.decks.count,
            cardCount: decoded.decks.reduce(0) { $0 + $1.cards.count },
            decks: deckSummaries,
            errors: errors
        )
    }

    func performImport(from source: ImportSource, mergePlan: DeckMergePlan) async throws -> ImportResult {
        let document = try decodeDocument(from: source.data)
        let validationErrors = validate(document: document, sourceData: source.data)
        let normalized = convert(document: document)
        let result = try await writer.importDocument(normalized, mergePlan: mergePlan)
        return ImportResult(
            decksInserted: result.decksInserted,
            decksUpdated: result.decksUpdated,
            cardsInserted: result.cardsInserted,
            cardsUpdated: result.cardsUpdated,
            cardsSkipped: result.cardsSkipped,
            errors: validationErrors + result.errors
        )
    }

    private func decodeDocument(from data: Data) throws -> JSONFlashcardDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(JSONFlashcardDocument.self, from: data)
        guard document.schema == JSONFlashcardDocument.expectedSchema else {
            throw ImportErrorDetail(line: nil, path: "schema", message: "Unexpected schema \(document.schema)")
        }
        guard JSONFlashcardDocument.supportedVersions.contains(document.version) else {
            throw ImportErrorDetail(line: nil, path: "version", message: "Unsupported schema version \(document.version)")
        }
        return document
    }

    private func validate(document: JSONFlashcardDocument, sourceData: Data) -> [ImportErrorDetail] {
        var issues: [ImportErrorDetail] = []
        let lineLookup = JSONLineLookup(data: sourceData)

        for (deckIndex, deck) in document.decks.enumerated() {
            if deck.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let line = lineLookup.line(matching: deck.id.uuidString) ?? lineLookup.line(forKeyPath: ["decks", "\(deckIndex)", "name"])
                issues.append(ImportErrorDetail(line: line, path: "decks[\(deckIndex)].name", message: "Deck name is required."))
            }
            for (cardIndex, card) in deck.cards.enumerated() {
                issues.append(contentsOf: validate(card: card, deckIndex: deckIndex, cardIndex: cardIndex, lineLookup: lineLookup))
            }
        }
        return issues
    }

    private func validate(card: JSONCard, deckIndex: Int, cardIndex: Int, lineLookup: JSONLineLookup) -> [ImportErrorDetail] {
        var issues: [ImportErrorDetail] = []
        let pathPrefix = "decks[\(deckIndex)].cards[\(cardIndex)]"
        if card.kind == .basic {
            if (card.front ?? "").isEmpty {
                let line = lineLookup.line(matching: card.id.uuidString) ?? lineLookup.line(forKeyPath: [pathPrefix, "front"])
                issues.append(ImportErrorDetail(line: line, path: "\(pathPrefix).front", message: "Front is required for basic cards."))
            }
            if (card.back ?? "").isEmpty {
                let line = lineLookup.line(matching: card.id.uuidString) ?? lineLookup.line(forKeyPath: [pathPrefix, "back"])
                issues.append(ImportErrorDetail(line: line, path: "\(pathPrefix).back", message: "Back is required for basic cards."))
            }
        }
        if card.kind == .cloze {
            if (card.clozeSource ?? "").isEmpty {
                let line = lineLookup.line(matching: card.id.uuidString) ?? lineLookup.line(forKeyPath: [pathPrefix, "clozeSource"])
                issues.append(ImportErrorDetail(line: line, path: "\(pathPrefix).clozeSource", message: "clozeSource is required for cloze cards."))
            }
        }
        return issues
    }

    private func convert(document: JSONFlashcardDocument) -> ImportedDocument {
        let decks = document.decks.enumerated().map { index, deck -> ImportedDeck in
            let cards = deck.cards.map { card -> ImportedCard in
                let kind = Card.Kind(rawValue: card.kind.rawValue) ?? .basic
                let media = (card.media ?? []).filter { $0.isFileURL || $0.scheme != nil }
                return ImportedCard(
                    id: card.id,
                    kind: kind,
                    front: card.front,
                    back: card.back,
                    clozeSource: card.clozeSource,
                    choices: card.choices ?? [],
                    correctChoiceIndex: card.correctChoiceIndex,
                    tags: card.tags ?? [],
                    media: media,
                    createdAt: card.createdAt,
                    updatedAt: card.updatedAt,
                    isSuspended: nil,
                    srs: nil
                )
            }
            return ImportedDeck(
                id: deck.id,
                parentId: deck.parentId,
                name: deck.name,
                note: deck.note,
                dueDate: deck.dueDateProvided ? deck.dueDate : nil,
                dueDateProvided: deck.dueDateProvided,
                isArchived: deck.isArchived,
                cards: cards,
                token: ImportDeckToken(sourceIndex: index, originalID: deck.id)
            )
        }
        return ImportedDocument(decks: decks)
    }
}

private struct JSONLineLookup {
    private let lines: [Substring]

    init(data: Data) {
        let string = String(data: data, encoding: .utf8) ?? ""
        self.lines = string.split(separator: "\n", omittingEmptySubsequences: false)
    }

    func line(matching needle: String) -> Int? {
        guard !needle.isEmpty else { return nil }
        for (index, line) in lines.enumerated() where line.contains(needle) {
            return index + 1
        }
        return nil
    }

    func line(forKeyPath path: [String]) -> Int? {
        guard let last = path.last else { return nil }
        return line(matching: "\"\(last)\"")
    }
}
