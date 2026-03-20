#if DEBUG
import SwiftUI

@MainActor
enum RevuPreviewData {
    static func seed(storage: Storage) async {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let math = Deck(name: "Math", note: "Linear algebra")
        let algebra = Deck(parentId: math.id, name: "Algebra", note: "Groups • Rings • Fields")
        let languages = Deck(name: "Languages", note: "Daily review")
        let archived = Deck(name: "Old Notes", note: "Archived deck", isArchived: true)

        do {
            try await storage.upsert(deck: math.toDTO())
            try await storage.upsert(deck: algebra.toDTO())
            try await storage.upsert(deck: languages.toDTO())
            try await storage.upsert(deck: archived.toDTO())

            var overdue = Card(deckId: math.id, kind: .basic, front: "Define a vector space", back: "...")
            overdue.srs.queue = .review
            overdue.srs.dueDate = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
            overdue.tags = ["math", "linear-algebra"]

            var dueToday = Card(deckId: algebra.id, kind: .basic, front: "What is a group?", back: "...")
            dueToday.srs.queue = .review
            dueToday.srs.dueDate = calendar.date(byAdding: .hour, value: 2, to: startOfDay) ?? now
            dueToday.tags = ["math", "algebra"]

            var dueSoon = Card(deckId: languages.id, kind: .basic, front: "Hola → ?", back: "Hello")
            dueSoon.srs.queue = .review
            dueSoon.srs.dueDate = calendar.date(byAdding: .day, value: 2, to: startOfDay) ?? now
            dueSoon.tags = ["language", "spanish"]

            var newCard = Card(deckId: languages.id, kind: .basic, front: "Merci → ?", back: "Thank you")
            newCard.srs.queue = .new
            newCard.tags = ["language", "french"]

            var archivedCard = Card(deckId: archived.id, kind: .basic, front: "Archived front", back: "Archived back")
            archivedCard.srs.queue = .review
            archivedCard.srs.dueDate = calendar.date(byAdding: .day, value: -3, to: startOfDay) ?? startOfDay
            archivedCard.tags = ["archive"]

            try await storage.upsert(card: overdue.toDTO())
            try await storage.upsert(card: dueToday.toDTO())
            try await storage.upsert(card: dueSoon.toDTO())
            try await storage.upsert(card: newCard.toDTO())
            try await storage.upsert(card: archivedCard.toDTO())

            for offset in 0..<7 {
                let timestamp = calendar.date(byAdding: .day, value: -offset, to: startOfDay) ?? startOfDay
                let log = ReviewLog(
                    cardId: overdue.id,
                    timestamp: timestamp.addingTimeInterval(TimeInterval(Int.random(in: 60...240))),
                    grade: [2, 3, 4].randomElement() ?? 3,
                    elapsedMs: Int.random(in: 1200...9000),
                    prevInterval: Int.random(in: 0...4),
                    nextInterval: Int.random(in: 2...12),
                    prevEase: 2.3,
                    nextEase: 2.35,
                    prevStability: 0.8,
                    nextStability: 0.95,
                    prevDifficulty: 5.0,
                    nextDifficulty: 4.8,
                    predictedRecall: 0.78,
                    requestedRetention: 0.85
                )
                try await storage.append(log: log.toDTO())
            }
        } catch {
            // Best-effort seeding for previews.
        }
    }
}

@MainActor
struct RevuPreviewHost<Content: View>: View {
    let controller: DataController

    @StateObject private var commandCenter: WorkspaceCommandCenter
    @StateObject private var workspaceSelection: WorkspaceSelection
    @StateObject private var workspacePreferences: WorkspacePreferences

    private let content: (DataController) -> Content

    init(seed: Bool = true, content: @escaping (DataController) -> Content) {
        let controller = DataController.previewController()
        self.controller = controller
        self.content = content

        let workspaceDefaults = UserDefaults(suiteName: "com.revu.preview.workspace") ?? .standard

        _commandCenter = StateObject(wrappedValue: WorkspaceCommandCenter())
        _workspaceSelection = StateObject(wrappedValue: WorkspaceSelection())
        _workspacePreferences = StateObject(wrappedValue: WorkspacePreferences(userDefaults: workspaceDefaults))

        if seed {
            Task { @MainActor in
                await RevuPreviewData.seed(storage: controller.storage)
                controller.events.notify()
            }
        }
    }

    var body: some View {
        content(controller)
            .environment(\.storage, controller.storage)
            .environmentObject(controller.events)
            .environmentObject(commandCenter)
            .environmentObject(workspaceSelection)
            .environmentObject(workspacePreferences)
    }
}

#endif
