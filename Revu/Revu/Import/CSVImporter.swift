import Foundation

final class CSVImporter: DeckImporter {
    private let storage: Storage
    private let writer: DeckImportWriter
    private let isoFormatter = ISO8601DateFormatter()

    init(storage: Storage) {
        self.storage = storage
        self.writer = DeckImportWriter(storage: storage)
    }

    func loadPreview(from source: ImportSource) async throws -> ImportPreviewDetails {
        let (document, errors) = try parseDocument(from: source)
        let deckLookup = Dictionary(uniqueKeysWithValues: document.decks.map { ($0.id, $0) })

        func fullPath(for deck: ImportedDeck) -> String {
            var components: [String] = [deck.name]
            var current = deck.parentId
            var seen: Set<UUID> = [deck.id]
            while let id = current, let parent = deckLookup[id], seen.insert(id).inserted {
                components.append(parent.name)
                current = parent.parentId
            }
            return components.reversed().joined(separator: "::")
        }

        let deckSummaries = document.decks.map { deck in
            ImportPreview.DeckSummary(
                id: deck.id,
                name: fullPath(for: deck),
                cardCount: deck.cards.count,
                token: deck.token
            )
        }
        let cardCount = document.decks.reduce(0) { $0 + $1.cards.count }
        return ImportPreviewDetails(
            deckCount: document.decks.count,
            cardCount: cardCount,
            decks: deckSummaries,
            errors: errors
        )
    }

    func performImport(from source: ImportSource, mergePlan: DeckMergePlan) async throws -> ImportResult {
        let (document, errors) = try parseDocument(from: source)
        let result = try await writer.importDocument(document, mergePlan: mergePlan)
        return ImportResult(
            decksInserted: result.decksInserted,
            decksUpdated: result.decksUpdated,
            cardsInserted: result.cardsInserted,
            cardsUpdated: result.cardsUpdated,
            cardsSkipped: result.cardsSkipped,
            errors: errors + result.errors
        )
    }

    private func parseBoolean(_ raw: String) -> Bool? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "true", "yes", "y", "1":
            return true
        case "false", "no", "n", "0":
            return false
        default:
            return nil
        }
    }

    private func parseDocument(from source: ImportSource) throws -> (ImportedDocument, [ImportErrorDetail]) {
        guard let text = String(data: source.data, encoding: .utf8) else {
            throw ImportErrorDetail(line: nil, path: "encoding", message: "File is not valid UTF-8")
        }
        let delimiter: Character = text.contains("\t") && !text.contains(",\t") ? "\t" : ","
        let table = try CSVTable(text: text, delimiter: delimiter)
        var errors: [ImportErrorDetail] = []

        var deckBuilders: [String: DeckBuilder] = [:]
        var deckOrder: [String] = []
        let dueDateKeys = ["duedate", "due_date", "deadline", "due"]
        let separator = "::"

        func normalizedDeckPathComponents(from raw: String) -> [String] {
            raw
                .components(separatedBy: separator)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        func canonicalDeckPath(from components: [String]) -> String {
            components.joined(separator: separator).lowercased()
        }

        @discardableResult
        func ensureAncestorBuilders(for components: [String]) -> UUID? {
            guard components.count > 1 else { return nil }
            var currentParentId: UUID? = nil
            for depth in 0..<(components.count - 1) {
                let prefixComponents = Array(components.prefix(depth + 1))
                let prefixName = prefixComponents.last ?? ""
                let canonicalPrefix = canonicalDeckPath(from: prefixComponents)
                let prefixId = StableUUID.deckPathID(canonicalPrefix)
                let key = canonicalPrefix

                if deckBuilders[key] == nil {
                    deckBuilders[key] = DeckBuilder(
                        id: prefixId,
                        parentId: currentParentId,
                        name: prefixName,
                        fullPath: prefixComponents.joined(separator: separator)
                    )
                    deckOrder.append(key)
                }

                currentParentId = prefixId
            }
            return currentParentId
        }

        for (index, row) in table.rows.enumerated() {
            let lineNumber = index + 2 // header is line 1
            let accessor = RowAccessor(headers: table.headers, row: row, isoFormatter: isoFormatter)
            guard let deckName = accessor.value(for: ["deck"]) else {
                errors.append(ImportErrorDetail(line: lineNumber, path: "row[\(index)]", message: "Deck is required."))
                continue
            }

            let pathComponents = normalizedDeckPathComponents(from: deckName)
            guard let leafName = pathComponents.last else {
                errors.append(ImportErrorDetail(line: lineNumber, path: "row[\(index)].deck", message: "Deck is required."))
                continue
            }

            let canonicalPath = canonicalDeckPath(from: pathComponents)
            let deckKey = canonicalPath
            let explicitId = accessor.uuid(for: ["deckId", "deck_id"])
            let resolvedId = explicitId ?? StableUUID.deckPathID(canonicalPath)
            let parentId = ensureAncestorBuilders(for: pathComponents)

            var builder = deckBuilders[deckKey] ?? DeckBuilder(
                id: resolvedId,
                parentId: parentId,
                name: leafName,
                fullPath: pathComponents.joined(separator: separator)
            )
            if builder.note == nil, let note = accessor.value(for: ["note", "deckNote", "deck_note"]) {
                builder.note = note
            }

            if accessor.fieldExists(for: dueDateKeys) {
                let rawDue = accessor.rawValue(for: dueDateKeys)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let path = "row[\(index)].dueDate"
                if let rawDue, !rawDue.isEmpty {
                    if let parsed = accessor.date(for: dueDateKeys) {
                        builder.applyDueDate(.set(parsed), lineNumber: lineNumber, path: path, errors: &errors)
                    } else {
                        let message = "Due date must use ISO-8601 format (YYYY-MM-DD)."
                        errors.append(ImportErrorDetail(line: lineNumber, path: path, message: message))
                    }
                } else {
                    builder.applyDueDate(.clear, lineNumber: lineNumber, path: path, errors: &errors)
                }
            }

            if let rawArchived = accessor.value(for: ["archived", "isArchived"]) {
                let path = "row[\(index)].archived"
                if let flag = parseBoolean(rawArchived) {
                    builder.applyArchiveFlag(flag, lineNumber: lineNumber, path: path, errors: &errors)
                } else {
                    errors.append(ImportErrorDetail(line: lineNumber, path: path, message: "Archived must be true or false."))
                }
            }

            let cardID = accessor.uuid(for: ["id", "cardId", "card_id"]) ?? UUID()
            let rawKind = accessor.value(for: ["kind", "type"])
            let kind: Card.Kind
            if let rawKind, !rawKind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let resolvedKind = Card.Kind.importKind(from: rawKind) else {
                    errors.append(ImportErrorDetail(line: lineNumber, path: "row[\(index)].kind", message: "Unknown card kind \(rawKind)"))
                    continue
                }
                kind = resolvedKind
            } else {
                kind = .basic
            }

            let createdAt = accessor.date(for: ["createdAt", "created_at"]) ?? Date()
            let updatedAt = accessor.date(for: ["updatedAt", "updated_at"]) ?? createdAt
            let tags = accessor.list(for: ["tags"]) ?? []
            let media = accessor.urls(for: ["media", "attachments"]) ?? []

            switch kind {
            case .basic:
                guard let front = accessor.value(for: ["front", "prompt", "question"]) else {
                    errors.append(ImportErrorDetail(line: lineNumber, path: "row[\(index)].front", message: "Front/prompt is required for basic cards."))
                    continue
                }
                guard let back = accessor.value(for: ["back", "answer"]) else {
                    errors.append(ImportErrorDetail(line: lineNumber, path: "row[\(index)].back", message: "Back/answer is required for basic cards."))
                    continue
                }
                let card = ImportedCard(
                    id: cardID,
                    kind: kind,
                    front: front,
                    back: back,
                    clozeSource: nil,
                    choices: [],
                    correctChoiceIndex: nil,
                    tags: tags,
                    media: media,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    isSuspended: nil,
                    srs: nil
                )
                builder.cards.append(card)
            case .cloze:
                guard let cloze = accessor.value(for: ["cloze", "clozeSource", "source"]) else {
                    errors.append(ImportErrorDetail(line: lineNumber, path: "row[\(index)].cloze", message: "Cloze source is required for cloze cards."))
                    continue
                }
                let card = ImportedCard(
                    id: cardID,
                    kind: kind,
                    front: nil,
                    back: nil,
                    clozeSource: cloze,
                    choices: [],
                    correctChoiceIndex: nil,
                    tags: tags,
                    media: media,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    isSuspended: nil,
                    srs: nil
                )
                builder.cards.append(card)
            case .multipleChoice:
                guard let prompt = accessor.value(for: ["prompt", "front", "question"]) else {
                    errors.append(ImportErrorDetail(line: lineNumber, path: "row[\(index)].prompt", message: "Prompt is required for multiple choice cards."))
                    continue
                }
                guard let rawChoices = accessor.value(for: ["choices", "options"]) else {
                    errors.append(ImportErrorDetail(line: lineNumber, path: "row[\(index)].choices", message: "At least one choice is required."))
                    continue
                }
                let choices = parseChoices(from: rawChoices)
                if choices.isEmpty {
                    errors.append(ImportErrorDetail(line: lineNumber, path: "row[\(index)].choices", message: "Choices could not be parsed."))
                    continue
                }
                guard let answerIndex = resolveAnswerIndex(accessor: accessor, choices: choices, rowIndex: index, lineNumber: lineNumber, errors: &errors) else {
                    continue
                }
                let back = accessor.value(for: ["back", "answerExplanation", "explanation"])
                let card = ImportedCard(
                    id: cardID,
                    kind: kind,
                    front: prompt,
                    back: back,
                    clozeSource: nil,
                    choices: choices,
                    correctChoiceIndex: answerIndex,
                    tags: tags,
                    media: media,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    isSuspended: nil,
                    srs: nil
                )
                builder.cards.append(card)
            }

            if deckBuilders[deckKey] == nil {
                deckOrder.append(deckKey)
            }
            deckBuilders[deckKey] = builder
        }

        let decks = deckOrder.enumerated().compactMap { index, key -> ImportedDeck? in
            guard let builder = deckBuilders[key] else { return nil }
            let dueDetails = builder.importedDueDate
            return ImportedDeck(
                id: builder.id,
                parentId: builder.parentId,
                name: builder.name,
                note: builder.note,
                dueDate: dueDetails.0,
                dueDateProvided: dueDetails.1,
                isArchived: builder.isArchived,
                cards: builder.cards,
                token: ImportDeckToken(sourceIndex: index, originalID: builder.id)
            )
        }

        return (ImportedDocument(decks: decks), errors)
    }

    private func resolveAnswerIndex(accessor: RowAccessor, choices: [String], rowIndex: Int, lineNumber: Int, errors: inout [ImportErrorDetail]) -> Int? {
        guard let raw = accessor.value(for: ["correct", "answer", "solution"]) else {
            let message = "Correct answer is required for multiple choice cards."
            let error = ImportErrorDetail(line: lineNumber, path: "row[\(rowIndex)].correct", message: message)
            errors.append(error)
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let indexValue = Int(trimmed), indexValue > 0, indexValue <= choices.count {
            return indexValue - 1
        }
        if let matchIndex = choices.firstIndex(where: { $0.compare(trimmed, options: .caseInsensitive) == .orderedSame }) {
            return matchIndex
        }
        let error = ImportErrorDetail(line: lineNumber, path: "row[\(rowIndex)].correct", message: "Could not match correct answer to a choice.")
        errors.append(error)
        return nil
    }

    private func parseChoices(from raw: String) -> [String] {
        let normalized = raw
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "|", with: "\n")
            .replacingOccurrences(of: ";", with: "\n")
        return normalized
            .split(separator: "\n")
            .map { entry -> String in
                var value = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                if value.hasPrefix("-") {
                    value.removeFirst()
                }
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }
}

private struct CSVTable {
    let headers: [String]
    let rows: [[String]]

    init(text: String, delimiter: Character) throws {
        // Normalize common line endings up front so the parser can treat every newline the same,
        // regardless of whether the source came from Windows (CRLF) or Unix/macOS (LF).
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var iterator = normalizedText.makeIterator()
        var inQuotes = false

        while let character = iterator.next() {
            switch character {
            case "\"":
                if inQuotes {
                    if let peek = iterator.peek(), peek == "\"" {
                        _ = iterator.next()
                        currentField.append("\"")
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            case delimiter where !inQuotes:
                currentRow.append(currentField)
                currentField = ""
            case "\n" where !inQuotes:
                currentRow.append(currentField)
                rows.append(currentRow)
                currentRow = []
                currentField = ""
            default:
                currentField.append(character)
            }
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        rows = rows.filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        guard var headerRow = rows.first else {
            throw ImportErrorDetail(line: nil, path: "csv", message: "CSV file is empty")
        }

        if var firstHeader = headerRow.first, firstHeader.hasPrefix("\u{feff}") {
            firstHeader.removeFirst()
            headerRow[0] = firstHeader
        }

        self.headers = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        self.rows = rows.dropFirst().map { row in
            if row.count < headerRow.count {
                return row + Array(repeating: "", count: headerRow.count - row.count)
            } else if row.count > headerRow.count {
                return Array(row.prefix(headerRow.count))
            }
            return row
        }
    }
}

private struct DeckBuilder {
    let id: UUID
    let parentId: UUID?
    let name: String
    let fullPath: String
    var note: String? = nil
    var dueDateState: DeckDueDateState = .unspecified
    var archivedState: Bool?
    var cards: [ImportedCard] = []

    mutating func applyDueDate(_ newState: DeckDueDateState, lineNumber: Int?, path: String, errors: inout [ImportErrorDetail]) {
        guard newState != .unspecified else { return }
        if dueDateState == .unspecified || dueDateState == newState {
            dueDateState = newState
        } else {
            let message = "Conflicting due date values for deck \(name)."
            errors.append(ImportErrorDetail(line: lineNumber, path: path, message: message))
        }
    }

    mutating func applyArchiveFlag(_ newValue: Bool, lineNumber: Int?, path: String, errors: inout [ImportErrorDetail]) {
        if let archivedState, archivedState != newValue {
            let message = "Conflicting archive state values for deck \(name)."
            errors.append(ImportErrorDetail(line: lineNumber, path: path, message: message))
            return
        }
        archivedState = newValue
    }

    var importedDueDate: (Date?, Bool) {
        switch dueDateState {
        case .unspecified:
            return (nil, false)
        case .clear:
            return (nil, true)
        case .set(let date):
            return (date, true)
        }
    }

    var isArchived: Bool {
        archivedState ?? false
    }
}

private enum DeckDueDateState: Equatable {
    case unspecified
    case set(Date)
    case clear
}

private struct RowAccessor {
    private let headers: [String: Int]
    private let row: [String]
    private let isoFormatter: ISO8601DateFormatter

    init(headers: [String], row: [String], isoFormatter: ISO8601DateFormatter) {
        var map: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            map[header] = index
        }
        self.headers = map
        self.row = row
        self.isoFormatter = isoFormatter
    }

    func fieldExists(for keys: [String]) -> Bool {
        for key in keys {
            if headers[key.lowercased()] != nil {
                return true
            }
        }
        return false
    }

    func rawValue(for keys: [String]) -> String? {
        for key in keys {
            if let index = headers[key.lowercased()], index < row.count {
                return row[index]
            }
        }
        return nil
    }

    func value(for keys: [String]) -> String? {
        for key in keys {
            if let index = headers[key.lowercased()], index < row.count {
                let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    func uuid(for keys: [String]) -> UUID? {
        guard let raw = value(for: keys) else { return nil }
        return UUID(uuidString: raw)
    }

    func date(for keys: [String]) -> Date? {
        guard let raw = value(for: keys) else { return nil }
        if let date = isoFormatter.date(from: raw) {
            return date
        }
        return nil
    }

    func list(for keys: [String]) -> [String]? {
        guard let raw = value(for: keys) else { return nil }
        let separators = CharacterSet(charactersIn: ",;|\n")
        return raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func urls(for keys: [String]) -> [URL]? {
        guard let raw = value(for: keys) else { return nil }
        let parts = raw
            .replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: CharacterSet(charactersIn: "\n,;|"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.compactMap { URL(string: $0) }
    }
}

private extension IteratorProtocol where Element == Character {
    mutating func peek() -> Character? {
        var copy = self
        return copy.next()
    }
}
