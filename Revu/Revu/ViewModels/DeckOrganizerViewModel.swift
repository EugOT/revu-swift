import Foundation
import Combine

@MainActor
final class DeckOrganizerViewModel: ObservableObject {
    enum DropRegion: Sendable {
        case before
        case nest
        case after
    }

    static func dropRegion(locationY: CGFloat, rowHeight: CGFloat) -> DropRegion {
        let height = max(rowHeight, 1)
        let threshold = min(18, max(height * 0.4, 12))
        if locationY <= threshold {
            return .before
        }
        if locationY >= height - threshold {
            return .after
        }
        return .nest
    }

    enum DragMode: String, CaseIterable, Identifiable {
        case organize
        case merge

        var id: String { rawValue }

        var title: String {
            switch self {
            case .organize: return "Organize"
            case .merge: return "Merge"
            }
        }
    }

    struct DeckActivitySnapshot: Equatable, Sendable {
        var overdue: Int = 0
        var dueToday: Int = 0
        var dueSoon: Int = 0
        var new: Int = 0
        var total: Int = 0

        var dueTotal: Int { overdue + dueToday }
    }

    struct DeckRow: Identifiable, Equatable, Sendable {
        let deck: Deck
        let depth: Int
        let hasChildren: Bool
        let isExpanded: Bool
        let displayPath: String

        var id: UUID { deck.id }
    }

    @Published var searchText: String = "" {
        didSet { rebuildRows() }
    }

    @Published var dragMode: DragMode = .organize
    @Published var includeArchived: Bool = false {
        didSet { rebuildRows() }
    }

    @Published private(set) var rows: [DeckRow] = []
    @Published private(set) var deckOrder: [UUID] = []
    @Published private(set) var snapshots: [UUID: DeckActivitySnapshot] = [:]
    @Published private(set) var isLoading: Bool = false

    private(set) var allDecks: [Deck] = []
    private var collapsedDeckIDs: Set<UUID> = [] {
        didSet {
            persistCollapsedDeckIDs()
            rebuildRows()
        }
    }

    private let storage: Storage
    private let deckService: DeckService
    private let userDefaults: UserDefaults
    private let collapsedDecksKey: String
    private var loadTask: Task<Void, Never>?
    private var dragPreviewOriginalOrder: [UUID]?
    private var lastPreviewMove: (sourceID: UUID, targetID: UUID, placeBefore: Bool)?

    init(
        storage: Storage,
        userDefaults: UserDefaults = .standard,
        collapsedDecksKey: String = "deckOrganizer.collapsedDeckIDs"
    ) {
        self.storage = storage
        self.deckService = DeckService(storage: storage)
        self.userDefaults = userDefaults
        self.collapsedDecksKey = collapsedDecksKey
        self.collapsedDeckIDs = Self.loadCollapsedDeckIDs(userDefaults: userDefaults, key: collapsedDecksKey)
    }

    convenience init() {
        self.init(storage: DataController.shared.storage, userDefaults: .standard)
    }

    func refresh() {
        Task { await refreshNow() }
    }

    func refreshNow() async {
        loadTask?.cancel()
        let task = Task { await load() }
        loadTask = task
        await task.value
    }

    func toggleExpanded(_ deckId: UUID) {
        if collapsedDeckIDs.contains(deckId) {
            collapsedDeckIDs.remove(deckId)
        } else {
            collapsedDeckIDs.insert(deckId)
        }
    }

    func isExpanded(_ deckId: UUID) -> Bool {
        !collapsedDeckIDs.contains(deckId)
    }

    func handleDrop(
        payloads: [DeckDragPayload],
        targetDeckId: UUID,
        locationY: CGFloat,
        rowHeight: CGFloat,
        onMergeDecks: @escaping (Deck, Deck) -> Void
    ) -> Bool {
        guard let payload = payloads.first,
              let sourceDeck = deck(id: payload.id),
              let targetDeck = deck(id: targetDeckId),
              sourceDeck.id != targetDeck.id else {
            return false
        }

        if dragMode == .merge {
            onMergeDecks(sourceDeck, targetDeck)
            return true
        }

        let region = Self.dropRegion(locationY: locationY, rowHeight: rowHeight)
        switch region {
        case .nest:
            collapsedDeckIDs.remove(targetDeck.id)
            return reparentAndPosition(
                sourceDeck: sourceDeck,
                newParentId: targetDeck.id,
                anchorDeckId: lastDeckIdInSubtree(of: targetDeck.id) ?? targetDeck.id,
                placeBefore: false
            )
        case .before:
            return reparentAndPosition(
                sourceDeck: sourceDeck,
                newParentId: targetDeck.parentId,
                anchorDeckId: targetDeck.id,
                placeBefore: true
            )
        case .after:
            return reparentAndPosition(
                sourceDeck: sourceDeck,
                newParentId: targetDeck.parentId,
                anchorDeckId: targetDeck.id,
                placeBefore: false
            )
        }
    }

    func deck(id: UUID) -> Deck? {
        allDecks.first(where: { $0.id == id })
    }

    func beginDragPreviewIfNeeded() {
        if dragPreviewOriginalOrder == nil {
            dragPreviewOriginalOrder = deckOrder
            lastPreviewMove = nil
        }
    }

    func previewReorder(sourceDeckId: UUID, targetDeckId: UUID, placeBefore: Bool) {
        guard dragMode == .organize else { return }
        guard sourceDeckId != targetDeckId else { return }

        beginDragPreviewIfNeeded()
        if let lastPreviewMove,
           lastPreviewMove.sourceID == sourceDeckId,
           lastPreviewMove.targetID == targetDeckId,
           lastPreviewMove.placeBefore == placeBefore {
            return
        }

        lastPreviewMove = (sourceID: sourceDeckId, targetID: targetDeckId, placeBefore: placeBefore)
        moveDeckInOrder(sourceID: sourceDeckId, targetID: targetDeckId, placeBefore: placeBefore)
    }

    func cancelDragPreview() {
        guard let originalOrder = dragPreviewOriginalOrder else { return }
        dragPreviewOriginalOrder = nil
        lastPreviewMove = nil

        deckOrder = originalOrder
        allDecks = DeckHierarchy(decks: allDecks).preorder(usingSortOrder: originalOrder)
        rebuildRows()
    }

    func commitDragPreview() {
        dragPreviewOriginalOrder = nil
        lastPreviewMove = nil
    }
}

private extension DeckOrganizerViewModel {
    func load() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        async let decksTask = storage.allDecks()
        async let cardsTask = storage.allCards()
        async let settingsTask = storage.loadSettings()

        let deckDTOs = (try? await decksTask) ?? []
        let cardDTOs = (try? await cardsTask) ?? []
        let settingsDTO = (try? await settingsTask)

        let fetchedDecks = deckDTOs.map { $0.toDomain() }
        let normalizedOrder = normalizeDeckOrder(
            storedOrder: settingsDTO?.deckSortOrder ?? [],
            decks: fetchedDecks
        )
        let orderedDecks = DeckHierarchy(decks: fetchedDecks).preorder(usingSortOrder: normalizedOrder)

        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let soon = calendar.date(byAdding: .day, value: 3, to: startOfDay) ?? tomorrow

        var deckSnapshotAccumulator: [UUID: DeckActivitySnapshot] = [:]
        for card in cardDTOs {
            guard let deckId = card.deckId else { continue }
            var snapshot = deckSnapshotAccumulator[deckId] ?? DeckActivitySnapshot()
            snapshot.total += 1

            if !card.isSuspended {
                if card.srs.queue == .new {
                    snapshot.new += 1
                } else if card.srs.dueDate < startOfDay {
                    snapshot.overdue += 1
                } else if card.srs.dueDate < tomorrow {
                    snapshot.dueToday += 1
                } else if card.srs.dueDate < soon {
                    snapshot.dueSoon += 1
                }
            }

            deckSnapshotAccumulator[deckId] = snapshot
        }

        let hierarchy = DeckHierarchy(decks: fetchedDecks)
        var aggregatedSnapshots = deckSnapshotAccumulator
        for (deckId, snapshot) in deckSnapshotAccumulator {
            for ancestor in hierarchy.ancestors(of: deckId) {
                var rolled = aggregatedSnapshots[ancestor.id] ?? DeckActivitySnapshot()
                rolled.total += snapshot.total
                rolled.overdue += snapshot.overdue
                rolled.dueToday += snapshot.dueToday
                rolled.dueSoon += snapshot.dueSoon
                rolled.new += snapshot.new
                aggregatedSnapshots[ancestor.id] = rolled
            }
        }

        await MainActor.run {
            guard !Task.isCancelled else { return }
            allDecks = orderedDecks
            deckOrder = normalizedOrder
            snapshots = aggregatedSnapshots
            rebuildRows()
        }
    }

    func rebuildRows() {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let visibleDecks: [Deck] = includeArchived ? allDecks : allDecks.filter { !$0.isArchived }
        let visibleIDs = Set(visibleDecks.map(\.id))
        let hierarchy = DeckHierarchy(decks: visibleDecks)

        let allowedIDs: Set<UUID>
        let forcedExpanded: Set<UUID>

        if trimmedSearch.isEmpty {
            allowedIDs = visibleIDs
            forcedExpanded = []
        } else {
            var matches: Set<UUID> = []
            var expand: Set<UUID> = []
            for deck in visibleDecks {
                if deck.name.localizedCaseInsensitiveContains(trimmedSearch) ||
                    hierarchy.displayPath(of: deck.id).localizedCaseInsensitiveContains(trimmedSearch) {
                    matches.insert(deck.id)
                    for ancestor in hierarchy.ancestors(of: deck.id) {
                        matches.insert(ancestor.id)
                        expand.insert(ancestor.id)
                    }
                }
            }
            allowedIDs = matches
            forcedExpanded = expand
        }

        let grouped: [UUID?: [Deck]] = Dictionary(grouping: visibleDecks) { deck -> UUID? in
            guard let parentId = deck.parentId, allowedIDs.contains(parentId) else { return nil }
            return parentId
        }

        func hasVisibleChildren(_ deckId: UUID) -> Bool {
            !(grouped[deckId]?.isEmpty ?? true)
        }

        var built: [DeckRow] = []
        built.reserveCapacity(visibleDecks.count)

        var hiddenDepth: Int? = nil

        for deck in visibleDecks {
            guard allowedIDs.contains(deck.id) else { continue }
            let depth = hierarchy.depth(of: deck.id)

            if let currentHiddenDepth = hiddenDepth {
                if depth > currentHiddenDepth {
                    continue
                }
                hiddenDepth = nil
            }

            let hasChildren = hasVisibleChildren(deck.id)
            let isExpanded = !hasChildren ? false : (!collapsedDeckIDs.contains(deck.id) || forcedExpanded.contains(deck.id))
            built.append(
                DeckRow(
                    deck: deck,
                    depth: depth,
                    hasChildren: hasChildren,
                    isExpanded: isExpanded,
                    displayPath: hierarchy.displayPath(of: deck.id)
                )
            )

            if hasChildren && !isExpanded {
                hiddenDepth = depth
            }
        }

        rows = built
    }

    func reparentAndPosition(
        sourceDeck: Deck,
        newParentId: UUID?,
        anchorDeckId: UUID,
        placeBefore: Bool
    ) -> Bool {
        let visibleDecks: [Deck] = includeArchived ? allDecks : allDecks.filter { !$0.isArchived }
        let hierarchy = DeckHierarchy(decks: visibleDecks)

        guard sourceDeck.isArchived == (deck(id: anchorDeckId)?.isArchived ?? sourceDeck.isArchived) else { return false }
        guard hierarchy.canReparent(deckId: sourceDeck.id, toParentId: newParentId) else { return false }

        if sourceDeck.parentId != newParentId {
            optimisticallyUpdateDeckParent(deckId: sourceDeck.id, parentId: newParentId)
            Task { await deckService.reparent(deckId: sourceDeck.id, toParentId: newParentId) }
        }

        moveDeckInOrder(sourceID: sourceDeck.id, targetID: anchorDeckId, placeBefore: placeBefore)
        persistDeckOrder()
        return true
    }

    func moveDeckInOrder(sourceID: UUID, targetID: UUID, placeBefore: Bool) {
        guard sourceID != targetID else { return }
        var order = deckOrder
        if let fromIndex = order.firstIndex(of: sourceID) {
            order.remove(at: fromIndex)
        }
        let insertionIndex: Int
        if let targetIndex = order.firstIndex(of: targetID) {
            insertionIndex = placeBefore ? targetIndex : targetIndex + 1
        } else {
            insertionIndex = placeBefore ? 0 : order.count
        }
        order.insert(sourceID, at: min(insertionIndex, order.count))
        deckOrder = normalizeDeckOrder(storedOrder: order, decks: allDecks)
        allDecks = DeckHierarchy(decks: allDecks).preorder(usingSortOrder: deckOrder)
        rebuildRows()
    }

    func optimisticallyUpdateDeckParent(deckId: UUID, parentId: UUID?) {
        guard let index = allDecks.firstIndex(where: { $0.id == deckId }) else { return }
        var updated = allDecks[index]
        updated.parentId = parentId
        updated.updatedAt = Date()
        allDecks[index] = updated
    }

    func persistDeckOrder() {
        Task {
            do {
                var settings = try await storage.loadSettings().toDomain()
                settings.deckSortOrder = deckOrder
                try await storage.save(settings: settings.toDTO())
            } catch {
                print("DeckOrganizerViewModel.persistDeckOrder failed: \(error)")
            }
        }
    }

    func lastDeckIdInSubtree(of deckId: UUID) -> UUID? {
        let hierarchy = DeckHierarchy(decks: allDecks)
        return hierarchy.subtreeDeckIDs(of: deckId).last
    }

    func normalizeDeckOrder(storedOrder: [UUID], decks: [Deck]) -> [UUID] {
        var seen: Set<UUID> = []
        var normalized: [UUID] = []
        let deckIds = Set(decks.map(\.id))
        for id in storedOrder where deckIds.contains(id) {
            guard !seen.contains(id) else { continue }
            normalized.append(id)
            seen.insert(id)
        }
        for deck in decks where !seen.contains(deck.id) {
            normalized.append(deck.id)
            seen.insert(deck.id)
        }
        let hierarchy = DeckHierarchy(decks: decks)
        return hierarchy.preorder(usingSortOrder: normalized).map(\.id)
    }

    func persistCollapsedDeckIDs() {
        let lines = collapsedDeckIDs
            .map(\.uuidString)
            .sorted()
            .joined(separator: "\n")
        userDefaults.set(lines, forKey: collapsedDecksKey)
    }

    static func loadCollapsedDeckIDs(userDefaults: UserDefaults, key: String) -> Set<UUID> {
        let raw = userDefaults.string(forKey: key) ?? ""
        return Set(
            raw
                .split(separator: "\n")
                .compactMap { UUID(uuidString: String($0)) }
        )
    }
}
