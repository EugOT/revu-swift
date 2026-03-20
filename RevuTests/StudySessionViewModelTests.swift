import Foundation
import Testing
@testable import Revu

@Suite("Study session queue loading")
struct StudySessionViewModelTests {
    @MainActor
    private func makeTempController() throws -> DataController {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = try SQLiteStorage(rootURL: url)
        return DataController(rootURL: url, storage: storage)
    }

    @Test("Loads all due cards even when daily review limit is low")
    @MainActor
    func testLoadsAllDueCardsIgnoringDailyLimit() async throws {
        let controller = try makeTempController()
        let storage = controller.storage
        let deck = Deck(name: "Deck A")
        try await storage.upsert(deck: deck.toDTO())

        var limitedSettings = UserSettings(dailyReviewLimit: 3)
        try await storage.save(settings: limitedSettings.toDTO())

        let now = Date()
        for index in 0..<10 {
            var state = SRSState(
                interval: 1,
                dueDate: now.addingTimeInterval(-Double(index + 1) * 60),
                lastReviewed: now.addingTimeInterval(-Double(index + 1) * 86_400),
                queue: .review,
                stability: 5,
                difficulty: 5,
                fsrsReps: 3
            )
            state.cardId = UUID()
            let card = Card(
                id: state.cardId,
                deckId: deck.id,
                kind: .basic,
                front: "Q\(index)",
                back: "A",
                srs: state
            )
            try await storage.upsert(card: card.toDTO())
        }

        let viewModel = StudySessionViewModel(deck: deck, mode: .dueToday, dataController: controller)

        // Allow bootstrap/loadQueue to complete
        try await Task.sleep(nanoseconds: 500_000_000)

        let loadedCount = viewModel.queue.count + (viewModel.currentCard != nil ? 1 : 0)
        #expect(loadedCount == 10)
        #expect(viewModel.isFinished == false)
    }

    @Test("Study ahead does not reduce the scheduled queue size")
    @MainActor
    func testLoadAheadKeepsAllDue() async throws {
        let controller = try makeTempController()
        let storage = controller.storage
        let deck = Deck(name: "Deck B")
        try await storage.upsert(deck: deck.toDTO())
        try await storage.save(settings: UserSettings(dailyReviewLimit: 5).toDTO())

        let now = Date()
        for index in 0..<8 {
            var state = SRSState(
                interval: 2,
                dueDate: now.addingTimeInterval(-Double(index + 1) * 120),
                lastReviewed: now.addingTimeInterval(-Double(index + 2) * 86_400),
                queue: .review,
                stability: 6,
                difficulty: 4.5,
                fsrsReps: 4
            )
            state.cardId = UUID()
            let card = Card(
                id: state.cardId,
                deckId: deck.id,
                kind: .basic,
                front: "Ahead \(index)",
                back: "A",
                srs: state
            )
            try await storage.upsert(card: card.toDTO())
        }

        let viewModel = StudySessionViewModel(deck: deck, mode: .dueToday, dataController: controller)
        try await Task.sleep(nanoseconds: 400_000_000)
        await viewModel.loadAheadQueue()
        try await Task.sleep(nanoseconds: 400_000_000)

        let loadedCount = viewModel.queue.count + (viewModel.currentCard != nil ? 1 : 0)
        #expect(loadedCount == 8)
        #expect(viewModel.queueMode == .ahead)
    }
}
