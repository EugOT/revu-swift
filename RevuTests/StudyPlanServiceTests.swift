import Foundation
import Testing
@testable import Revu

@Suite("Study plan distribution")
struct StudyPlanServiceTests {
    @Test("Spreads new cards evenly up to the deck due date")
    func testEvenDistributionTowardDeadline() async throws {
        let deck = Deck(
            id: UUID(),
            name: "Deadline Deck",
            dueDate: Calendar.current.date(byAdding: .day, value: 9, to: Date())
        )
        let settings = UserSettings(dailyNewLimit: 20)

        let cards: [Card] = (0..<34).map { index in
            let created = Date().addingTimeInterval(TimeInterval(-index * 60))
            return Card(
                id: UUID(),
                deckId: deck.id,
                kind: .basic,
                createdAt: created,
                srs: SRSState(
                    interval: 0,
                    dueDate: created,
                    queue: .new,
                    fsrsReps: 0
                )
            )
        }

        let summary = StudyPlanService.forecastSummary(
            for: deck,
            cards: cards,
            settings: settings
        )

        let days = summary.days
        #expect(!days.isEmpty)
        let counts = days.map { $0.newCount + $0.reviewCount }
        let totalPlanned = counts.reduce(0, +)
        #expect(totalPlanned == 34)

        // Record distribution for debugging if it looks sparse.
        let zeroDays = counts.filter { $0 == 0 }.count
        if zeroDays > 2 {
            Issue.record("Sparse distribution: \(counts)")
        }
    }
}
