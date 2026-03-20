import Foundation

struct SearchService {
    private let storage: Storage
    private let deckService: DeckService
    private let cardService: CardService
    private let tagService: TagService

    init(storage: Storage) {
        self.storage = storage
        self.deckService = DeckService(storage: storage)
        self.cardService = CardService(storage: storage)
        self.tagService = TagService(storage: storage)
    }

    init() {
        self.init(storage: DataController.shared.storage)
    }

    func search(query: String) async -> [QuickCommandResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            async let decksTask = deckService.allDecks()
            async let cardsTask = cardService.allCards()
            let decks = await decksTask
            let cards = await cardsTask
            return defaultResults(decks: decks, cards: cards)
        }

        async let decksTask = deckService.allDecks()
        async let cardsTask = cardService.searchCards(query: trimmed)
        async let tagsTask = tagService.allTags()

        let decks = await decksTask
        let cards = await cardsTask
        let tags = await tagsTask
        let deckLookup = Dictionary(uniqueKeysWithValues: decks.map { ($0.id, $0) })
        let hierarchy = DeckHierarchy(decks: decks)

        var results: [QuickCommandResult] = []
        results.append(contentsOf: deckResults(for: trimmed, decks: decks, hierarchy: hierarchy))
        results.append(contentsOf: cardResults(for: trimmed, cards: cards, deckLookup: deckLookup, hierarchy: hierarchy))
        results.append(contentsOf: tagResults(for: trimmed, tags: tags))
        results.append(contentsOf: smartFilterResults(for: trimmed))
        if trimmed.localizedCaseInsensitiveContains("setting") {
            results.append(QuickCommandResult(
                id: "settings",
                title: "Settings",
                subtitle: "Update preferences",
                icon: "gearshape",
                action: .openSettings
            ))
        }
        if trimmed.localizedCaseInsensitiveContains("stat") {
            results.append(QuickCommandResult(
                id: "stats",
                title: "Stats",
                subtitle: "View analytics",
                icon: "chart.bar",
                action: .openStats
            ))
        }
        return results
    }

    private func defaultResults(decks: [Deck], cards: [Card]) -> [QuickCommandResult] {
        var results: [QuickCommandResult] = []
        let hierarchy = DeckHierarchy(decks: decks)
        let recentDecks = decks.sorted { $0.updatedAt > $1.updatedAt }.prefix(3)
        for deck in recentDecks {
            results.append(
                QuickCommandResult(
                    id: "deck-\(deck.id)",
                    title: hierarchy.displayPath(of: deck.id),
                    subtitle: "Deck",
                    icon: "rectangle.stack",
                    action: .openDeck(deck.id)
                )
            )
        }

        let metrics = quickFilterMetrics(from: cards)
        for filter in SmartFilter.allCases {
            let count = metrics[filter] ?? 0
            let badge = count > 0 ? String(count) : nil
            results.append(
                QuickCommandResult(
                    id: "smart-\(filter.rawValue)",
                    title: filter.title,
                    subtitle: filter.subtitle,
                    icon: filter.symbol,
                    badge: badge,
                    action: .smartFilter(filter)
                )
            )
        }

        results.append(
            QuickCommandResult(
                id: "stats",
                title: "Stats",
                subtitle: "Review progress dashboards",
                icon: "chart.bar",
                action: .openStats
            )
        )
        results.append(
            QuickCommandResult(
                id: "settings",
                title: "Settings",
                subtitle: "Update preferences",
                icon: "gearshape",
                action: .openSettings
            )
        )
        return results
    }

    private func quickFilterMetrics(from cards: [Card]) -> [SmartFilter: Int] {
        var counts: [SmartFilter: Int] = [.dueToday: 0, .new: 0, .suspended: 0]
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        for card in cards {
            if card.isSuspended {
                counts[.suspended, default: 0] += 1
                continue
            }
            if card.srs.dueDate < tomorrow {
                counts[.dueToday, default: 0] += 1
            }
            if card.srs.queue == .new {
                counts[.new, default: 0] += 1
            }
        }
        return counts
    }

    private func deckResults(for query: String, decks: [Deck], hierarchy: DeckHierarchy) -> [QuickCommandResult] {
        decks
            .filter { hierarchy.displayPath(of: $0.id, separator: "::").localizedCaseInsensitiveContains(query) || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(5)
            .map { deck in
                QuickCommandResult(
                    id: "deck-\(deck.id)",
                    title: hierarchy.displayPath(of: deck.id),
                    subtitle: "Deck",
                    icon: "rectangle.stack",
                    action: .openDeck(deck.id)
                )
            }
    }

    private func cardResults(for query: String, cards: [Card], deckLookup: [UUID: Deck], hierarchy: DeckHierarchy) -> [QuickCommandResult] {
        cards
            .prefix(8)
            .map { card in
                let deckName = card.deckId.map { hierarchy.displayPath(of: $0) } ?? "Unassigned"
                let subtitle = deckName.isEmpty ? card.kind.displayName : deckName
                let prompt = card.displayPrompt
                let fallback = card.displayAnswer
                return QuickCommandResult(
                    id: "card-\(card.id)",
                    title: prompt.isEmpty ? fallback : prompt,
                    subtitle: subtitle,
                    icon: "doc.text.magnifyingglass",
                    action: .openCard(cardId: card.id, deckId: card.deckId)
                )
            }
    }

    private func tagResults(for query: String, tags: [String]) -> [QuickCommandResult] {
        tags
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .prefix(5)
            .map { tag in
                QuickCommandResult(
                    id: "tag-\(tag)",
                    title: "#\(tag)",
                    subtitle: "Tag filter",
                    icon: "tag",
                    action: .filterTag(tag)
                )
            }
    }

    private func smartFilterResults(for query: String) -> [QuickCommandResult] {
        SmartFilter.allCases
            .filter { filter in
                filter.title.localizedCaseInsensitiveContains(query) ||
                filter.searchKeywords.contains { $0.localizedCaseInsensitiveContains(query) }
            }
            .map { filter in
                QuickCommandResult(
                    id: "smart-\(filter.rawValue)",
                    title: filter.title,
                    subtitle: filter.subtitle,
                    icon: filter.symbol,
                    action: .smartFilter(filter)
                )
            }
    }
}
