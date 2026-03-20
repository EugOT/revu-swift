import Foundation

struct DeckHierarchy: Sendable {
    private let decksById: [UUID: Deck]
    private let childrenByParentId: [UUID?: [UUID]]
    private let roots: [UUID]

    init(decks: [Deck]) {
        let decksById = Dictionary(uniqueKeysWithValues: decks.map { ($0.id, $0) })

        var accumulator: [UUID?: [UUID]] = [:]
        accumulator[nil] = []

        for deck in decks {
            let parentId = deck.parentId.flatMap { decksById[$0] == nil ? nil : $0 }
            accumulator[parentId, default: []].append(deck.id)
        }

        for (parent, children) in accumulator {
            accumulator[parent] = children.sorted { lhs, rhs in
                let left = decksById[lhs]?.name ?? ""
                let right = decksById[rhs]?.name ?? ""
                return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
            }
        }

        self.decksById = decksById
        self.childrenByParentId = accumulator
        self.roots = accumulator[nil] ?? []
    }

    func deck(id: UUID) -> Deck? { decksById[id] }

    func rootDeckIDs() -> [UUID] { roots }

    func children(of deckId: UUID?) -> [Deck] {
        (childrenByParentId[deckId] ?? []).compactMap { decksById[$0] }
    }

    func descendants(of deckId: UUID) -> [Deck] {
        var ordered: [Deck] = []
        var stack: [UUID] = (childrenByParentId[deckId] ?? []).reversed()
        var seen: Set<UUID> = []

        while let next = stack.popLast() {
            guard let deck = decksById[next] else { continue }
            guard seen.insert(deck.id).inserted else { continue }
            ordered.append(deck)
            let children = childrenByParentId[deck.id] ?? []
            for child in children.reversed() {
                stack.append(child)
            }
        }

        return ordered
    }

    func subtreeDeckIDs(of deckId: UUID) -> [UUID] {
        [deckId] + descendants(of: deckId).map(\.id)
    }

    func ancestors(of deckId: UUID) -> [Deck] {
        var ordered: [Deck] = []
        var current = decksById[deckId]?.parentId
        var seen: Set<UUID> = [deckId]

        while let id = current, let deck = decksById[id] {
            guard seen.insert(id).inserted else { break }
            ordered.append(deck)
            current = deck.parentId
        }

        return ordered.reversed()
    }

    func pathComponents(of deckId: UUID) -> [String] {
        let chain = ancestors(of: deckId).map(\.name)
        let own = decksById[deckId]?.name ?? ""
        return chain + [own]
    }

    func displayPath(of deckId: UUID, separator: String = " / ") -> String {
        pathComponents(of: deckId)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }

    func depth(of deckId: UUID) -> Int {
        ancestors(of: deckId).count
    }

    func canReparent(deckId: UUID, toParentId proposedParentId: UUID?) -> Bool {
        guard proposedParentId != deckId else { return false }
        guard let proposedParentId else { return true }
        guard decksById[deckId] != nil else { return false }
        guard decksById[proposedParentId] != nil else { return false }

        var current: UUID? = proposedParentId
        var seen: Set<UUID> = [deckId]
        while let id = current, let deck = decksById[id] {
            guard seen.insert(id).inserted else { return false }
            if deck.parentId == deckId { return false }
            current = deck.parentId
        }
        return true
    }

    func preorder(
        usingSortOrder sortOrder: [UUID]
    ) -> [Deck] {
        let positions = sortOrder.enumerated().reduce(into: [UUID: Int]()) { result, entry in
            result[entry.element] = entry.offset
        }

        func orderedChildren(parentId: UUID?) -> [UUID] {
            let ids = childrenByParentId[parentId] ?? []
            return ids.sorted { lhs, rhs in
                let l = positions[lhs] ?? Int.max
                let r = positions[rhs] ?? Int.max
                if l == r {
                    let left = decksById[lhs]?.name ?? ""
                    let right = decksById[rhs]?.name ?? ""
                    return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                }
                return l < r
            }
        }

        var result: [Deck] = []
        var stack: [UUID] = orderedChildren(parentId: nil).reversed()
        var seen: Set<UUID> = []

        while let next = stack.popLast() {
            guard let deck = decksById[next] else { continue }
            guard seen.insert(deck.id).inserted else { continue }
            result.append(deck)
            let kids = orderedChildren(parentId: deck.id)
            for id in kids.reversed() {
                stack.append(id)
            }
        }

        return result
    }

    func preorder(sortedByName ascending: Bool) -> [Deck] {
        func orderedChildren(parentId: UUID?) -> [UUID] {
            let ids = childrenByParentId[parentId] ?? []
            return ids.sorted { lhs, rhs in
                let left = decksById[lhs]?.name ?? ""
                let right = decksById[rhs]?.name ?? ""
                let comparison = left.localizedCaseInsensitiveCompare(right)
                return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
            }
        }

        var result: [Deck] = []
        var stack: [UUID] = orderedChildren(parentId: nil).reversed()
        var seen: Set<UUID> = []

        while let next = stack.popLast() {
            guard let deck = decksById[next] else { continue }
            guard seen.insert(deck.id).inserted else { continue }
            result.append(deck)
            let kids = orderedChildren(parentId: deck.id)
            for id in kids.reversed() {
                stack.append(id)
            }
        }

        return result
    }

    func preorder(sortedByModified ascending: Bool) -> [Deck] {
        func orderedChildren(parentId: UUID?) -> [UUID] {
            let ids = childrenByParentId[parentId] ?? []
            return ids.sorted { lhs, rhs in
                let left = decksById[lhs]?.updatedAt ?? Date.distantPast
                let right = decksById[rhs]?.updatedAt ?? Date.distantPast
                return ascending ? left < right : left > right
            }
        }

        var result: [Deck] = []
        var stack: [UUID] = orderedChildren(parentId: nil).reversed()
        var seen: Set<UUID> = []

        while let next = stack.popLast() {
            guard let deck = decksById[next] else { continue }
            guard seen.insert(deck.id).inserted else { continue }
            result.append(deck)
            let kids = orderedChildren(parentId: deck.id)
            for id in kids.reversed() {
                stack.append(id)
            }
        }

        return result
    }

    func preorder(sortedByCreated ascending: Bool) -> [Deck] {
        func orderedChildren(parentId: UUID?) -> [UUID] {
            let ids = childrenByParentId[parentId] ?? []
            return ids.sorted { lhs, rhs in
                let left = decksById[lhs]?.createdAt ?? Date.distantPast
                let right = decksById[rhs]?.createdAt ?? Date.distantPast
                return ascending ? left < right : left > right
            }
        }

        var result: [Deck] = []
        var stack: [UUID] = orderedChildren(parentId: nil).reversed()
        var seen: Set<UUID> = []

        while let next = stack.popLast() {
            guard let deck = decksById[next] else { continue }
            guard seen.insert(deck.id).inserted else { continue }
            result.append(deck)
            let kids = orderedChildren(parentId: deck.id)
            for id in kids.reversed() {
                stack.append(id)
            }
        }

        return result
    }
}
