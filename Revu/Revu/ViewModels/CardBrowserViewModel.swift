import Foundation
import Combine

@MainActor
final class CardBrowserViewModel: ObservableObject {
    @Published private(set) var cards: [Card] = []
    @Published private(set) var isLoading: Bool = false
    @Published var searchText: String = "" {
        didSet { applySearch() }
    }

    private(set) var filter: CardBrowserFilter
    private let storage: Storage
    private let cardService: CardService
    private let deckService: DeckService
    private var baseCards: [Card] = []
    private var loadTask: Task<Void, Never>?
    private var loadingFilter: CardBrowserFilter?

    init(filter: CardBrowserFilter, storage: Storage) {
        self.filter = filter
        self.storage = storage
        self.cardService = CardService(storage: storage)
        self.deckService = DeckService(storage: storage)
        // Don't load immediately - let the view trigger it with onAppear
    }

    convenience init(filter: CardBrowserFilter) {
        self.init(filter: filter, storage: DataController.shared.storage)
    }

    func load() async {
        await queueLoad(for: filter)
    }

    func load(for newFilter: CardBrowserFilter) async {
        setFilter(newFilter, clearSearch: true)
        await queueLoad(for: newFilter)
    }

    func setFilter(_ newFilter: CardBrowserFilter, clearSearch: Bool) {
        guard filter != newFilter else { return }
        filter = newFilter
        if clearSearch {
            searchText = ""
        }
        baseCards.removeAll()
        cards.removeAll()
    }

    func refresh() {
        Task { await queueLoad(for: filter) }
    }

    private func queueLoad(for targetFilter: CardBrowserFilter) async {
        if isLoading, loadingFilter == targetFilter {
            return
        }
        loadTask?.cancel()
        let task = Task { await performLoad(using: targetFilter) }
        loadTask = task
        await task.value
    }

    private func performLoad(using filter: CardBrowserFilter) async {
        isLoading = true
        loadingFilter = filter
        defer { isLoading = false }
        defer { loadingFilter = nil }

        let fetched: [Card] = await fetchCards(for: filter)

        guard filter == self.filter, !Task.isCancelled else { return }

        let sanitized = sanitize(fetched, for: filter)
        baseCards = sanitized
        applySearch()
    }

    func deck(for id: UUID) async -> Deck? {
        await deckService.deck(withId: id)
    }

    func state(for card: Card) -> SRSState {
        card.srs
    }
    
    func removeCard(withId id: UUID) {
        // Optimistically remove from UI
        baseCards.removeAll { $0.id == id }
        applySearch()
    }
    
    func updateCard(_ card: Card) {
        // Optimistically update in UI
        if let index = baseCards.firstIndex(where: { $0.id == card.id }) {
            baseCards[index] = card
            applySearch()
        }
    }

    private func fetchSmartCards(_ smart: SmartFilter) async -> [Card] {
        let all = await cardService.allCards()
        switch smart {
        case .dueToday:
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return all.filter { card in
                guard !card.isSuspended else { return false }
                let state = card.srs
                if state.queue == .new { return false }
                return state.dueDate < tomorrow
            }
        case .new:
            return all.filter { !$0.isSuspended && $0.srs.queue == .new }
        case .suspended:
            return all.filter { $0.isSuspended }
        }
    }

    private func applySearch() {
        guard !searchText.isEmpty else {
            cards = baseCards
            return
        }
        let needle = searchText.lowercased()
        cards = baseCards.filter { card in
            card.front.lowercased().contains(needle) ||
            card.back.lowercased().contains(needle) ||
            card.choices.contains { $0.lowercased().contains(needle) } ||
            card.tags.contains { $0.lowercased().contains(needle) }
        }
    }

    private func fetchCards(for filter: CardBrowserFilter) async -> [Card] {
        switch filter {
        case .deck(let deckId):
            return await cardService.cards(deckId: deckId)
        case .tag(let tag):
            let all = await cardService.allCards()
            return all.filter { card in
                card.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
            }
        case .smart(let smart):
            return await fetchSmartCards(smart)
        }
    }

    private func sanitize(_ cards: [Card], for filter: CardBrowserFilter) -> [Card] {
        switch filter {
        case .deck(let deckId):
            return cards.filter { $0.deckId == deckId }
        case .tag(let tag):
            let normalizedTag = tag.lowercased()
            return cards.filter { card in
                card.tags.contains { $0.lowercased() == normalizedTag }
            }
        case .smart:
            return cards
        }
    }
}
