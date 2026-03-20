import Foundation
import Testing
@testable import Revu

@Suite("Deck hierarchy")
struct DeckHierarchyTests {
    @Test("Builds paths and descendants")
    func pathsAndDescendants() {
        let root = Deck(id: UUID(), parentId: nil, name: "Root")
        let child = Deck(id: UUID(), parentId: root.id, name: "Child")
        let grandchild = Deck(id: UUID(), parentId: child.id, name: "Grandchild")
        let hierarchy = DeckHierarchy(decks: [grandchild, root, child])

        #expect(hierarchy.displayPath(of: root.id) == "Root")
        #expect(hierarchy.displayPath(of: child.id) == "Root / Child")
        #expect(hierarchy.displayPath(of: grandchild.id) == "Root / Child / Grandchild")

        let descendants = hierarchy.descendants(of: root.id).map(\.id)
        #expect(descendants.contains(child.id))
        #expect(descendants.contains(grandchild.id))
        #expect(descendants.count == 2)
    }

    @Test("Prevents cycles on reparent")
    func preventsCycles() {
        let root = Deck(id: UUID(), parentId: nil, name: "Root")
        let child = Deck(id: UUID(), parentId: root.id, name: "Child")
        let hierarchy = DeckHierarchy(decks: [root, child])

        #expect(hierarchy.canReparent(deckId: root.id, toParentId: child.id) == false)
        #expect(hierarchy.canReparent(deckId: child.id, toParentId: root.id) == true)
        #expect(hierarchy.canReparent(deckId: child.id, toParentId: nil) == true)
    }
}

