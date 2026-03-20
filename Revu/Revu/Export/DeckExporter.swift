import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum DeckExportError: Error {
    case noDecks
    case encodingFailed
}

enum DeckExportFormat: String, CaseIterable, Identifiable {
    case json
    case csv
    case markdown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .json:
            return "JSON"
        case .csv:
            return "Spreadsheet (CSV)"
        case .markdown:
            return "Markdown"
        }
    }

    var iconName: String {
        switch self {
        case .json:
            return "curlybraces"
        case .csv:
            return "tablecells"
        case .markdown:
            return "doc.text"
        }
    }

    var contentType: UTType {
        switch self {
        case .json:
            return .json
        case .csv:
            return .commaSeparatedText
        case .markdown:
            return UTType(filenameExtension: "md") ?? .plainText
        }
    }

    var fileExtension: String {
        switch self {
        case .json:
            return "json"
        case .csv:
            return "csv"
        case .markdown:
            return "md"
        }
    }

    func buttonTitle(for deckCount: Int) -> String {
        let action = switch self {
        case .json: "JSON"
        case .csv: "CSV"
        case .markdown: "Markdown"
        }
        return deckCount == 1 ? "Export as \(action)" : "Export \(deckCount) decks as \(action)"
    }
}

struct DeckExportRequest {
    let data: Data
    let format: DeckExportFormat
    let suggestedFilename: String
}

struct DeckExportDocument: FileDocument {
    static var readableContentTypes: [UTType] = DeckExportFormat.allCases.map { $0.contentType }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(request: DeckExportRequest) {
        self.data = request.data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
final class DeckExporter {
    fileprivate struct DeckBundle {
        let deck: Deck
        let deckPath: String
        let cards: [Card]
    }

    private let storage: Storage
    private let cardService: CardService
    private let jsonExporter: JSONExporter
    private let isoFormatter: ISO8601DateFormatter

    init(storage: Storage) {
        self.storage = storage
        self.cardService = CardService(storage: storage)
        self.jsonExporter = JSONExporter(storage: storage)
        self.isoFormatter = ISO8601DateFormatter()
        self.isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func makeExportRequest(for decks: [Deck], format: DeckExportFormat) async throws -> DeckExportRequest {
        guard !decks.isEmpty else { throw DeckExportError.noDecks }
        let exportDecks = await expandedExportDecks(for: decks)
        let filename = Self.filename(for: decks, format: format)

        switch format {
        case .json:
            let data = try await jsonExporter.export(decks: exportDecks)
            return DeckExportRequest(data: data, format: format, suggestedFilename: filename)
        case .csv:
            let bundles = await loadBundles(for: exportDecks)
            let csv = CSVEncoder(isoFormatter: isoFormatter).render(bundles: bundles)
            guard let data = csv.data(using: String.Encoding.utf8) else { throw DeckExportError.encodingFailed }
            return DeckExportRequest(data: data, format: format, suggestedFilename: filename)
        case .markdown:
            let bundles = await loadBundles(for: exportDecks)
            let markdown = MarkdownEncoder(isoFormatter: isoFormatter).render(bundles: bundles)
            guard let data = markdown.data(using: String.Encoding.utf8) else { throw DeckExportError.encodingFailed }
            return DeckExportRequest(data: data, format: format, suggestedFilename: filename)
        }
    }

    private func loadBundles(for decks: [Deck]) async -> [DeckBundle] {
        let hierarchy = DeckHierarchy(decks: decks)
        var bundles: [DeckBundle] = []
        for deck in decks {
            let cards = await cardService.cards(deckId: deck.id, includeSubdecks: false).sorted { $0.createdAt < $1.createdAt }
            bundles.append(DeckBundle(deck: deck, deckPath: hierarchy.displayPath(of: deck.id, separator: "::"), cards: cards))
        }
        return bundles
    }

    private func expandedExportDecks(for decks: [Deck]) async -> [Deck] {
        let allDecks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        let hierarchy = DeckHierarchy(decks: allDecks)

        var selected: Set<UUID> = []
        for deck in decks {
            selected.formUnion(hierarchy.subtreeDeckIDs(of: deck.id))
            selected.formUnion(hierarchy.ancestors(of: deck.id).map(\.id))
        }

        let settings = (try? await storage.loadSettings())?.toDomain() ?? UserSettings()
        let ordered = DeckHierarchy(decks: allDecks.filter { selected.contains($0.id) }).preorder(usingSortOrder: settings.deckSortOrder)
        return ordered
    }

    private static func filename(for decks: [Deck], format: DeckExportFormat) -> String {
        if decks.count == 1, let deck = decks.first {
            let sanitized = deck.name
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "[^a-z0-9_-]", with: "", options: .regularExpression)
            return (sanitized.isEmpty ? "deck" : sanitized) + "." + format.fileExtension
        }
        return "revu." + format.fileExtension
    }
}

private struct CSVEncoder {
    private let isoFormatter: ISO8601DateFormatter

    init(isoFormatter: ISO8601DateFormatter) {
        self.isoFormatter = isoFormatter
    }

    func render(bundles: [DeckExporter.DeckBundle]) -> String {
        let headers = [
            "deck",
            "deckId",
            "kind",
            "front",
            "back",
            "cloze",
            "prompt",
            "choices",
            "correct",
            "tags",
            "note",
            "dueDate",
            "archived",
            "media",
            "id",
            "createdAt",
            "updatedAt"
        ]

        var rows: [String] = [headers.joined(separator: ",")]
        if bundles.isEmpty {
            return rows.joined(separator: "\n")
        }

        for bundle in bundles {
            if bundle.cards.isEmpty {
                rows.append(row(for: nil, in: bundle))
            } else {
                for card in bundle.cards {
                    rows.append(row(for: card, in: bundle))
                }
            }
        }

        return rows.joined(separator: "\n")
    }

    private func row(for card: Card?, in bundle: DeckExporter.DeckBundle) -> String {
        let deckName = bundle.deckPath
        let deckId = bundle.deck.id.uuidString
        let deckNote = bundle.deck.note ?? ""
        let dueDate = bundle.deck.dueDate.map { isoFormatter.string(from: $0) } ?? ""
        let archived = bundle.deck.isArchived ? "true" : "false"

        let base: [String] = {
            if let card { return rowComponents(for: card) }
            return Array(repeating: "", count: 8)
        }()

        let columns: [String]
        if let card {
            columns = [
                deckName,
                deckId,
                card.kind.rawValue,
                base[0],
                base[1],
                base[2],
                base[3],
                base[4],
                base[5],
                base[6],
                deckNote,
                dueDate,
                archived,
                base[7],
                card.id.uuidString,
                isoFormatter.string(from: card.createdAt),
                isoFormatter.string(from: card.updatedAt)
            ]
        } else {
            columns = [
                deckName,
                deckId,
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                deckNote,
                dueDate,
                archived,
                "",
                "",
                "",
                ""
            ]
        }

        return columns.map(escape).joined(separator: ",")
    }

    private func rowComponents(for card: Card) -> [String] {
        let tags = card.tags.joined(separator: "; ")
        let media = card.media.map { $0.absoluteString }.joined(separator: "; ")
        switch card.kind {
        case .basic:
            return [
                card.front,
                card.back,
                "",
                "",
                "",
                "",
                tags,
                media
            ]
        case .cloze:
            return [
                "",
                "",
                card.clozeSource ?? card.front,
                "",
                "",
                "",
                tags,
                media
            ]
        case .multipleChoice:
            let correctIndex = card.correctChoiceIndex.map { String($0 + 1) } ?? ""
            let choices = card.choices.joined(separator: " | ")
            return [
                card.front,
                card.back,
                "",
                card.front,
                choices,
                correctIndex,
                tags,
                media
            ]
        }
    }

    private func escape(_ value: String) -> String {
        guard !value.isEmpty else { return "" }
        var needsQuotes = false
        if value.contains(where: { ",\n\r\"".contains($0) }) {
            needsQuotes = true
        }
        var escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if needsQuotes {
            escaped = "\"" + escaped + "\""
        }
        return escaped
    }
}

private struct MarkdownEncoder {
    private let isoFormatter: ISO8601DateFormatter

    init(isoFormatter: ISO8601DateFormatter) {
        self.isoFormatter = isoFormatter
    }

    func render(bundles: [DeckExporter.DeckBundle]) -> String {
        guard !bundles.isEmpty else { return "" }
        var sections: [String] = []

        for bundle in bundles {
            sections.append(deckSection(for: bundle))
            if bundle.cards.isEmpty { continue }
            for card in bundle.cards {
                sections.append(cardSection(for: card, bundle: bundle))
            }
        }

        return sections.joined(separator: "\n---\n\n")
    }

    private func deckSection(for bundle: DeckExporter.DeckBundle) -> String {
        let deck = bundle.deck
        var lines: [String] = []
        lines.append("Deck: \(bundle.deckPath)")
        lines.append("DeckId: \(deck.id.uuidString)")
        if let note = deck.note, !note.isEmpty {
            lines.append("Note: \(note)")
        }
        if let dueDate = deck.dueDate {
            lines.append("DueDate: \(isoFormatter.string(from: dueDate))")
        }
        lines.append("Archived: \(deck.isArchived ? "true" : "false")")
        lines.append("CreatedAt: \(isoFormatter.string(from: deck.createdAt))")
        lines.append("UpdatedAt: \(isoFormatter.string(from: deck.updatedAt))")
        return lines.joined(separator: "\n")
    }

    private func cardSection(for card: Card, bundle: DeckExporter.DeckBundle) -> String {
        let deck = bundle.deck
        var lines: [String] = []
        lines.append("Deck: \(bundle.deckPath)")
        lines.append("DeckId: \(deck.id.uuidString)")
        lines.append("Kind: \(card.kind.rawValue)")
        switch card.kind {
        case .basic:
            lines.append("Front: \(card.front)")
            lines.append("Back: \(card.back)")
        case .cloze:
            let cloze = card.clozeSource ?? card.front
            if !cloze.isEmpty {
                lines.append("Cloze: \(cloze)")
            }
            if !card.back.isEmpty {
                lines.append("Back: \(card.back)")
            }
        case .multipleChoice:
            lines.append("Prompt: \(card.front)")
            if !card.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("Back: \(card.back)")
            }
            if !card.choices.isEmpty {
                lines.append("Choices: \(card.choices.joined(separator: " | "))")
            }
            if let index = card.correctChoiceIndex {
                lines.append("Correct: \(index + 1)")
            }
        }
        if !card.tags.isEmpty {
            lines.append("Tags: \(card.tags.joined(separator: "; "))")
        }
        if !card.media.isEmpty {
            lines.append("Media: \(card.media.map { $0.absoluteString }.joined(separator: "; "))")
        }
        lines.append("Archived: \(deck.isArchived ? "true" : "false")")
        lines.append("Id: \(card.id.uuidString)")
        lines.append("CreatedAt: \(isoFormatter.string(from: card.createdAt))")
        lines.append("UpdatedAt: \(isoFormatter.string(from: card.updatedAt))")
        return lines.joined(separator: "\n")
    }
}
