import Foundation
import Testing
@testable import Revu

@Suite("Deck organizer view model")
struct DeckOrganizerViewModelTests {
    @MainActor
    private func makeTempController() throws -> DataController {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = try SQLiteStorage(rootURL: url)
        return DataController(rootURL: url, storage: storage)
    }

    @Test("Builds rows, supports collapse + search, rolls up snapshots")
    @MainActor
    func rowsCollapseSearchAndSnapshots() async throws {
        let controller = try makeTempController()
        let storage = controller.storage

        let root = Deck(name: "Root")
        let child = Deck(parentId: root.id, name: "Child")
        try await storage.upsert(deck: root.toDTO())
        try await storage.upsert(deck: child.toDTO())

        // Use a due date clearly before start-of-day so the card is always "overdue"
        // regardless of what time of day the test runs.
        let yesterday = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-1)
        var state = SRSState(
            interval: 2,
            repetitions: 3,
            lapses: 0,
            dueDate: yesterday,
            lastReviewed: Date().addingTimeInterval(-86_400),
            queue: .review,
            stability: 6,
            difficulty: 5,
            fsrsReps: 3
        )
        state.cardId = UUID()
        let card = Card(
            id: state.cardId,
            deckId: child.id,
            kind: .basic,
            front: "Q",
            back: "A",
            srs: state
        )
        try await storage.upsert(card: card.toDTO())

        let defaultsSuite = "tests.deckOrganizer.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }

        let viewModel = DeckOrganizerViewModel(
            storage: storage,
            userDefaults: defaults,
            collapsedDecksKey: "collapsed"
        )

        await viewModel.refreshNow()

        #expect(viewModel.rows.count == 2)
        #expect(viewModel.rows.first?.deck.id == root.id)
        #expect(viewModel.rows.first?.depth == 0)
        #expect(viewModel.rows.last?.deck.id == child.id)
        #expect(viewModel.rows.last?.depth == 1)

        let rootSnapshot = viewModel.snapshots[root.id]
        #expect(rootSnapshot?.total == 1)
        #expect(rootSnapshot?.overdue == 1)
        #expect(rootSnapshot?.dueTotal == 1)

        viewModel.toggleExpanded(root.id)
        #expect(viewModel.rows.count == 1)
        #expect(viewModel.rows.first?.deck.id == root.id)

        viewModel.searchText = "Child"
        #expect(viewModel.rows.contains(where: { $0.deck.id == child.id }))
    }
}
