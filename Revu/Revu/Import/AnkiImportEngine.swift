import Foundation
import Combine

enum AnkiImportEngine {
    static func loadPreviewDetails(from location: AnkiCollectionLocation) throws -> ImportPreviewDetails {
        let database = try SQLiteDatabase(readOnly: location.databaseURL)
        let collection = try loadCollectionMetadata(from: database)
        let cardCounts = try loadCardCountsByDeck(from: database)

        let decks = collection.decks.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let deckSummaries: [ImportPreview.DeckSummary] = decks.enumerated().map { index, deck in
            ImportPreview.DeckSummary(
                id: deck.id,
                name: deck.name,
                cardCount: cardCounts[deck.ankiID] ?? 0,
                token: ImportDeckToken(sourceIndex: index, originalID: deck.id)
            )
        }

        let totalCards = deckSummaries.reduce(0) { $0 + $1.cardCount }
        return ImportPreviewDetails(
            deckCount: deckSummaries.count,
            cardCount: totalCards,
            decks: deckSummaries,
            errors: []
        )
    }

    static func performImport(
        from location: AnkiCollectionLocation,
        storage: Storage,
        mergePlan: DeckMergePlan,
        options: AnkiImportOptions? = nil,
        progress: (@Sendable (AnkiImportProgress) -> Void)? = nil
    ) async throws -> ImportResult {
        let importOptions = options ?? AnkiImportOptions()
#if DEBUG
        let importStartedAt = Date()
#endif
        func runImport() async throws -> ImportResult {
            let database = try SQLiteDatabase(readOnly: location.databaseURL)
            let collection = try loadCollectionMetadata(from: database)

            let attachmentsRoot = (storage as? AttachmentDirectoryProviding)?.attachmentsDirectory
            let mediaResolver: AnkiMediaResolver? = {
                guard importOptions.includeMedia else { return nil }
                guard let sourceMediaDir = location.mediaDirectoryURL else { return nil }
                guard let attachmentsRoot else { return nil }
                let safeName = location.displayName.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "\\", with: "_")
                let namespace = "\(safeName)-\(Int(Date().timeIntervalSince1970))"
                return try? AnkiMediaResolver(
                    sourceDirectory: sourceMediaDir,
                    destinationRoot: attachmentsRoot,
                    mappingFile: location.mediaMappingURL,
                    importNamespace: namespace
                )
            }()

            let decks = collection.decks.values.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            let deckByFullName = Dictionary(uniqueKeysWithValues: decks.map { ($0.name, $0) })

            var aggregated = ImportResult(
                decksInserted: 0,
                decksUpdated: 0,
                cardsInserted: 0,
                cardsUpdated: 0,
                cardsSkipped: 0,
                errors: []
            )

            let totalDecks = decks.count
            var processedDecks = 0
            let writer = DeckImportWriter(storage: storage)
            var ensuredDecks: Set<UUID> = []

            for (index, deck) in decks.enumerated() {
                try Task.checkCancellation()

                let resolved = await ensureAnkiDeckHierarchy(
                    fullName: deck.name,
                    storage: storage,
                    deckByFullName: deckByFullName,
                    ensuredDecks: &ensuredDecks
                )

                let importedDeck = try loadImportedDeck(
                    deck: deck,
                    deckIndex: index,
                    parentId: resolved.parentId,
                    displayName: resolved.leafName,
                    collection: collection,
                    database: database,
                    mediaResolver: mediaResolver,
                    includeScheduling: importOptions.includeScheduling
                )

                let result = try await writer.importDocument(
                    ImportedDocument(decks: [importedDeck]),
                    mergePlan: mergePlan,
                    rebuildStudyPlans: !importOptions.includeScheduling
                )

                aggregated = ImportResult(
                    decksInserted: aggregated.decksInserted + result.decksInserted,
                    decksUpdated: aggregated.decksUpdated + result.decksUpdated,
                    cardsInserted: aggregated.cardsInserted + result.cardsInserted,
                    cardsUpdated: aggregated.cardsUpdated + result.cardsUpdated,
                    cardsSkipped: aggregated.cardsSkipped + result.cardsSkipped,
                    errors: aggregated.errors + result.errors
                )

                processedDecks += 1
                progress?(AnkiImportProgress(
                    phase: .importing,
                    totalDecks: totalDecks,
                    processedDecks: processedDecks
                ))
            }

            progress?(AnkiImportProgress(
                phase: .completed,
                totalDecks: totalDecks,
                processedDecks: processedDecks
            ))

            return aggregated
        }

        let result: ImportResult
        if let appStorage = storage as? LocalStore {
            result = try await appStorage.withBatchUpdates { try await runImport() }
        } else {
            result = try await runImport()
        }

#if DEBUG
        let importMs = Int(Date().timeIntervalSince(importStartedAt) * 1000)
        if importMs > 500 {
            print("Anki import took \(importMs)ms (decks +\(result.decksInserted)/~\(result.decksUpdated), cards +\(result.cardsInserted)/~\(result.cardsUpdated), skipped \(result.cardsSkipped))")
        }
#endif
        return result
    }
}

private extension AnkiImportEngine {
    struct ResolvedDeckHierarchy {
        let parentId: UUID?
        let leafName: String
    }

    static func ensureAnkiDeckHierarchy(
        fullName: String,
        storage: Storage,
        deckByFullName: [String: AnkiDeckMetadata],
        ensuredDecks: inout Set<UUID>
    ) async -> ResolvedDeckHierarchy {
        let separator = "::"
        let components = fullName
            .components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard components.count >= 2 else {
            return ResolvedDeckHierarchy(parentId: nil, leafName: fullName)
        }

        func upsertDeckIfNeeded(id: UUID, parentId: UUID?, name: String, description: String?) async {
            guard ensuredDecks.insert(id).inserted else { return }
            let note: String? = {
                guard let description else { return nil }
                let text = AnkiImportUtilities.plainText(fromHTML: description).trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : text
            }()

            let existing = (try? await storage.deck(withId: id)) ?? nil
            if var existing = existing?.toDomain() {
                let needsUpdate = existing.parentId != parentId || existing.name != name || existing.note != note
                guard needsUpdate else { return }
                existing.parentId = parentId
                existing.name = name
                existing.note = note
                existing.updatedAt = Date()
                try? await storage.upsert(deck: existing.toDTO())
                return
            }

            let deck = Deck(
                id: id,
                parentId: parentId,
                name: name,
                note: note,
                dueDate: nil,
                createdAt: Date(),
                updatedAt: Date(),
                isArchived: false
            )
            try? await storage.upsert(deck: deck.toDTO())
        }

        var currentParentId: UUID? = nil
        for depth in 0..<(components.count - 1) {
            let prefixComponents = Array(components.prefix(depth + 1))
            let prefixFullName = prefixComponents.joined(separator: separator)

            let id: UUID
            let description: String?
            if let metadata = deckByFullName[prefixFullName] {
                id = metadata.id
                description = metadata.description
            } else {
                id = StableAnkiUUID.deckPathID(prefixFullName)
                description = nil
            }

            await upsertDeckIfNeeded(
                id: id,
                parentId: currentParentId,
                name: prefixComponents.last ?? prefixFullName,
                description: description
            )

            currentParentId = id
        }

        return ResolvedDeckHierarchy(parentId: currentParentId, leafName: components.last ?? fullName)
    }
}

struct AnkiImportProgress: Sendable, Hashable {
    enum Phase: Sendable, Hashable {
        case importing
        case completed
    }

    var phase: Phase
    var totalDecks: Int
    var processedDecks: Int

    var fraction: Double {
        guard totalDecks > 0 else { return 0 }
        return min(max(Double(processedDecks) / Double(totalDecks), 0), 1)
    }
}

private struct AnkiCollectionMetadata: Sendable {
    var creationDate: Date
    var decks: [Int64: AnkiDeckMetadata]
    var models: [Int64: AnkiModelMetadata]
}

private extension AnkiImportEngine {
    static func loadCollectionMetadata(from database: SQLiteDatabase) throws -> AnkiCollectionMetadata {
        var creation = Date(timeIntervalSince1970: 0)
        var decksJSON = "{}"
        var modelsJSON = "{}"

        try database.query("SELECT crt, decks, models FROM col LIMIT 1") { row in
            let crtSeconds = row.int64(0)
            creation = Date(timeIntervalSince1970: TimeInterval(crtSeconds))
            decksJSON = row.string(1) ?? "{}"
            modelsJSON = row.string(2) ?? "{}"
        }

        let parsedDecks = try parseDecks(fromJSON: decksJSON)
        let parsedModels = try parseModels(fromJSON: modelsJSON)

        return AnkiCollectionMetadata(
            creationDate: creation,
            decks: parsedDecks,
            models: parsedModels
        )
    }

    static func loadCardCountsByDeck(from database: SQLiteDatabase) throws -> [Int64: Int] {
        var counts: [Int64: Int] = [:]
        try database.query(
            """
            SELECT
              CASE WHEN odid != 0 THEN odid ELSE did END AS homeDeck,
              COUNT(*) AS cnt
            FROM cards
            GROUP BY CASE WHEN odid != 0 THEN odid ELSE did END
            """
        ) { row in
            let deckId = row.int64(0)
            let count = row.int(1)
            counts[deckId] = count
        }
        return counts
    }

    static func parseDecks(fromJSON string: String) throws -> [Int64: AnkiDeckMetadata] {
        guard let data = string.data(using: .utf8) else { return [:] }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = object as? [String: Any] else { return [:] }

        var decks: [Int64: AnkiDeckMetadata] = [:]
        decks.reserveCapacity(root.count)

        for (key, value) in root {
            guard let deckDict = value as? [String: Any] else { continue }
            let ankiID: Int64 = {
                if let value = deckDict["id"] as? Int64 { return value }
                if let value = deckDict["id"] as? Int { return Int64(value) }
                if let value = deckDict["id"] as? Double { return Int64(value) }
                if let parsed = Int64(key) { return parsed }
                return 0
            }()
            let name = (deckDict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled Deck"
            let desc = deckDict["desc"] as? String
            let dyn = deckDict["dyn"] as? Int ?? 0
            let metadata = AnkiDeckMetadata(
                ankiID: ankiID,
                id: StableAnkiUUID.deckID(ankiID),
                name: name,
                description: desc,
                isDynamic: dyn != 0
            )
            decks[ankiID] = metadata
        }

        return decks
    }

    static func parseModels(fromJSON string: String) throws -> [Int64: AnkiModelMetadata] {
        guard let data = string.data(using: .utf8) else { return [:] }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = object as? [String: Any] else { return [:] }

        var models: [Int64: AnkiModelMetadata] = [:]
        models.reserveCapacity(root.count)

        for (key, value) in root {
            guard let modelDict = value as? [String: Any] else { continue }
            let ankiID: Int64 = {
                if let value = modelDict["id"] as? Int64 { return value }
                if let value = modelDict["id"] as? Int { return Int64(value) }
                if let value = modelDict["id"] as? Double { return Int64(value) }
                if let parsed = Int64(key) { return parsed }
                return 0
            }()
            let name = (modelDict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Model"
            let type = modelDict["type"] as? Int ?? 0
            let isCloze = type == 1

            let fieldNames: [String] = {
                guard let fields = modelDict["flds"] as? [[String: Any]] else { return [] }
                return fields.compactMap { $0["name"] as? String }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }()

            let templates: [AnkiTemplateMetadata] = {
                guard let raw = modelDict["tmpls"] as? [[String: Any]] else { return [] }
                return raw.map { tmpl in
                    AnkiTemplateMetadata(
                        name: (tmpl["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Card",
                        questionFormat: tmpl["qfmt"] as? String ?? "",
                        answerFormat: tmpl["afmt"] as? String ?? ""
                    )
                }
            }()

            let clozeFieldName: String? = {
                guard isCloze else { return nil }
                for template in templates {
                    if let name = AnkiImportUtilities.extractClozeFieldName(from: template.questionFormat) {
                        return name
                    }
                    if let name = AnkiImportUtilities.extractClozeFieldName(from: template.answerFormat) {
                        return name
                    }
                }
                return fieldNames.first
            }()

            models[ankiID] = AnkiModelMetadata(
                ankiID: ankiID,
                name: name,
                isCloze: isCloze,
                fieldNames: fieldNames,
                templates: templates,
                clozeFieldName: clozeFieldName
            )
        }

        return models
    }

    static func loadImportedDeck(
        deck: AnkiDeckMetadata,
        deckIndex: Int,
        parentId: UUID?,
        displayName: String,
        collection: AnkiCollectionMetadata,
        database: SQLiteDatabase,
        mediaResolver: AnkiMediaResolver?,
        includeScheduling: Bool
    ) throws -> ImportedDeck {
        let deckNote: String? = {
            guard let desc = deck.description else { return nil }
            let text = AnkiImportUtilities.plainText(fromHTML: desc).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }()
        let cards = try loadCards(
            forHomeDeckID: deck.ankiID,
            collection: collection,
            database: database,
            mediaResolver: mediaResolver,
            includeScheduling: includeScheduling
        )

        return ImportedDeck(
            id: deck.id,
            parentId: parentId,
            name: displayName,
            note: deckNote,
            dueDate: nil,
            dueDateProvided: false,
            isArchived: false,
            cards: cards,
            token: ImportDeckToken(sourceIndex: deckIndex, originalID: deck.id)
        )
    }

    static func loadCards(
        forHomeDeckID deckID: Int64,
        collection: AnkiCollectionMetadata,
        database: SQLiteDatabase,
        mediaResolver: AnkiMediaResolver?,
        includeScheduling: Bool
    ) throws -> [ImportedCard] {
        var cards: [ImportedCard] = []

        try database.query(
            """
            SELECT
              c.id,
              c.nid,
              CASE WHEN c.odid != 0 THEN c.odid ELSE c.did END AS homeDeck,
              c.ord,
              c.mod,
              c.type,
              c.queue,
              CASE WHEN c.odue != 0 THEN c.odue ELSE c.due END AS homeDue,
              c.ivl,
              c.factor,
              c.reps,
              c.lapses,
              n.mid,
              n.flds,
              n.tags
            FROM cards c
            JOIN notes n ON n.id = c.nid
            WHERE (CASE WHEN c.odid != 0 THEN c.odid ELSE c.did END) = ?
            """,
            bindings: [.int64(deckID)]
        ) { row in
            let ankiCardID = row.int64(0)
            let ord = row.int(3)
            let modSeconds = row.int64(4)
            let cardType = row.int(5)
            let cardQueue = row.int(6)
            let dueValue = row.int64(7)
            let intervalDays = row.int(8)
            let factorRaw = row.int(9)
            let reps = row.int(10)
            let lapses = row.int(11)
            let modelID = row.int64(12)
            let rawFields = row.string(13) ?? ""
            let rawTags = row.string(14)

            let model = collection.models[modelID]
            let tags = AnkiImportUtilities.parseTags(rawTags)

            let imported = buildImportedCard(
                ankiCardID: ankiCardID,
                model: model,
                ord: ord,
                rawFields: rawFields,
                tags: tags,
                cardType: cardType,
                cardQueue: cardQueue,
                dueValue: dueValue,
                intervalDays: intervalDays,
                factorRaw: factorRaw,
                reps: reps,
                lapses: lapses,
                modSeconds: modSeconds,
                collectionCreation: collection.creationDate,
                mediaResolver: mediaResolver,
                includeScheduling: includeScheduling
            )

            cards.append(imported)
        }

        return cards
    }

    static func buildImportedCard(
        ankiCardID: Int64,
        model: AnkiModelMetadata?,
        ord: Int,
        rawFields: String,
        tags: [String],
        cardType: Int,
        cardQueue: Int,
        dueValue: Int64,
        intervalDays: Int,
        factorRaw: Int,
        reps: Int,
        lapses: Int,
        modSeconds: Int64,
        collectionCreation: Date,
        mediaResolver: AnkiMediaResolver?,
        includeScheduling: Bool
    ) -> ImportedCard {
        let cardUUID = StableAnkiUUID.cardID(ankiCardID)
        let fields = mapFields(rawFields: rawFields, model: model)

        let createdAt = Date(timeIntervalSince1970: TimeInterval(ankiCardID) / 1000.0)
        let updatedAt = Date(timeIntervalSince1970: TimeInterval(modSeconds))

        let isCloze = model?.isCloze ?? false

        let frontHTML: String
        let backHTML: String
        let clozeSource: String?

        if isCloze {
            let clozeField = model?.clozeFieldName ?? model?.fieldNames.first ?? ""
            let clozeHTML = fields[clozeField] ?? ""
            let transformed = AnkiImportUtilities.clozeSource(
                from: AnkiImportUtilities.plainText(fromHTML: clozeHTML),
                targetIndex: max(1, ord + 1)
            )
            clozeSource = transformed

            let extras = model?.fieldNames.filter { $0 != clozeField } ?? []
            let extraHTML = extras.compactMap { fields[$0] }.filter { !$0.isEmpty }.joined(separator: "\n\n")
            frontHTML = clozeHTML
            backHTML = extraHTML
        } else {
            let template = resolveTemplate(model: model, ord: ord)
            let qHTML = AnkiImportUtilities.renderTemplate(
                template?.questionFormat ?? "",
                fields: fields,
                tags: tags
            )
            let aHTML = AnkiImportUtilities.renderTemplate(
                template?.answerFormat ?? "",
                fields: fields,
                tags: tags,
                frontSide: qHTML
            )
            frontHTML = qHTML.isEmpty ? fallbackFront(from: fields) : qHTML
            backHTML = aHTML.isEmpty ? fallbackBack(from: fields) : aHTML
            clozeSource = nil
        }

        let media: [URL] = {
            guard let mediaResolver else { return [] }
            var all: [URL] = []
            all.append(contentsOf: mediaResolver.resolveMediaURLs(from: frontHTML))
            all.append(contentsOf: mediaResolver.resolveMediaURLs(from: backHTML))
            return Array(Set(all))
        }()

        let frontText = AnkiImportUtilities.stripSoundMarkup(AnkiImportUtilities.plainText(fromHTML: frontHTML))
        let backTextRaw = AnkiImportUtilities.stripSoundMarkup(
            AnkiImportUtilities.plainText(fromHTML: AnkiImportUtilities.stripHTMLAnswerDivider(backHTML))
        )

        var resolvedBack = backTextRaw
        if !isCloze {
            let trimmedFront = frontText.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBack = resolvedBack.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedFront.isEmpty, trimmedBack.hasPrefix(trimmedFront) {
                resolvedBack = String(trimmedBack.dropFirst(trimmedFront.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let backText: String? = resolvedBack.isEmpty ? nil : resolvedBack

        let kind: Card.Kind = isCloze ? .cloze : .basic

        let srs: SRSState? = includeScheduling ? buildSRS(
            cardId: cardUUID,
            cardType: cardType,
            cardQueue: cardQueue,
            dueValue: dueValue,
            intervalDays: intervalDays,
            factorRaw: factorRaw,
            reps: reps,
            lapses: lapses,
            collectionCreation: collectionCreation
        ) : nil

        let isSuspended: Bool? = includeScheduling ? (cardQueue == -1) : nil

        return ImportedCard(
            id: cardUUID,
            kind: kind,
            front: frontText.isEmpty ? nil : frontText,
            back: backText,
            clozeSource: clozeSource,
            choices: [],
            correctChoiceIndex: nil,
            tags: tags,
            media: media,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isSuspended: isSuspended,
            srs: srs
        )
    }

    static func buildSRS(
        cardId: UUID,
        cardType: Int,
        cardQueue: Int,
        dueValue: Int64,
        intervalDays: Int,
        factorRaw: Int,
        reps: Int,
        lapses: Int,
        collectionCreation: Date
    ) -> SRSState {
        let now = Date()

        let dueDate: Date = {
            if cardQueue == 1 || cardQueue == 3 {
                return dateFromTimestamp(dueValue)
            }
            if cardType == 1 || cardType == 3 {
                return dateFromTimestamp(dueValue)
            }
            if cardQueue == 2 || cardType == 2 {
                let start = Calendar.current.startOfDay(for: collectionCreation)
                return Calendar.current.date(byAdding: .day, value: Int(dueValue), to: start) ?? now
            }
            if cardQueue == -2 || cardQueue == -3 {
                return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
            }
            return now
        }()

        let easeFactor = min(max(Double(factorRaw) / 1000.0, 1.3), 3.0)
        let interval = max(0, intervalDays)

        let queue: SRSState.Queue = {
            if cardQueue == 0 || cardType == 0 {
                return .new
            }
            if cardQueue == 1 || cardQueue == 3 || cardType == 1 {
                return .learning
            }
            if cardType == 3 {
                return .relearn
            }
            return .review
        }()

        let inferredLastReviewed: Date? = {
            guard interval > 0 else { return nil }
            let candidate = dueDate.addingTimeInterval(TimeInterval(-interval) * 86_400.0)
            if candidate > now {
                return now
            }
            return candidate
        }()

        let stability = max(0.6, Double(max(interval, 1)))
        let difficulty = min(max(11.0 - easeFactor * 2.0, 1.0), 10.0)

        return SRSState(
            cardId: cardId,
            easeFactor: easeFactor,
            interval: interval,
            repetitions: reps,
            lapses: lapses,
            dueDate: dueDate,
            lastReviewed: inferredLastReviewed,
            queue: queue,
            stability: stability,
            difficulty: difficulty,
            fsrsReps: max(reps, 0),
            lastElapsedSeconds: nil
        )
    }

    static func dateFromTimestamp(_ value: Int64) -> Date {
        if value > 2_000_000_000_000 {
            return Date(timeIntervalSince1970: TimeInterval(value) / 1000.0)
        }
        return Date(timeIntervalSince1970: TimeInterval(value))
    }

    static func resolveTemplate(model: AnkiModelMetadata?, ord: Int) -> AnkiTemplateMetadata? {
        guard let templates = model?.templates, !templates.isEmpty else { return nil }
        if templates.indices.contains(ord) {
            return templates[ord]
        }
        return templates.first
    }

    static func mapFields(rawFields: String, model: AnkiModelMetadata?) -> [String: String] {
        let values = AnkiImportUtilities.parseNoteFields(rawFields)
        guard let fieldNames = model?.fieldNames, !fieldNames.isEmpty else {
            return Dictionary(uniqueKeysWithValues: values.enumerated().map { index, value in
                ("Field \(index + 1)", value)
            })
        }

        var mapped: [String: String] = [:]
        mapped.reserveCapacity(fieldNames.count)

        for (index, name) in fieldNames.enumerated() {
            if values.indices.contains(index) {
                mapped[name] = values[index]
            } else {
                mapped[name] = ""
            }
        }
        return mapped
    }

    static func fallbackFront(from fields: [String: String]) -> String {
        if let front = fields["Front"], !front.isEmpty { return front }
        if let first = fields.values.first(where: { !$0.isEmpty }) { return first }
        return ""
    }

    static func fallbackBack(from fields: [String: String]) -> String {
        if let back = fields["Back"], !back.isEmpty { return back }
        let values = fields.values.filter { !$0.isEmpty }
        if values.count > 1 {
            return values[1]
        }
        return ""
    }
}
