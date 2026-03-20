import Foundation

// MARK: - Public Snapshots

struct SessionCuratorSnapshot: Equatable, Sendable {
    struct QueuePreview: Identifiable, Equatable, Sendable {
        enum Emphasis: String, Sendable {
            case focus
            case contrast
            case reinforce
        }

        let id: UUID
        let concept: String
        let companionConcept: String?
        let prompt: String
        let predictedRecall: Double
        let dueInHours: Double
        let emphasis: Emphasis
    }

    struct ConceptWeave: Identifiable, Equatable, Sendable {
        enum Strategy: String, Sendable {
            case contrast
            case reinforce
            case expand
        }

        let id: UUID
        let primaryConcept: String
        let supportingConcepts: [String]
        let contribution: Double
        let dueCount: Int
        let strategy: Strategy
    }

    struct Insight: Identifiable, Equatable, Sendable {
        let id: UUID
        let title: String
        let detail: String
        let symbol: String
    }

    let generatedAt: Date
    let totalDue: Int
    let conceptCoverage: Int
    let interleavingScore: Double
    let queuePreview: [QueuePreview]
    let conceptWeaves: [ConceptWeave]
    let insights: [Insight]

    static let empty = SessionCuratorSnapshot(
        generatedAt: Date(),
        totalDue: 0,
        conceptCoverage: 0,
        interleavingScore: 0,
        queuePreview: [],
        conceptWeaves: [],
        insights: []
    )
}

struct AdaptiveNavigatorSnapshot: Equatable, Sendable {
    enum Energy: String, CaseIterable, Sendable {
        case focus
        case calibrate
        case accelerate
    }

    enum ConceptKind: String, Sendable {
        case deck
        case concept
    }

    struct JourneyStep: Identifiable, Equatable, Sendable {
        let id: UUID
        let title: String
        let detail: String
        let symbol: String
        let energy: Energy
    }

    struct ConceptNode: Identifiable, Equatable, Sendable {
        let id: String
        let deckId: UUID?
        let name: String
        let kind: ConceptKind
        let mastery: Double
        let due: Int
        let new: Int
        let connections: [String]
        let energy: Energy
    }

    let generatedAt: Date
    let averageMastery: Double
    let totalDue: Int
    let totalConcepts: Int
    let focusConcepts: Int
    let accelerateConcepts: Int
    let journey: [JourneyStep]
    let deckNodes: [ConceptNode]
    let conceptNodes: [ConceptNode]

    static let empty = AdaptiveNavigatorSnapshot(
        generatedAt: Date(),
        averageMastery: 0,
        totalDue: 0,
        totalConcepts: 0,
        focusConcepts: 0,
        accelerateConcepts: 0,
        journey: [],
        deckNodes: [],
        conceptNodes: []
    )
}

// MARK: - Service

struct LearningIntelligenceService {
    private let storage: Storage
    private let deckService: DeckService
    private let cardService: CardService
    private let conceptTracer: ConceptTracerService

    init(storage: Storage) {
        self.storage = storage
        self.deckService = DeckService(storage: storage)
        self.cardService = CardService(storage: storage)
        self.conceptTracer = ConceptTracerService(storage: storage)
    }

    init() {
        self.init(storage: DataController.shared.storage)
    }

    func sessionCuratorSnapshot(for date: Date = Date()) async -> SessionCuratorSnapshot {
        let data = await loadWorkspaceState()
        return buildSessionSnapshot(from: data, for: date)
    }

    func adaptiveNavigatorSnapshot(for date: Date = Date()) async -> AdaptiveNavigatorSnapshot {
        let data = await loadWorkspaceState()
        return await buildNavigatorSnapshot(from: data, for: date)
    }

    func combinedSnapshots(for date: Date = Date()) async -> (SessionCuratorSnapshot, AdaptiveNavigatorSnapshot) {
        let data = await loadWorkspaceState()
        return (
            buildSessionSnapshot(from: data, for: date),
            await buildNavigatorSnapshot(from: data, for: date)
        )
    }

    func snapshots(
        decks: [Deck],
        cards: [Card],
        settings: UserSettings,
        date: Date = Date()
    ) async -> (SessionCuratorSnapshot, AdaptiveNavigatorSnapshot) {
        let state = WorkspaceState(decks: decks, cards: cards, settings: settings)
        return (
            buildSessionSnapshot(from: state, for: date),
            await buildNavigatorSnapshot(from: state, for: date)
        )
    }

    // MARK: - Workspace Snapshot

    private struct WorkspaceState {
        let decks: [Deck]
        let cards: [Card]
        let settings: UserSettings
    }

    private func loadWorkspaceState() async -> WorkspaceState {
        async let decksTask = deckService.allDecks(includeArchived: false)
        async let cardsTask = cardService.allCards()
        async let settingsTask = storage.loadSettings()

        let decks = await decksTask.filter { !$0.isArchived }
        let activeDeckIds = Set(decks.map(\.id))
        let cards = await cardsTask.filter { card in
            guard let deckId = card.deckId else { return true }
            return activeDeckIds.contains(deckId)
        }
        let settingsDTO = try? await settingsTask
        let settings = settingsDTO?.toDomain() ?? UserSettings()

        return WorkspaceState(decks: decks, cards: cards, settings: settings)
    }

    // MARK: - Session Curator

    private struct ConceptPair: Hashable {
        let a: String
        let b: String

        init(_ values: [String]) {
            if values.count == 2 {
                if values[0] < values[1] {
                    self.a = values[0]
                    self.b = values[1]
                } else {
                    self.a = values[1]
                    self.b = values[0]
                }
            } else {
                self.a = values.first ?? ""
                self.b = values.last ?? ""
            }
        }
    }

    private func buildSessionSnapshot(from data: WorkspaceState, for date: Date) -> SessionCuratorSnapshot {
        guard !data.cards.isEmpty else { return .empty }

        let deckLookup = Dictionary(uniqueKeysWithValues: data.decks.map { ($0.id, $0) })
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let retentionTarget = dataSafeRetention(from: data.settings)
        let dueHorizon = calendar.date(byAdding: .day, value: 7, to: startOfDay) ?? startOfDay

        let dueCards = data.cards.filter { card in
            guard !card.isSuspended else { return false }
            if card.srs.dueDate < tomorrow {
                return true
            }
            guard let deckId = card.deckId, let deck = deckLookup[deckId], let deckDue = deck.dueDate else {
                return false
            }
            let isCriticalDeck = deckDue <= dueHorizon || deckDue <= tomorrow
            guard isCriticalDeck else { return false }
            if card.srs.queue == .new || card.srs.fsrsReps == 0 {
                return true
            }
            if card.srs.dueDate <= deckDue {
                return true
            }
            let projectedRecall = card.srs.predictedRecall(on: deckDue, retentionTarget: retentionTarget)
            return projectedRecall < 0.82
        }

        let newCards = plannedNewCards(
            decks: data.decks,
            cards: data.cards,
            settings: data.settings,
            date: date
        )
        let totalQueueCount = mergedQueueCount(dueCards: dueCards, newCards: newCards)

        guard totalQueueCount > 0 else {
            return SessionCuratorSnapshot(
                generatedAt: date,
                totalDue: 0,
                conceptCoverage: 0,
                interleavingScore: 0,
                queuePreview: [],
                conceptWeaves: [],
                insights: []
            )
        }

        var conceptBuckets: [String: [Card]] = [:]
        var pairCounts: [ConceptPair: Int] = [:]
        var multiConceptCards = 0

        for card in dueCards {
            let concepts = normalizedConcepts(for: card, deckLookup: deckLookup)
            if concepts.count > 1 { multiConceptCards += 1 }
            for concept in concepts {
                conceptBuckets[concept, default: []].append(card)
            }
            let uniqueConcepts = Array(Set(concepts)).sorted()
            if uniqueConcepts.count >= 2 {
                for index in 0..<(uniqueConcepts.count - 1) {
                    for inner in (index + 1)..<uniqueConcepts.count {
                        let pair = ConceptPair([uniqueConcepts[index], uniqueConcepts[inner]])
                        pairCounts[pair, default: 0] += 1
                    }
                }
            }
        }

        let queuePreview = buildQueuePreview(
            from: conceptBuckets,
            deckLookup: deckLookup,
            settings: data.settings,
            dueHorizon: dueHorizon,
            asOf: date
        )

        let interleavingScore = calculateInterleavingScore(
            queuePreview: queuePreview,
            conceptBuckets: conceptBuckets,
            multiConceptCards: multiConceptCards,
            totalDue: dueCards.count
        )

        let conceptWeaves = buildConceptWeaves(
            buckets: conceptBuckets,
            pairCounts: pairCounts,
            totalDue: dueCards.count
        )

        let insights = buildSessionInsights(
            dueCards: dueCards,
            deckLookup: deckLookup,
            dueHorizon: dueHorizon,
            conceptWeaves: conceptWeaves,
            interleavingScore: interleavingScore,
            settings: data.settings,
            asOf: date
        )

        return SessionCuratorSnapshot(
            generatedAt: date,
            totalDue: totalQueueCount,
            conceptCoverage: conceptBuckets.keys.count,
            interleavingScore: interleavingScore,
            queuePreview: queuePreview,
            conceptWeaves: conceptWeaves,
            insights: insights
        )
    }

    private func mergedQueueCount(dueCards: [Card], newCards: [Card]) -> Int {
        var ids = Set<UUID>()
        ids.formUnion(dueCards.map(\.id))
        ids.formUnion(newCards.map(\.id))
        return ids.count
    }

    private func plannedNewCards(
        decks: [Deck],
        cards: [Card],
        settings: UserSettings,
        date: Date
    ) -> [Card] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let cutoff = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let dueDateDecks = decks.filter { $0.dueDate != nil }
        let deckLookup = Dictionary(uniqueKeysWithValues: decks.map { ($0.id, $0) })
        let dueDeckLookup = Dictionary(uniqueKeysWithValues: dueDateDecks.map { ($0.id, $0) })
        let dueDeckIDs = Set(dueDateDecks.map(\.id))

        var planned: [Card] = []

        if !dueDateDecks.isEmpty {
            let dueDriven = cards.compactMap { card -> Card? in
                guard let deckId = card.deckId, let deck = dueDeckLookup[deckId] else { return nil }
                guard !card.isSuspended else { return nil }
                let state = card.srs
                guard state.queue == .new && state.fsrsReps == 0 else { return nil }
                let threshold = dueDateThreshold(for: deck, cutoff: cutoff, now: date)
                return state.dueDate <= threshold ? card : nil
            }.sorted { lhs, rhs in
                if lhs.srs.dueDate == rhs.srs.dueDate {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.srs.dueDate < rhs.srs.dueDate
            }
            planned.append(contentsOf: dueDriven)
        }

        if settings.dailyNewLimit > 0 {
            let limit = settings.dailyNewLimit
            _ = max(max(limit * 3, limit + 20), 60)
            var pool = cards.filter { card in
                guard !card.isSuspended else { return false }
                let state = card.srs
                guard state.queue == .new && state.fsrsReps == 0 else { return false }
                if let deckId = card.deckId {
                    guard deckLookup[deckId] != nil else { return false }
                    if let deck = deckLookup[deckId], deck.isArchived { return false }
                }
                return true
            }.sorted { lhs, rhs in lhs.createdAt < rhs.createdAt }

            if !dueDeckIDs.isEmpty {
                pool = pool.filter { card in
                    guard let deckId = card.deckId else { return true }
                    return !dueDeckIDs.contains(deckId)
                }
            }

            planned.append(contentsOf: pool.prefix(limit))
        }

        var seen: Set<UUID> = []
        var unique: [Card] = []
        for card in planned where seen.insert(card.id).inserted {
            unique.append(card)
        }
        return unique
    }

    private func dueDateThreshold(for deck: Deck, cutoff: Date, now: Date) -> Date {
        guard let dueDate = deck.dueDate else { return cutoff }
        if dueDate <= now {
            return cutoff
        }
        return min(cutoff, dueDate)
    }

    private func buildQueuePreview(
        from buckets: [String: [Card]],
        deckLookup: [UUID: Deck],
        settings: UserSettings,
        dueHorizon: Date,
        asOf date: Date
    ) -> [SessionCuratorSnapshot.QueuePreview] {
        let retention = dataSafeRetention(from: settings)

        func deckDueDate(for card: Card) -> Date? {
            guard let deckId = card.deckId, let deck = deckLookup[deckId] else { return nil }
            return deck.dueDate
        }

        func effectiveDue(for card: Card) -> Date {
            guard let deckDue = deckDueDate(for: card) else {
                return max(card.srs.dueDate, date)
            }
            let buffer: TimeInterval = 3 * 60 * 60
            let target = deckDue.addingTimeInterval(-buffer)
            if target <= date {
                return max(date, card.srs.dueDate)
            }
            return max(date, min(card.srs.dueDate, target))
        }

        var working = buckets.mapValues { cards in
            cards.sorted { lhs, rhs in
                let lhsDue = effectiveDue(for: lhs)
                let rhsDue = effectiveDue(for: rhs)
                if lhsDue == rhsDue {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhsDue < rhsDue
            }
        }
        var concepts = working.keys.sorted { lhs, rhs in
            (working[lhs]?.count ?? 0) > (working[rhs]?.count ?? 0)
        }
        var previews: [SessionCuratorSnapshot.QueuePreview] = []
        var previousConcept: String?

        while previews.count < min(6, working.values.reduce(0) { $0 + $1.count }) {
            var progressMade = false
            for concept in concepts {
                guard var cards = working[concept], !cards.isEmpty else { continue }
                if previousConcept == concept && concepts.count > 1 { continue }
                let card = cards.removeFirst()
                working[concept] = cards
                previousConcept = concept
                progressMade = true

                let deckDue = deckDueDate(for: card)
                let recallTarget = deckDue.map { min($0, card.srs.dueDate) } ?? card.srs.dueDate
                let recall = card.srs.predictedRecall(on: recallTarget, retentionTarget: retention)
                let effectiveDueDate = effectiveDue(for: card)
                let dueInHours = max(0, effectiveDueDate.timeIntervalSince(date) / 3600.0)
                let emphasis: SessionCuratorSnapshot.QueuePreview.Emphasis
                if let deckDue, deckDue <= dueHorizon.addingTimeInterval(24 * 60 * 60) {
                    emphasis = .focus
                } else {
                    switch recall {
                    case ..<0.55:
                        emphasis = .focus
                    case ..<0.75:
                        emphasis = .contrast
                    default:
                        emphasis = .reinforce
                    }
                }

                let companion = companionConcept(for: card, primary: concept, deckLookup: deckLookup)
                let preview = SessionCuratorSnapshot.QueuePreview(
                    id: card.id,
                    concept: concept,
                    companionConcept: companion,
                    prompt: summarizePrompt(card.displayPrompt),
                    predictedRecall: recall,
                    dueInHours: dueInHours,
                    emphasis: emphasis
                )
                previews.append(preview)
                if previews.count >= 6 { break }
            }

            if !progressMade { break }

            concepts = concepts.sorted { lhs, rhs in
                (working[lhs]?.count ?? 0) > (working[rhs]?.count ?? 0)
            }
        }

        return previews
    }

    private func calculateInterleavingScore(
        queuePreview: [SessionCuratorSnapshot.QueuePreview],
        conceptBuckets: [String: [Card]],
        multiConceptCards: Int,
        totalDue: Int
    ) -> Double {
        guard totalDue > 0 else { return 0 }

        let diversity = Double(Set(queuePreview.map(\.concept)).count)
        let previewCount = max(1, queuePreview.count)
        let previewRatio = diversity / Double(previewCount)

        let multiRatio = totalDue > 0 ? Double(multiConceptCards) / Double(totalDue) : 0
        let breadthRatio = Double(conceptBuckets.keys.count) / Double(max(3, queuePreview.count))

        let score = (previewRatio * 0.5) + (multiRatio * 0.3) + (min(breadthRatio, 1) * 0.2)
        return min(max(score, 0), 1)
    }

    private func buildConceptWeaves(
        buckets: [String: [Card]],
        pairCounts: [ConceptPair: Int],
        totalDue: Int
    ) -> [SessionCuratorSnapshot.ConceptWeave] {
        let sortedConcepts = buckets.sorted { lhs, rhs in
            lhs.value.count > rhs.value.count
        }

        let topConcepts = sortedConcepts.prefix(4)
        var weaves: [SessionCuratorSnapshot.ConceptWeave] = []

        for (concept, cards) in topConcepts {
            let supporting = supportingConcepts(for: concept, pairCounts: pairCounts)
            let contribution = totalDue > 0 ? Double(cards.count) / Double(totalDue) : 0
            let strategy: SessionCuratorSnapshot.ConceptWeave.Strategy
            if supporting.contains(where: { $0.count > 2 }) {
                strategy = .contrast
            } else if cards.count <= 2 {
                strategy = .expand
            } else {
                strategy = .reinforce
            }

            let weave = SessionCuratorSnapshot.ConceptWeave(
                id: UUID(),
                primaryConcept: concept,
                supportingConcepts: supporting.map(\.name),
                contribution: contribution,
                dueCount: cards.count,
                strategy: strategy
            )
            weaves.append(weave)
        }

        return weaves
    }

    private func buildSessionInsights(
        dueCards: [Card],
        deckLookup: [UUID: Deck],
        dueHorizon: Date,
        conceptWeaves: [SessionCuratorSnapshot.ConceptWeave],
        interleavingScore: Double,
        settings: UserSettings,
        asOf date: Date
    ) -> [SessionCuratorSnapshot.Insight] {
        var insights: [SessionCuratorSnapshot.Insight] = []
        let calendar = Calendar.current
        let retention = dataSafeRetention(from: settings)

        var dueDecks: [UUID: (deck: Deck, dueDate: Date, cardCount: Int, weakCount: Int)] = [:]
        for card in dueCards {
            guard let deckId = card.deckId,
                  let deck = deckLookup[deckId],
                  let dueDate = deck.dueDate
            else { continue }
            guard dueDate <= dueHorizon || dueDate <= calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date else {
                continue
            }
            var entry = dueDecks[deckId] ?? (deck: deck, dueDate: dueDate, cardCount: 0, weakCount: 0)
            entry.dueDate = min(entry.dueDate, dueDate)
            entry.cardCount += 1
            let recall = card.srs.predictedRecall(on: dueDate, retentionTarget: retention)
            if recall < 0.82 {
                entry.weakCount += 1
            }
            dueDecks[deckId] = entry
        }

        if let critical = dueDecks.values.sorted(by: { $0.dueDate < $1.dueDate }).first {
            let countdown = countdownDescription(to: critical.dueDate, reference: date, calendar: calendar)
            let descriptor: String
            if critical.weakCount > 0 {
                descriptor = "\(critical.weakCount) weak cards"
            } else {
                descriptor = "\(critical.cardCount) cards"
            }
            insights.append(SessionCuratorSnapshot.Insight(
                id: UUID(),
                title: "\(critical.deck.name) deadline approaching",
                detail: "\(critical.deck.name) is \(countdown) with \(descriptor) in queue—prioritize this deck in today's focus.",
                symbol: "calendar.badge.exclamationmark"
            ))
        }

        let recallValues = dueCards.map { $0.srs.predictedRecall(on: date, retentionTarget: retention) }
        if let lowest = recallValues.min() {
            let percent = NumberFormatter.percentFormatter.string(from: NSNumber(value: lowest)) ?? ""
            let title = "Memory fragility detected"
            let detail = "Your weakest prompt is tracking at \(percent) recall—front-load it in today's mix."
            insights.append(SessionCuratorSnapshot.Insight(id: UUID(), title: title, detail: detail, symbol: "exclamationmark.triangle"))
        }

        if let topWeave = conceptWeaves.first {
            let allies = topWeave.supportingConcepts.prefix(2).joined(separator: " • ")
            let detail: String
            if allies.isEmpty {
                detail = "Thread \(topWeave.primaryConcept) with a complementary concept to deepen contrast."
            } else {
                detail = "Blend \(topWeave.primaryConcept) with \(allies) for sharper discrimination."
            }
            insights.append(SessionCuratorSnapshot.Insight(
                id: UUID(),
                title: "Anchor today's storyline",
                detail: detail,
                symbol: "square.grid.3x3.fill"
            ))
        }

        let interleavingPercent = NumberFormatter.percentFormatter.string(from: NSNumber(value: interleavingScore)) ?? ""
        let pacingTitle = interleavingScore > 0.7 ? "Rhythm looks vibrant" : "Broaden the cadence"
        let pacingDetail = interleavingScore > 0.7
            ? "Interleaving at \(interleavingPercent) — keep balancing contrasting ideas."
            : "Currently interleaving at \(interleavingPercent). Sprinkle in more varied concepts to elevate contrast."
        insights.append(SessionCuratorSnapshot.Insight(
            id: UUID(),
            title: pacingTitle,
            detail: pacingDetail,
            symbol: "metronome"
        ))

        return insights
    }

    private func supportingConcepts(
        for concept: String,
        pairCounts: [ConceptPair: Int]
    ) -> [(name: String, count: Int)] {
        var related: [String: Int] = [:]
        for (pair, count) in pairCounts {
            if pair.a == concept {
                related[pair.b, default: 0] += count
            } else if pair.b == concept {
                related[pair.a, default: 0] += count
            }
        }
        return related
            .sorted { lhs, rhs in lhs.value > rhs.value }
            .prefix(3)
            .map { ($0.key, $0.value) }
    }

    // MARK: - Adaptive Navigator

    private struct ConceptAccumulator {
        var name: String
        var kind: AdaptiveNavigatorSnapshot.ConceptKind
        var total: Int = 0
        var due: Int = 0
        var new: Int = 0
        var recallSum: Double = 0
        var stabilitySum: Double = 0
        var connections: [String: Int] = [:]
    }

    private func buildNavigatorSnapshot(from data: WorkspaceState, for date: Date) async -> AdaptiveNavigatorSnapshot {
        guard !data.cards.isEmpty else { return .empty }

        let deckLookup = Dictionary(uniqueKeysWithValues: data.decks.map { ($0.id, $0) })
        let hierarchy = DeckHierarchy(decks: data.decks)
        var deckAccumulators: [UUID: ConceptAccumulator] = [:]
        var conceptAccumulators: [String: ConceptAccumulator] = [:]

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let retentionTarget = dataSafeRetention(from: data.settings)
        
        // Load concept states from tracer for mastery integration
        let conceptStates = (try? await conceptTracer.allConceptStates()) ?? []
        let conceptStateLookup = Dictionary(uniqueKeysWithValues: conceptStates.map { ($0.key, $0) })

        for card in data.cards {
            let state = card.srs
            let isUnseen = state.fsrsReps == 0
            let recall = isUnseen ? 0 : state.predictedRecall(on: date, retentionTarget: retentionTarget)
            let stability = isUnseen ? 0 : state.stability
            let isDue = !card.isSuspended && state.dueDate < tomorrow
            let isNew = !card.isSuspended && state.queue == .new

            if let deckId = card.deckId, let deck = deckLookup[deckId] {
                let name = hierarchy.displayPath(of: deck.id)
                var accumulator = deckAccumulators[deckId] ?? ConceptAccumulator(name: name, kind: .deck)
                accumulator.total += 1
                if isDue { accumulator.due += 1 }
                if isNew { accumulator.new += 1 }
                accumulator.recallSum += recall
                accumulator.stabilitySum += stability

                for tag in card.tags {
                    accumulator.connections[tag, default: 0] += 1
                }

                deckAccumulators[deckId] = accumulator
            }

            let concepts = card.tags.isEmpty
                ? [card.deckId.map { hierarchy.displayPath(of: $0) } ?? "Unsorted"]
                : card.tags

            for concept in concepts {
                var accumulator = conceptAccumulators[concept] ?? ConceptAccumulator(name: concept, kind: .concept)
                accumulator.total += 1
                if isDue { accumulator.due += 1 }
                if isNew { accumulator.new += 1 }
                accumulator.recallSum += recall
                accumulator.stabilitySum += stability

                if let deckId = card.deckId, let deck = deckLookup[deckId] {
                    accumulator.connections[hierarchy.displayPath(of: deck.id), default: 0] += 1
                }

                for tag in card.tags where tag != concept {
                    accumulator.connections[tag, default: 0] += 1
                }

                conceptAccumulators[concept] = accumulator
            }
        }

        let deckNodes = deckAccumulators.map { entry -> AdaptiveNavigatorSnapshot.ConceptNode in
            buildConceptNode(from: entry.value, deckId: entry.key, conceptStateLookup: conceptStateLookup)
        }.sorted { lhs, rhs in lhs.mastery < rhs.mastery }

        let conceptNodes = conceptAccumulators.values.map { accumulator -> AdaptiveNavigatorSnapshot.ConceptNode in
            buildConceptNode(from: accumulator, deckId: nil, conceptStateLookup: conceptStateLookup)
        }.sorted { lhs, rhs in lhs.mastery < rhs.mastery }

        let totalDue = deckNodes.reduce(0) { $0 + $1.due }
        let totalConcepts = conceptNodes.count + deckNodes.count
        let focusConcepts = conceptNodes.filter { $0.energy == .focus }.count + deckNodes.filter { $0.energy == .focus }.count
        let accelerateConcepts = conceptNodes.filter { $0.energy == .accelerate }.count + deckNodes.filter { $0.energy == .accelerate }.count

        let averageMastery: Double
        if deckNodes.isEmpty {
            let aggregate = conceptNodes.reduce(0.0) { $0 + $1.mastery }
            averageMastery = conceptNodes.isEmpty ? 0 : aggregate / Double(conceptNodes.count)
        } else {
            let aggregate = deckNodes.reduce(0.0) { $0 + $1.mastery }
            averageMastery = aggregate / Double(deckNodes.count)
        }

        let journey = buildJourney(using: deckNodes, conceptNodes: conceptNodes)

        return AdaptiveNavigatorSnapshot(
            generatedAt: date,
            averageMastery: averageMastery,
            totalDue: totalDue,
            totalConcepts: totalConcepts,
            focusConcepts: focusConcepts,
            accelerateConcepts: accelerateConcepts,
            journey: journey,
            deckNodes: deckNodes,
            conceptNodes: conceptNodes
        )
    }

    private func buildConceptNode(
        from accumulator: ConceptAccumulator,
        deckId: UUID?,
        conceptStateLookup: [String: ConceptState]
    ) -> AdaptiveNavigatorSnapshot.ConceptNode {
        // Use tracer mastery as primary signal for concept nodes
        let tracerMastery: Double?
        if accumulator.kind == .concept {
            let normalizedKey = accumulator.name.trimmingCharacters(in: .whitespaces).lowercased()
            tracerMastery = conceptStateLookup[normalizedKey]?.pKnown
        } else {
            tracerMastery = nil
        }
        
        // Calculate FSRS-based mastery as fallback
        let fsrsMastery = calculateMasteryScore(
            recallSum: accumulator.recallSum,
            stabilitySum: accumulator.stabilitySum,
            total: accumulator.total
        )
        
        // Use tracer mastery for concepts if available, otherwise fall back to FSRS
        let mastery = tracerMastery ?? fsrsMastery
        
        let duePressure = accumulator.total > 0 ? Double(accumulator.due) / Double(accumulator.total) : 0
        let newPressure = accumulator.total > 0 ? Double(accumulator.new) / Double(accumulator.total) : 0
        let energy: AdaptiveNavigatorSnapshot.Energy
        if mastery < 0.55 || duePressure > 0.45 {
            energy = .focus
        } else if mastery < 0.75 || duePressure > 0.25 || newPressure > 0.35 {
            energy = .calibrate
        } else {
            energy = .accelerate
        }

        let sortedConnections = accumulator.connections.sorted { lhs, rhs in lhs.value > rhs.value }
        let connectionNames = sortedConnections.prefix(3).map { $0.key }

        return AdaptiveNavigatorSnapshot.ConceptNode(
            id: deckId?.uuidString ?? "\(accumulator.kind.rawValue)-\(accumulator.name)",
            deckId: deckId,
            name: accumulator.name,
            kind: accumulator.kind,
            mastery: mastery,
            due: accumulator.due,
            new: accumulator.new,
            connections: connectionNames,
            energy: energy
        )
    }

    private func buildJourney(
        using deckNodes: [AdaptiveNavigatorSnapshot.ConceptNode],
        conceptNodes: [AdaptiveNavigatorSnapshot.ConceptNode]
    ) -> [AdaptiveNavigatorSnapshot.JourneyStep] {
        var steps: [AdaptiveNavigatorSnapshot.JourneyStep] = []

        if let focus = (deckNodes + conceptNodes).first(where: { $0.energy == .focus }) {
            let detail = "\(focus.due) due • mastery \(formattedPercent(focus.mastery))"
            steps.append(.init(
                id: UUID(),
                title: "Stabilize \(focus.name)",
                detail: detail,
                symbol: "target",
                energy: .focus
            ))
        }

        if let calibrate = (deckNodes + conceptNodes).first(where: { $0.energy == .calibrate }) {
            let connections = calibrate.connections.prefix(2).joined(separator: " • ")
            let detail = connections.isEmpty ? "Blend with an adjacent concept" : "Bridge via \(connections)"
            steps.append(.init(
                id: UUID(),
                title: "Weave \(calibrate.name)",
                detail: detail,
                symbol: "point.topleft.down.curvedto.point.bottomright.up",
                energy: .calibrate
            ))
        }

        if let accelerate = (deckNodes + conceptNodes).first(where: { $0.energy == .accelerate }) {
            let detail = accelerate.new > 0
                ? "Unlock \(accelerate.new) fresh cards once review streak holds"
                : "Channel momentum into adjacent topics"
            steps.append(.init(
                id: UUID(),
                title: "Advance \(accelerate.name)",
                detail: detail,
                symbol: "forward.end",
                energy: .accelerate
            ))
        }

        return steps
    }

    // MARK: - Helpers

    private func normalizedConcepts(for card: Card, deckLookup: [UUID: Deck]) -> [String] {
        var concepts: [String] = []
        if let deckId = card.deckId, let deck = deckLookup[deckId] {
            concepts.append(deck.name)
        }
        if card.tags.isEmpty {
            concepts.append("Concepts")
        } else {
            concepts.append(contentsOf: card.tags)
        }
        return concepts
    }

    private func companionConcept(for card: Card, primary: String, deckLookup: [UUID: Deck]) -> String? {
        let candidates = normalizedConcepts(for: card, deckLookup: deckLookup).filter { $0 != primary }
        return candidates.first
    }

    private func summarizePrompt(_ prompt: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled prompt" }
        let components = trimmed.components(separatedBy: CharacterSet.newlines)
        let primary = components.first ?? trimmed
        if primary.count > 120 {
            let index = primary.index(primary.startIndex, offsetBy: 120)
            return String(primary[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return primary
    }

    private func calculateMasteryScore(recallSum: Double, stabilitySum: Double, total: Int) -> Double {
        guard total > 0 else { return 0 }
        let recallAverage = recallSum / Double(total)
        let stabilityAverage = stabilitySum / Double(total)
        let normalizedStability = min(stabilityAverage / 25.0, 1.0)
        return min(max((recallAverage * 0.65) + (normalizedStability * 0.35), 0), 1)
    }

    private func formattedPercent(_ value: Double) -> String {
        NumberFormatter.percentFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    private func countdownDescription(to dueDate: Date, reference: Date, calendar: Calendar) -> String {
        if dueDate <= reference {
            return "due now"
        }
        if calendar.isDate(dueDate, inSameDayAs: reference) {
            return "due today"
        }
        let startOfReference = calendar.startOfDay(for: reference)
        let startOfDue = calendar.startOfDay(for: dueDate)
        let components = calendar.dateComponents([.day], from: startOfReference, to: startOfDue)
        if let days = components.day {
            if days == 0 {
                return "due today"
            } else if days == 1 {
                return "due tomorrow"
            } else if days > 1 {
                return "due in \(days) days"
            }
        }
        let hours = max(1, Int(ceil(dueDate.timeIntervalSince(reference) / 3600.0)))
        return "due in \(hours)h"
    }

    private func dataSafeRetention(from settings: UserSettings) -> Double {
        min(max(settings.retentionTarget, 0.5), 0.97)
    }
}

// MARK: - Formatters

private extension NumberFormatter {
    static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
