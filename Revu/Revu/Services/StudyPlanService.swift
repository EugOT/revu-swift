@preconcurrency import Foundation

struct StudyPlanSummary: Equatable, Sendable {
    struct Day: Identifiable, Equatable, Sendable {
        let date: Date
        let newCount: Int
        let reviewCount: Int

        var id: Date { date }
        var total: Int { newCount + reviewCount }
    }

    let deckId: UUID
    let generatedAt: Date
    let dueDate: Date?
    let totalCards: Int
    let activeNewCards: Int
    let suspendedCards: Int
    let lastStudied: Date?
    let days: [Day]

    var dueToday: Int { days.first?.total ?? 0 }
    var newToday: Int { days.first?.newCount ?? 0 }
    var plannedThrough: Date? { days.last?.date }
    var totalScheduled: Int { days.reduce(0) { $0 + $1.total } }

    static func empty(deckId: UUID, dueDate: Date? = nil, generatedAt: Date = Date()) -> StudyPlanSummary {
        StudyPlanSummary(
            deckId: deckId,
            generatedAt: generatedAt,
            dueDate: dueDate,
            totalCards: 0,
            activeNewCards: 0,
            suspendedCards: 0,
            lastStudied: nil,
            days: []
        )
    }
}

struct StudyPlanService {
    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    func rebuildDeckPlan(
        forDeckId deckId: UUID,
        dueDate: Date?,
        referenceDate: Date = Date()
    ) async -> StudyPlanSummary {
        let settings = await loadSettings()
        let deckDTO = try? await storage.deck(withId: deckId)
        let effectiveDueDate = deckDTO?.dueDate ?? dueDate
        let decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        let hierarchy = DeckHierarchy(decks: decks)
        let subtree = hierarchy.subtreeDeckIDs(of: deckId)
        let cards = await loadCards(forDeckIDs: subtree)
        let isArchivedDeck = (hierarchy.deck(id: deckId)?.isArchived ?? false) ||
            hierarchy.ancestors(of: deckId).contains(where: { $0.isArchived })

        if isArchivedDeck {
            return archivedSummary(forDeckId: deckId, dueDate: effectiveDueDate, cards: cards, referenceDate: referenceDate)
        }
        var builder = StudyPlanBuilder(
            deckId: deckId,
            dueDate: effectiveDueDate,
            settings: settings,
            referenceDate: referenceDate,
            cards: cards
        )
        let computation = builder.build()
        if !computation.updatedCards.isEmpty {
            for card in computation.updatedCards {
                try? await storage.upsert(card: card.toDTO())
            }
        }
        return computation.summary
    }

    func forecastDeckPlan(
        forDeckId deckId: UUID,
        dueDate: Date?,
        referenceDate: Date = Date()
    ) async -> StudyPlanSummary {
        let settings = await loadSettings()
        let deckDTO = try? await storage.deck(withId: deckId)
        let effectiveDueDate = deckDTO?.dueDate ?? dueDate
        let decks = (try? await storage.allDecks().map { $0.toDomain() }) ?? []
        let hierarchy = DeckHierarchy(decks: decks)
        let subtree = hierarchy.subtreeDeckIDs(of: deckId)
        let cards = await loadCards(forDeckIDs: subtree)
        let isArchivedDeck = (hierarchy.deck(id: deckId)?.isArchived ?? false) ||
            hierarchy.ancestors(of: deckId).contains(where: { $0.isArchived })
        if isArchivedDeck {
            return archivedSummary(forDeckId: deckId, dueDate: effectiveDueDate, cards: cards, referenceDate: referenceDate)
        }
        var builder = StudyPlanBuilder(
            deckId: deckId,
            dueDate: effectiveDueDate,
            settings: settings,
            referenceDate: referenceDate,
            cards: cards
        )
        let computation = builder.build()
        return computation.summary
    }

    func workspaceForecast(referenceDate: Date = Date()) async -> [StudyPlanSummary] {
        async let decksTask = storage.allDecks()
        async let cardsTask = storage.allCards()
        async let settingsTask = storage.loadSettings()

        let deckDTOs = (try? await decksTask) ?? []
        let cardDTOs = (try? await cardsTask) ?? []
        let settings = (try? await settingsTask)?.toDomain() ?? UserSettings()

        let decks = deckDTOs.map { $0.toDomain() }.filter { !$0.isArchived }
        let activeDeckIds = Set(decks.map(\.id))
        let cards = cardDTOs.map { $0.toDomain() }.filter { card in
            guard let deckId = card.deckId else { return true }
            return activeDeckIds.contains(deckId)
        }
        let grouped = Dictionary(grouping: cards) { $0.deckId }

        var summaries: [StudyPlanSummary] = []
        summaries.reserveCapacity(decks.count)
        for deck in decks {
            let deckCards = grouped[deck.id] ?? []
            var builder = StudyPlanBuilder(
                deckId: deck.id,
                dueDate: deck.dueDate,
                settings: settings,
                referenceDate: referenceDate,
                cards: deckCards
            )
            let computation = builder.build()
            summaries.append(computation.summary)
        }
        return summaries
    }

    static func forecastSummary(
        for deck: Deck,
        cards: [Card],
        settings: UserSettings,
        referenceDate: Date = Date()
    ) -> StudyPlanSummary {
        if deck.isArchived {
            let lastStudied = cards.compactMap { $0.srs.lastReviewed }.max()
            return StudyPlanSummary(
                deckId: deck.id,
                generatedAt: referenceDate,
                dueDate: deck.dueDate,
                totalCards: cards.count,
                activeNewCards: 0,
                suspendedCards: cards.count,
                lastStudied: lastStudied,
                days: []
            )
        }
        var builder = StudyPlanBuilder(
            deckId: deck.id,
            dueDate: deck.dueDate,
            settings: settings,
            referenceDate: referenceDate,
            cards: cards
        )
        return builder.build().summary
    }

    private func loadSettings() async -> UserSettings {
        if let stored = try? await storage.loadSettings() {
            return stored.toDomain()
        }
        return UserSettings()
    }

    private func archivedSummary(forDeckId deckId: UUID, dueDate: Date?, cards: [Card], referenceDate: Date) -> StudyPlanSummary {
        let lastStudied = cards.compactMap { $0.srs.lastReviewed }.max()
        return StudyPlanSummary(
            deckId: deckId,
            generatedAt: referenceDate,
            dueDate: dueDate,
            totalCards: cards.count,
            activeNewCards: 0,
            suspendedCards: cards.count,
            lastStudied: lastStudied,
            days: []
        )
    }
}

private extension StudyPlanService {
    func loadCards(forDeckIDs deckIds: [UUID]) async -> [Card] {
        var collected: [CardDTO] = []
        for deckId in deckIds {
            let cards = (try? await storage.cards(deckId: deckId)) ?? []
            collected.append(contentsOf: cards)
        }
        var unique: [UUID: CardDTO] = [:]
        for dto in collected {
            unique[dto.id] = dto
        }
        return unique.values.map { $0.toDomain() }
    }
}

private struct StudyPlanComputation {
    let summary: StudyPlanSummary
    let updatedCards: [Card]
}

private struct StudyPlanBuilder {
    private let deckId: UUID
    private let dueDate: Date?
    private let settings: UserSettings
    private let referenceDate: Date
    private var cards: [Card]

    private let calendar = Calendar.current
    private let maxSummaryDays = 60

    init(deckId: UUID, dueDate: Date?, settings: UserSettings, referenceDate: Date, cards: [Card]) {
        self.deckId = deckId
        self.dueDate = dueDate
        self.settings = settings
        self.referenceDate = referenceDate
        self.cards = cards
    }

    mutating func build() -> StudyPlanComputation {
        guard !cards.isEmpty else {
            return StudyPlanComputation(
                summary: StudyPlanSummary.empty(deckId: deckId, dueDate: dueDate, generatedAt: referenceDate),
                updatedCards: []
            )
        }

        let originalCards = cards
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let dueBuffer = dueDate?.addingTimeInterval(-3 * 3_600)

        var changed: [UUID: Card] = [:]

        let newIndices = cards.enumerated().filter { index, card in
            guard !card.isSuspended else { return false }
            let state = card.srs
            return state.queue == .new && state.fsrsReps == 0
        }.map(\.offset)

        let baseDailyLimit: Int = {
            guard !newIndices.isEmpty else { return 1 }
            if settings.dailyNewLimit > 0 && dueDate == nil {
                return settings.dailyNewLimit
            }
            let horizon = max(1, min(newIndices.count, 14))
            return max(1, Int(ceil(Double(newIndices.count) / Double(horizon))))
        }()

        var furthestDayOffset = 0

        if !newIndices.isEmpty {
            let sortedIndices = newIndices.sorted { lhs, rhs in
                let left = cards[lhs]
                let right = cards[rhs]
                if left.createdAt != right.createdAt {
                    return left.createdAt < right.createdAt
                }
                return left.id.uuidString < right.id.uuidString
            }

            let horizonDays: Int = {
                if let dueDate {
                    let dueStart = calendar.startOfDay(for: dueDate)
                    let span = max(0, calendar.dateComponents([.day], from: startOfToday, to: dueStart).day ?? 0)
                    return max(1, span + 1)
                }
                let required = Int(ceil(Double(sortedIndices.count) / Double(max(baseDailyLimit, 1))))
                return max(1, min(max(required, 7), maxSummaryDays))
            }()

            var capacity = Array(repeating: max(baseDailyLimit, 1), count: horizonDays)
            if let dueDate {
                let dueStart = calendar.startOfDay(for: dueDate)
                let span = max(0, calendar.dateComponents([.day], from: startOfToday, to: dueStart).day ?? 0)
                if span + 1 > 0 {
                    let requiredPerDay = Int(ceil(Double(sortedIndices.count) / Double(span + 1)))
                    if requiredPerDay > capacity.first ?? 0 {
                        capacity = Array(repeating: requiredPerDay, count: span + 1)
                    }
                }
            }

            var usage = Array(repeating: 0, count: capacity.count)

            for index in sortedIndices {
                // Pick the day with the lowest usage that is still under capacity.
                var dayIndex: Int? = nil
                for candidate in usage.indices {
                    guard usage[candidate] < capacity[candidate] else { continue }
                    if let chosen = dayIndex {
                        let currentUsage = usage[chosen]
                        if usage[candidate] < currentUsage {
                            dayIndex = candidate
                        }
                    } else {
                        dayIndex = candidate
                    }
                }

                if dayIndex == nil {
                    let fallback = capacity.last ?? max(baseDailyLimit, 1)
                    capacity.append(fallback)
                    usage.append(0)
                    dayIndex = usage.count - 1
                }

                guard let scheduledIndex = dayIndex,
                      let scheduledDay = calendar.date(byAdding: .day, value: scheduledIndex, to: startOfToday) else { continue }

                var plannedDate = calendar.date(byAdding: DateComponents(hour: 12), to: scheduledDay) ?? scheduledDay
                if let dueBuffer {
                    plannedDate = min(plannedDate, dueBuffer)
                }
                plannedDate = max(plannedDate, referenceDate)

                cards[index].srs.dueDate = plannedDate
                if cards[index].srs.dueDate != originalCards[index].srs.dueDate {
                    changed[cards[index].id] = cards[index]
                }
                usage[scheduledIndex] += 1
                furthestDayOffset = max(furthestDayOffset, scheduledIndex)
            }
        }

        if let dueBuffer {
            let clampDate = max(referenceDate, dueBuffer)
            for idx in cards.indices {
                guard !cards[idx].isSuspended else { continue }
                let state = cards[idx].srs
                if state.queue == .new && state.fsrsReps == 0 { continue }
                if state.dueDate > clampDate {
                    cards[idx].srs.dueDate = clampDate
                    if cards[idx].srs.dueDate != originalCards[idx].srs.dueDate {
                        changed[cards[idx].id] = cards[idx]
                    }
                }
            }
        }

        let activeNewCards = cards.reduce(0) { count, card in
            guard !card.isSuspended else { return count }
            if card.srs.queue == .new && card.srs.fsrsReps == 0 {
                return count + 1
            }
            return count
        }
        let suspendedCards = cards.filter(\.isSuspended).count
        let lastStudied = cards.compactMap { $0.srs.lastReviewed }.max()

        let summaryDays = buildSummaryDays(
            from: cards,
            startOfToday: startOfToday,
            furthestDayOffset: furthestDayOffset,
            dueDate: dueDate
        )

        let summary = StudyPlanSummary(
            deckId: deckId,
            generatedAt: referenceDate,
            dueDate: dueDate,
            totalCards: cards.count,
            activeNewCards: activeNewCards,
            suspendedCards: suspendedCards,
            lastStudied: lastStudied,
            days: summaryDays
        )

        return StudyPlanComputation(
            summary: summary,
            updatedCards: Array(changed.values)
        )
    }

    private func buildSummaryDays(
        from cards: [Card],
        startOfToday: Date,
        furthestDayOffset: Int,
        dueDate: Date?
    ) -> [StudyPlanSummary.Day] {
        let summaryEnd: Date = {
            if let dueDate {
                let dueStart = calendar.startOfDay(for: dueDate)
                return max(startOfToday, dueStart)
            }
            let offset = min(max(furthestDayOffset, 6), maxSummaryDays - 1)
            return calendar.date(byAdding: .day, value: offset, to: startOfToday) ?? startOfToday
        }()

        let cappedEnd = min(
            summaryEnd,
            calendar.date(byAdding: .day, value: maxSummaryDays - 1, to: startOfToday) ?? summaryEnd
        )

        var daySequence: [Date] = []
        let span = max(0, calendar.dateComponents([.day], from: startOfToday, to: cappedEnd).day ?? 0)
        if span == 0 {
            daySequence = [startOfToday]
        } else {
            for offset in 0...span {
                if let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) {
                    daySequence.append(day)
                }
            }
        }

        var breakdown: [Date: (new: Int, review: Int)] = Dictionary(uniqueKeysWithValues: daySequence.map { ($0, (0, 0)) })

        for card in cards where !card.isSuspended {
            let effectiveDue = max(card.srs.dueDate, referenceDate)
            var bucketDay = calendar.startOfDay(for: effectiveDue)
            if bucketDay < startOfToday {
                bucketDay = startOfToday
            }
            if bucketDay > cappedEnd {
                bucketDay = cappedEnd
            }
            var entry = breakdown[bucketDay] ?? (0, 0)
            if card.srs.queue == .new && card.srs.fsrsReps == 0 {
                entry.new += 1
            } else {
                entry.review += 1
            }
            breakdown[bucketDay] = entry
        }

        return daySequence.map { day in
            let counts = breakdown[day] ?? (0, 0)
            return StudyPlanSummary.Day(date: day, newCount: counts.new, reviewCount: counts.review)
        }
    }
}
