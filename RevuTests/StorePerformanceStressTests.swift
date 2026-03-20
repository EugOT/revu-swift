import Foundation
import Testing
@testable import Revu

@Suite("Store performance (stress)")
struct StorePerformanceStressTests {
    @Test("smoke: replaceAll + cold start + query performance")
    func testStorePerformance_smoke() async throws {
        let config = StressConfig.smoke
        try await runScenario(config: config)
    }

    @Test("stress: replaceAll + cold start + query performance (opt-in via REVU_RUN_STORE_STRESS=1)")
    func testStorePerformance_fullStress() async throws {
        guard StressConfig.shouldRunFullStress else {
            print("Skipping full stress test; set REVU_RUN_STORE_STRESS=1 to enable.")
            return
        }
        let config = StressConfig.full
        try await runScenario(config: config)
    }

    @Test("smoke: batched upserts are faster than unbatched")
    func testUpsertBatchingMatters_smoke() async throws {
        let config = StressConfig(
            deckCount: 1,
            cardCount: 400,
            logCount: 0,
            queryIterations: 1,
            dueLimit: 50,
            searchDeckScoped: false
        )

        let rootA = makeTempRoot()
        let storageA = try await MainActor.run { try SQLiteStorage(rootURL: rootA) }
        let dataset = Dataset.make(deckCount: config.deckCount, cardCount: config.cardCount, logCount: 0)

        let (_, unbatched) = try await measure("unbatched upserts") {
            for deck in dataset.decks {
                try await storageA.upsert(deck: deck)
            }
            for card in dataset.cards {
                try await storageA.upsert(card: card)
            }
        }

        let rootB = makeTempRoot()
        let storageB = try await MainActor.run { try SQLiteStorage(rootURL: rootB) }

        let (_, batched) = try await measure("batched upserts") {
            try await storageB.withBatchUpdates {
                for deck in dataset.decks {
                    try await storageB.upsert(deck: deck)
                }
                for card in dataset.cards {
                    try await storageB.upsert(card: card)
                }
            }
        }

        print("upserts: unbatched=\(format(unbatched)), batched=\(format(batched))")
        #expect(durationSeconds(batched) <= durationSeconds(unbatched))
    }
}

// MARK: - Scenario runner

private extension StorePerformanceStressTests {
    func runScenario(config: StressConfig) async throws {
        let root = makeTempRoot()
        let storage = try await MainActor.run { try SQLiteStorage(rootURL: root) }

        let dataset = Dataset.make(deckCount: config.deckCount, cardCount: config.cardCount, logCount: config.logCount)
        let dueCutoff = dataset.now

        let (_, replaceAllDuration) = try await measure("replaceAll") {
            try await storage.withBatchUpdates {
                for deck in dataset.decks {
                    try await storage.upsert(deck: deck)
                }
                for card in dataset.cards {
                    try await storage.upsert(card: card)
                }
                for log in dataset.logs {
                    try await storage.append(log: log)
                }
            }
        }

        let cardsURL = root.appendingPathComponent("cards.json")
        let decksURL = root.appendingPathComponent("decks.json")
        let logsURL = root.appendingPathComponent("review_log.jsonl")
        let cardsBytes = (try? fileSizeBytes(cardsURL)) ?? 0
        let decksBytes = (try? fileSizeBytes(decksURL)) ?? 0
        let logsBytes = (try? fileSizeBytes(logsURL)) ?? 0

        print("dataset: decks=\(dataset.decks.count), cards=\(dataset.cards.count), logs=\(dataset.logs.count)")
        print("disk: cards.json=\(formatBytes(cardsBytes)), decks.json=\(formatBytes(decksBytes)), review_log.jsonl=\(formatBytes(logsBytes))")
        print("replaceAll: \(format(replaceAllDuration))")

        let (reloadedStorage, coldStartDuration) = try await measure("cold start init") {
            try await MainActor.run { try SQLiteStorage(rootURL: root) }
        }
        print("cold start init: \(format(coldStartDuration))")

        let reloadedDecks = try await reloadedStorage.allDecks()
        let reloadedCards = try await reloadedStorage.allCards()
        #expect(reloadedDecks.count == dataset.decks.count)
        #expect(reloadedCards.count == dataset.cards.count)

        let (_, dueDuration) = try await measure("dueCards (x\(config.queryIterations))") {
            for _ in 0..<config.queryIterations {
                _ = try await reloadedStorage.dueCards(on: dueCutoff, limit: config.dueLimit)
            }
        }

        let (_, newDuration) = try await measure("newCards (x\(config.queryIterations))") {
            for _ in 0..<config.queryIterations {
                _ = try await reloadedStorage.newCards(limit: config.dueLimit)
            }
        }

        let searchText = "concept"
        let searchTags: Set<String> = [dataset.tagToSearch]
        let searchDeckId: UUID? = config.searchDeckScoped ? dataset.decks.first?.id : nil
        let (_, searchDuration) = try await measure("searchCards (x\(config.queryIterations))") {
            for _ in 0..<config.queryIterations {
                _ = try await reloadedStorage.searchCards(text: searchText, tags: searchTags, deckId: searchDeckId)
            }
        }

        var recentLogsAvgMs: Double? = nil
        if dataset.logs.isEmpty == false {
            let (_, recentLogsDuration) = try await measure("recentLogs (x\(config.queryIterations))") {
                for _ in 0..<config.queryIterations {
                    _ = try await reloadedStorage.recentLogs(limit: config.dueLimit)
                }
            }
            recentLogsAvgMs = durationSeconds(recentLogsDuration) * 1000.0 / Double(max(1, config.queryIterations))
        }

        let dueAvgMs = durationSeconds(dueDuration) * 1000.0 / Double(max(1, config.queryIterations))
        let newAvgMs = durationSeconds(newDuration) * 1000.0 / Double(max(1, config.queryIterations))
        let searchAvgMs = durationSeconds(searchDuration) * 1000.0 / Double(max(1, config.queryIterations))

        if let recentLogsAvgMs {
            print("query avg (ms): due=\(String(format: "%.2f", dueAvgMs)), new=\(String(format: "%.2f", newAvgMs)), search=\(String(format: "%.2f", searchAvgMs)), logs=\(String(format: "%.2f", recentLogsAvgMs))")
        } else {
            print("query avg (ms): due=\(String(format: "%.2f", dueAvgMs)), new=\(String(format: "%.2f", newAvgMs)), search=\(String(format: "%.2f", searchAvgMs))")
        }

        // These thresholds are intentionally generous: they only catch catastrophic regressions.
        #expect(durationSeconds(replaceAllDuration) < config.maxReplaceAllSeconds)
        #expect(durationSeconds(coldStartDuration) < config.maxColdStartSeconds)
        #expect(dueAvgMs < config.maxAvgQueryMs)
        #expect(newAvgMs < config.maxAvgQueryMs)
        #expect(searchAvgMs < config.maxAvgQueryMs)
        if let recentLogsAvgMs {
            #expect(recentLogsAvgMs < config.maxAvgQueryMs)
        }
    }
}

// MARK: - Dataset

private struct Dataset: Sendable {
    let now: Date
    let decks: [DeckDTO]
    let cards: [CardDTO]
    let logs: [ReviewLogDTO]
    let tagToSearch: String

    static func make(deckCount: Int, cardCount: Int, logCount: Int) -> Dataset {
        let now = Date(timeIntervalSince1970: 1_700_000_000) // stable baseline

        var decks: [DeckDTO] = []
        decks.reserveCapacity(deckCount)
        for i in 0..<deckCount {
            let deck = Deck(name: "Deck \(i)")
            decks.append(deck.toDTO())
        }

        let tagPool = max(10, min(250, cardCount / 40))
        let tagToSearch = "tag0"

        var cards: [CardDTO] = []
        cards.reserveCapacity(cardCount)

        let deckIds = decks.map(\.id)
        for i in 0..<cardCount {
            let deckId = deckIds.isEmpty ? nil : deckIds[i % deckIds.count]
            var card = Card(
                deckId: deckId,
                kind: .basic,
                front: "Concept \(i): What is the definition of concept \(i)?",
                back: "Definition \(i): This is a placeholder answer for concept \(i)."
            )

            card.tags = [
                "tag\(i % tagPool)",
                "tag\((i &+ 7) % tagPool)",
                "tag\((i &+ 13) % tagPool)",
            ]

            // Roughly: 30% new, 70% review; due dates spread over ~60 days.
            if i % 10 < 3 {
                card.srs.queue = .new
                card.srs.dueDate = now
            } else {
                card.srs.queue = .review
                let daysOffset = Double(i % 60)
                card.srs.dueDate = now.addingTimeInterval(-daysOffset * 86_400.0)
            }

            cards.append(card.toDTO())
        }

        var logs: [ReviewLogDTO] = []
        logs.reserveCapacity(logCount)
        if logCount > 0, let firstCard = cards.first {
            let cardIds = cards.map(\.id)
            for i in 0..<logCount {
                let cardId = cardIds[i % cardIds.count]
                logs.append(
                    ReviewLogDTO(
                        id: UUID(),
                        cardId: cardId,
                        timestamp: now.addingTimeInterval(-Double(i)),
                        grade: (i % 4) + 1,
                        elapsedMs: 1_200,
                        prevInterval: 1,
                        nextInterval: 2,
                        prevEase: 2.5,
                        nextEase: 2.5,
                        prevStability: 0.6,
                        nextStability: 0.6,
                        prevDifficulty: 5.0,
                        nextDifficulty: 5.0,
                        predictedRecall: 0.9,
                        requestedRetention: 0.9
                    )
                )
            }

            // Touch to avoid "unused" in some build configs.
            _ = firstCard
        }

        return Dataset(now: now, decks: decks, cards: cards, logs: logs, tagToSearch: tagToSearch)
    }
}

// MARK: - Config + helpers

private struct StressConfig: Sendable {
    let deckCount: Int
    let cardCount: Int
    let logCount: Int
    let queryIterations: Int
    let dueLimit: Int
    let searchDeckScoped: Bool

    let maxReplaceAllSeconds: Double
    let maxColdStartSeconds: Double
    let maxAvgQueryMs: Double

    init(
        deckCount: Int,
        cardCount: Int,
        logCount: Int,
        queryIterations: Int,
        dueLimit: Int,
        searchDeckScoped: Bool,
        maxReplaceAllSeconds: Double = 20.0,
        maxColdStartSeconds: Double = 20.0,
        maxAvgQueryMs: Double = 500.0
    ) {
        self.deckCount = deckCount
        self.cardCount = cardCount
        self.logCount = logCount
        self.queryIterations = queryIterations
        self.dueLimit = dueLimit
        self.searchDeckScoped = searchDeckScoped
        self.maxReplaceAllSeconds = maxReplaceAllSeconds
        self.maxColdStartSeconds = maxColdStartSeconds
        self.maxAvgQueryMs = maxAvgQueryMs
    }

    static var smoke: StressConfig {
        StressConfig(
            deckCount: 50,
            cardCount: 5_000,
            logCount: 5_000,
            queryIterations: 25,
            dueLimit: 200,
            searchDeckScoped: false,
            maxReplaceAllSeconds: 15.0,
            maxColdStartSeconds: 15.0,
            maxAvgQueryMs: 250.0
        )
    }

    static var full: StressConfig {
        let env = ProcessInfo.processInfo.environment
        let scale = max(1, min(20, Int(env["REVU_STORE_STRESS_SCALE"] ?? "") ?? 1))
        return StressConfig(
            deckCount: 200 * scale,
            cardCount: 50_000 * scale,
            logCount: 25_000 * scale,
            queryIterations: 50,
            dueLimit: 250,
            searchDeckScoped: false,
            maxReplaceAllSeconds: 60.0 * Double(scale),
            maxColdStartSeconds: 60.0 * Double(scale),
            maxAvgQueryMs: 1_500.0 * Double(scale)
        )
    }

    static var shouldRunFullStress: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["REVU_RUN_STORE_STRESS"] == "1" || env["REVU_RUN_STORE_STRESS"]?.lowercased() == "true"
    }
}

private func makeTempRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("revu-store-perf-\(UUID().uuidString)", isDirectory: true)
}

private func fileSizeBytes(_ url: URL) throws -> Int64 {
    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attrs[.size] as? NSNumber)?.int64Value ?? 0
}

private func formatBytes(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB"]
    var value = Double(bytes)
    var unit = 0
    while value >= 1024.0, unit < units.count - 1 {
        value /= 1024.0
        unit += 1
    }
    return String(format: "%.2f%@", value, units[unit])
}

private func durationSeconds(_ duration: Duration) -> Double {
    let c = duration.components
    return Double(c.seconds) + Double(c.attoseconds) / 1e18
}

private func format(_ duration: Duration) -> String {
    let seconds = durationSeconds(duration)
    if seconds < 1.0 {
        return String(format: "%.0fms", seconds * 1000.0)
    }
    return String(format: "%.2fs", seconds)
}

private func measure<T>(_ label: String, operation: () async throws -> T) async rethrows -> (T, Duration) {
    let clock = ContinuousClock()
    let start = clock.now
    let value = try await operation()
    let duration = start.duration(to: clock.now)
    print("\(label): \(format(duration))")
    return (value, duration)
}
