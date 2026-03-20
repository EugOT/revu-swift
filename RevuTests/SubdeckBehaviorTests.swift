import Foundation
import Testing
@testable import Revu

@Suite("Subdeck behaviour")
struct SubdeckBehaviorTests {
    @MainActor
    private func makeTempController() throws -> DataController {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = try SQLiteStorage(rootURL: url)
        return DataController(rootURL: url, storage: storage)
    }

    @Test("Study session on parent deck includes subdeck cards")
    @MainActor
    func studySessionIncludesSubdeckCards() async throws {
        let controller = try makeTempController()
        let storage = controller.storage

        let parent = Deck(name: "Parent")
        let child = Deck(parentId: parent.id, name: "Child")
        try await storage.upsert(deck: parent.toDTO())
        try await storage.upsert(deck: child.toDTO())

        let now = Date()
        for index in 0..<6 {
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
                deckId: child.id,
                kind: .basic,
                front: "Q\(index)",
                back: "A",
                srs: state
            )
            try await storage.upsert(card: card.toDTO())
        }

        let viewModel = StudySessionViewModel(deck: parent, mode: .dueToday, dataController: controller)
        try await Task.sleep(nanoseconds: 500_000_000)

        let loadedCount = viewModel.queue.count + (viewModel.currentCard != nil ? 1 : 0)
        #expect(loadedCount == 6)
    }

    @Test("Study plan for parent deck includes subdeck cards")
    @MainActor
    func studyPlanIncludesSubdeckCards() async throws {
        let controller = try makeTempController()
        let storage = controller.storage

        let parent = Deck(name: "Parent")
        let child = Deck(parentId: parent.id, name: "Child")
        try await storage.upsert(deck: parent.toDTO())
        try await storage.upsert(deck: child.toDTO())

        for index in 0..<4 {
            var state = SRSState(dueDate: Date().addingTimeInterval(-Double(index + 1) * 60))
            state.cardId = UUID()
            let card = Card(
                id: state.cardId,
                deckId: child.id,
                kind: .basic,
                front: "Q\(index)",
                back: "A",
                srs: state
            )
            try await storage.upsert(card: card.toDTO())
        }

        let planner = StudyPlanService(storage: storage)
        let summary = await planner.forecastDeckPlan(forDeckId: parent.id, dueDate: nil)
        #expect(summary.totalCards == 4)
    }
}

