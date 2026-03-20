@preconcurrency import Foundation

struct SRSStateService {
    private let storage: Storage
    private let deckService: DeckService
    private let cardService: CardService
    
    init(storage: Storage) {
        self.storage = storage
        self.deckService = DeckService(storage: storage)
        self.cardService = CardService(storage: storage)
    }
    
    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }
    
    func dueCards(for date: Date, settings: UserSettings, horizonDays: Int = 0) async -> [Card] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let cutoff = calendar.date(byAdding: .day, value: max(horizonDays + 1, 1), to: startOfDay) ?? date
        let retentionTarget = min(max(settings.retentionTarget, 0.5), 0.97)
        let dtos = try? await storage.dueCards(on: cutoff, limit: nil)
        let baseDue = (dtos ?? []).map { $0.toDomain() }
        
        let decks = await deckService.allDecks(includeArchived: false)
        let deckLookup = Dictionary(uniqueKeysWithValues: decks.map { ($0.id, $0) })
        let activeDeckIds = Set(deckLookup.keys)
        let horizonWindow = max(7, horizonDays + 1)
        let dueHorizon = calendar.date(byAdding: .day, value: horizonWindow, to: startOfDay) ?? cutoff
        
        struct PrioritizedCard {
            let card: Card
            let bucket: Int
            let effectiveDue: Date
            let predictedRecall: Double
        }
        
        var prioritized: [UUID: PrioritizedCard] = [:]
        
        func register(_ card: Card, bucket: Int, effectiveDue: Date) {
            var normalized = card
            if normalized.srs.dueDate != effectiveDue {
                normalized.srs.dueDate = effectiveDue
            }
            let prediction = normalized.srs.predictedRecall(on: effectiveDue, retentionTarget: retentionTarget)
            let entry = PrioritizedCard(
                card: normalized,
                bucket: bucket,
                effectiveDue: effectiveDue,
                predictedRecall: prediction
            )
            if let existing = prioritized[card.id] {
                if bucket < existing.bucket ||
                    (bucket == existing.bucket && effectiveDue < existing.effectiveDue) ||
                    (bucket == existing.bucket && effectiveDue == existing.effectiveDue && prediction < existing.predictedRecall)
                {
                    prioritized[card.id] = entry
                }
            } else {
                prioritized[card.id] = entry
            }
        }
        
        for card in baseDue where !card.isSuspended {
            if let deckId = card.deckId, !activeDeckIds.contains(deckId) { continue }
            let deck = card.deckId.flatMap { deckLookup[$0] }
            let effectiveDue = effectiveDueDate(for: card, deckDueDate: deck?.dueDate, asOf: date)
            let bucket = priorityBucket(
                for: card,
                deck: deck,
                cutoff: cutoff,
                dueHorizon: dueHorizon,
                retentionTarget: retentionTarget
            )
            register(card, bucket: bucket, effectiveDue: effectiveDue)
        }
        
        let dueCriticalDecks = decks.filter { deck in
            guard let due = deck.dueDate else { return false }
            return due <= dueHorizon || due <= cutoff
        }
        
        for deck in dueCriticalDecks {
            let cards = await cardService.cards(deckId: deck.id)
            for card in cards where !card.isSuspended {
                let bucket = priorityBucket(
                    for: card,
                    deck: deck,
                    cutoff: cutoff,
                    dueHorizon: dueHorizon,
                    retentionTarget: retentionTarget
                )
                guard bucket <= 2 else { continue }
                let effectiveDue = effectiveDueDate(for: card, deckDueDate: deck.dueDate, asOf: date)
                register(card, bucket: bucket, effectiveDue: effectiveDue)
            }
        }
        
        let ordered = prioritized.values.sorted { lhs, rhs in
            if lhs.bucket != rhs.bucket { return lhs.bucket < rhs.bucket }
            if lhs.effectiveDue != rhs.effectiveDue { return lhs.effectiveDue < rhs.effectiveDue }
            if lhs.predictedRecall != rhs.predictedRecall { return lhs.predictedRecall < rhs.predictedRecall }
            return lhs.card.createdAt < rhs.card.createdAt
        }.map(\.card)
        
        return ordered
    }
    
    func newCards(limit: Int) async -> [Card] {
        let dtos = try? await storage.newCards(limit: limit)
        let cards = (dtos ?? []).map { $0.toDomain() }
        let decks = await deckService.allDecks(includeArchived: false)
        let activeDeckIds = Set(decks.map(\.id))
        return cards.filter { card in
            guard let deckId = card.deckId else { return true }
            return activeDeckIds.contains(deckId)
        }
    }
    
    func save(card: Card) async {
        try? await storage.save(card: card.toDTO())
    }
    
    private func effectiveDueDate(for card: Card, deckDueDate: Date?, asOf date: Date) -> Date {
        guard let deckDueDate else { return max(card.srs.dueDate, date) }
        let buffer: TimeInterval = 3 * 60 * 60
        let target = deckDueDate.addingTimeInterval(-buffer)
        if target <= date {
            return max(date, card.srs.dueDate)
        }
        return max(date, min(card.srs.dueDate, target))
    }
    
    private func priorityBucket(
        for card: Card,
        deck: Deck?,
        cutoff: Date,
        dueHorizon: Date,
        retentionTarget: Double
    ) -> Int {
        if card.srs.dueDate <= cutoff {
            return 0
        }
        guard let deck, let deckDue = deck.dueDate else {
            return 3
        }
        let isCritical = deckDue <= dueHorizon || deckDue <= cutoff
        guard isCritical else { return 3 }
        if card.srs.queue == .new || card.srs.fsrsReps == 0 {
            return 1
        }
        let projectedRecall = card.srs.predictedRecall(on: deckDue, retentionTarget: retentionTarget)
        if projectedRecall < 0.82 {
            return 1
        }
        if card.srs.dueDate <= deckDue {
            return 1
        }
        return 2
    }
}
