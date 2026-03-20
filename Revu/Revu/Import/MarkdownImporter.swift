import Foundation

final class MarkdownImporter: DeckImporter {
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
        let blocks = MarkdownBlock.parse(text: text)
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
        func ensureAncestorBuilders(for components: [String], inheritedArchived: Bool) -> UUID? {
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
                        fullPath: prefixComponents.joined(separator: separator),
                        archivedState: inheritedArchived ? true : nil
                    )
                    deckOrder.append(key)
                }

                currentParentId = prefixId
            }
            return currentParentId
        }

        for (index, block) in blocks.enumerated() {
            let pathPrefix = "blocks[\(index)]"
            guard let deckName = block.value(for: ["deck"]) else {
                errors.append(ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).deck", message: "Deck is required."))
                continue
            }

            let pathComponents = normalizedDeckPathComponents(from: deckName)
            guard let leafName = pathComponents.last else {
                errors.append(ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).deck", message: "Deck is required."))
                continue
            }

            let canonicalPath = canonicalDeckPath(from: pathComponents)
            let deckKey = canonicalPath
            let explicitId = block.uuid(for: ["deckId", "deck_id"])
            let resolvedId = explicitId ?? StableUUID.deckPathID(canonicalPath)
            let inheritedArchived = block.value(for: ["archived", "isArchived"]).flatMap(parseBoolean) ?? false
            let parentId = ensureAncestorBuilders(for: pathComponents, inheritedArchived: inheritedArchived)

            var builder = deckBuilders[deckKey] ?? DeckBuilder(
                id: resolvedId,
                parentId: parentId,
                name: leafName,
                fullPath: pathComponents.joined(separator: separator),
                archivedState: inheritedArchived ? true : nil
            )

            if builder.note == nil, let note = block.value(for: ["note", "deckNote", "deck_note"]) {
                builder.note = note
            }

            if block.hasField(dueDateKeys) {
                let rawDue = block.rawValue(for: dueDateKeys)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let path = "\(pathPrefix).dueDate"
                if let rawDue, !rawDue.isEmpty {
                    if let parsed = block.date(for: dueDateKeys, formatter: isoFormatter) {
                        builder.applyDueDate(.set(parsed), lineNumber: block.startLine, path: path, errors: &errors)
                    } else {
                        let message = "Due date must use ISO-8601 format (YYYY-MM-DD)."
                        errors.append(ImportErrorDetail(line: block.startLine, path: path, message: message))
                    }
                } else {
                    builder.applyDueDate(.clear, lineNumber: block.startLine, path: path, errors: &errors)
                }
            }

            if let rawArchived = block.value(for: ["archived", "isArchived"]) {
                let path = "\(pathPrefix).archived"
                if let flag = parseBoolean(rawArchived) {
                    builder.applyArchiveFlag(flag, lineNumber: block.startLine, path: path, errors: &errors)
                } else {
                    errors.append(ImportErrorDetail(line: block.startLine, path: path, message: "Archived must be true or false."))
                }
            }

            let hasCardContent = block.hasAny(keys: ["front", "back", "cloze", "prompt", "choices"])
            if !hasCardContent {
                if deckBuilders[deckKey] == nil {
                    deckOrder.append(deckKey)
                }
                deckBuilders[deckKey] = builder
                continue
            }

            let rawKind = block.value(for: ["kind", "type"])
            let kind: Card.Kind
            if let rawKind, !rawKind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let resolvedKind = Card.Kind.importKind(from: rawKind) else {
                    errors.append(ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).kind", message: "Unknown card kind \(rawKind)"))
                    continue
                }
                kind = resolvedKind
            } else {
                kind = .basic
            }

            let cardID = block.uuid(for: ["id", "cardId", "card_id"]) ?? UUID()
            let createdAt = block.date(for: ["createdAt", "created_at"], formatter: isoFormatter) ?? Date()
            let updatedAt = block.date(for: ["updatedAt", "updated_at"], formatter: isoFormatter) ?? createdAt
            let tags = block.list(for: ["tags"]) ?? []
            let media = block.urls(for: ["media", "attachments"]) ?? []

            switch kind {
            case .basic:
                guard let front = block.value(for: ["front", "prompt", "question"]) else {
                    errors.append(ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).front", message: "Front/prompt is required for basic cards."))
                    continue
                }
                guard let back = block.value(for: ["back", "answer"]) else {
                    errors.append(ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).back", message: "Back/answer is required for basic cards."))
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
                guard let cloze = block.value(for: ["cloze", "clozeSource", "source"]) else {
                    errors.append(ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).cloze", message: "Cloze source is required for cloze cards."))
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
                guard let prompt = block.value(for: ["prompt", "front", "question"]) else {
                    errors.append(ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).prompt", message: "Prompt is required for multiple choice cards."))
                    continue
                }
                guard let rawChoices = block.value(for: ["choices", "options"]) else {
                    errors.append(ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).choices", message: "At least one choice is required."))
                    continue
                }
                let choices = parseChoices(from: rawChoices)
                if choices.isEmpty {
                    errors.append(ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).choices", message: "Choices could not be parsed."))
                    continue
                }
                guard let answerIndex = resolveAnswerIndex(block: block, choices: choices, pathPrefix: pathPrefix, errors: &errors) else {
                    continue
                }
                let back = block.value(for: ["back", "answerExplanation", "explanation"])
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

    private func resolveAnswerIndex(block: MarkdownBlock, choices: [String], pathPrefix: String, errors: inout [ImportErrorDetail]) -> Int? {
        guard let raw = block.value(for: ["correct", "answer", "solution"]) else {
            let error = ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).correct", message: "Correct answer is required for multiple choice cards.")
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
        let error = ImportErrorDetail(line: block.startLine, path: "\(pathPrefix).correct", message: "Could not match correct answer to a choice.")
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
            .flatMap { segment -> [String] in
                let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains(",") {
                    return trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                return [trimmed]
            }
            .map { value -> String in
                var value = value
                if value.hasPrefix("-") {
                    value.removeFirst()
                }
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
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

private struct MarkdownBlock {
    let fields: [String: String]
    let startLine: Int

    func value(for keys: [String]) -> String? {
        for key in keys {
            if let value = fields[key.lowercased()], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    func rawValue(for keys: [String]) -> String? {
        for key in keys {
            if let value = fields[key.lowercased()] {
                return value
            }
        }
        return nil
    }

    func hasField(_ keys: [String]) -> Bool {
        for key in keys {
            if fields[key.lowercased()] != nil {
                return true
            }
        }
        return false
    }

    func uuid(for keys: [String]) -> UUID? {
        guard let raw = value(for: keys) else { return nil }
        return UUID(uuidString: raw)
    }

    func date(for keys: [String], formatter: ISO8601DateFormatter) -> Date? {
        guard let raw = value(for: keys) else { return nil }
        return formatter.date(from: raw)
    }

    func list(for keys: [String]) -> [String]? {
        guard let raw = value(for: keys) else { return nil }
        let normalized = raw.replacingOccurrences(of: "\r", with: "")
        let separators = CharacterSet(charactersIn: ",;\n")
        var entries = normalized
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { value -> String in
                var result = value
                if result.hasPrefix("-") {
                    result.removeFirst()
                }
                return result.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        if !entries.isEmpty {
            return entries
        }
        entries = normalized
            .split(separator: "\n")
            .map { line -> String in
                var value = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if value.hasPrefix("-") {
                    value.removeFirst()
                }
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        return entries.isEmpty ? nil : entries
    }

    func urls(for keys: [String]) -> [URL]? {
        guard let raw = value(for: keys) else { return nil }
        let normalized = raw.replacingOccurrences(of: "\r", with: "")
        let parts = normalized
            .components(separatedBy: CharacterSet(charactersIn: "\n,;|"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.compactMap { URL(string: $0) }
    }

    func hasAny(keys: [String]) -> Bool {
        for key in keys {
            if let value = fields[key.lowercased()], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }
        return false
    }

    static func parse(text: String) -> [MarkdownBlock] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [MarkdownBlock] = []
        var currentLines: [String] = []
        var startLine = 1

        func flush(at lineIndex: Int) {
            if let block = MarkdownBlock.makeBlock(from: currentLines, startLine: startLine) {
                blocks.append(block)
            }
            currentLines.removeAll(keepingCapacity: true)
            startLine = lineIndex + 1
        }

        for (index, line) in lines.enumerated() {
            let content = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if content == "---" {
                flush(at: index + 1)
                continue
            }
            if currentLines.isEmpty {
                startLine = index + 1
            }
            currentLines.append(line)
        }

        flush(at: lines.count)
        return blocks
    }

    private static func makeBlock(from lines: [String], startLine: Int) -> MarkdownBlock? {
        var fields: [String: String] = [:]
        var currentKey: String?
        var currentValue: String = ""

        func commitCurrent() {
            if let key = currentKey {
                fields[key] = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            currentKey = nil
            currentValue = ""
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .newlines)
            if trimmed.trimmingCharacters(in: .whitespaces).isEmpty {
                if !currentValue.isEmpty {
                    currentValue.append("\n")
                }
                continue
            }
            if let colonIndex = line.firstIndex(of: ":"), line[..<colonIndex].trimmingCharacters(in: .whitespaces).isEmpty == false {
                commitCurrent()
                let key = line[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let remainder = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
                currentKey = key
                currentValue = remainder
            } else if currentKey != nil {
                let appended = line.trimmingCharacters(in: .whitespaces)
                if currentValue.isEmpty {
                    currentValue = appended
                } else {
                    currentValue.append("\n")
                    currentValue.append(appended)
                }
            }
        }

        commitCurrent()
        fields = fields.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if fields.isEmpty {
            return nil
        }
        return MarkdownBlock(fields: fields, startLine: startLine)
    }
}
