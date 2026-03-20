@preconcurrency import Foundation

@MainActor
final class JSONExporter {
    private let storage: Storage
    private let cardService: CardService

    init(storage: Storage) {
        self.storage = storage
        self.cardService = CardService(storage: storage)
    }

    func export(decks: [Deck], exportedAt: Date = .init()) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonDecks: [JSONDeck] = await decks.asyncMap { deck in
            let cards = await cardService.cards(deckId: deck.id, includeSubdecks: false)
            return JSONDeck(
                id: deck.id,
                parentId: deck.parentId,
                name: deck.name,
                note: deck.note,
                dueDate: deck.dueDate,
                cards: cards.sorted { $0.createdAt < $1.createdAt }.map { card in
                    JSONCard(
                        id: card.id,
                        kind: JSONCard.Kind(rawValue: card.kind.rawValue) ?? .basic,
                        front: card.kind == .cloze ? nil : card.front,
                        back: card.kind == .cloze
                            ? (card.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : card.back)
                            : card.back,
                        clozeSource: card.clozeSource,
                        choices: card.kind == .multipleChoice ? card.choices : nil,
                        correctChoiceIndex: card.kind == .multipleChoice ? card.correctChoiceIndex : nil,
                        tags: card.tags,
                        media: card.media,
                        createdAt: card.createdAt,
                        updatedAt: card.updatedAt
                    )
                },
                isArchived: deck.isArchived
            )
        }

        let document = JSONFlashcardDocument(
            schema: JSONFlashcardDocument.expectedSchema,
            version: JSONFlashcardDocument.supportedVersions.upperBound,
            exportedAt: exportedAt,
            decks: jsonDecks
        )

        return try encoder.encode(document)
    }

    func exportAllDecks(exportedAt: Date = .init()) async throws -> Data {
        let decks = try await storage.allDecks().map { $0.toDomain() }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return try await export(decks: decks, exportedAt: exportedAt)
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)
        for element in self {
            let value = try await transform(element)
            result.append(value)
        }
        return result
    }
}
