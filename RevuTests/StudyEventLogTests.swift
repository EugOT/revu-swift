import Foundation
import Testing
@testable import Revu

@Suite("Study event log persistence")
struct StudyEventLogTests {
    @MainActor
    private func makeTempController() throws -> DataController {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = try SQLiteStorage(rootURL: url)
        return DataController(rootURL: url, storage: storage)
    }

    @Test("Appends and reads study events in chronological order")
    @MainActor
    func testAppendAndReadEvents() async throws {
        let controller = try makeTempController()
        let service = StudyEventLogService(storage: controller.storage)
        
        let sessionId = UUID()
        let now = Date()
        
        // Append sessionStarted event
        let sessionStarted = StudyEvent(
            id: UUID(),
            timestamp: now,
            sessionId: sessionId,
            kind: .sessionStarted,
            deckId: UUID(),
            queueMode: "standard"
        )
        await service.append(sessionStarted)
        
        // Append cardPresented event
        let cardPresented = StudyEvent(
            id: UUID(),
            timestamp: now.addingTimeInterval(1),
            sessionId: sessionId,
            kind: .cardPresented,
            deckId: UUID(),
            cardId: UUID(),
            queueMode: "standard"
        )
        await service.append(cardPresented)
        
        // Append cardAnswered event
        let cardAnswered = StudyEvent(
            id: UUID(),
            timestamp: now.addingTimeInterval(5),
            sessionId: sessionId,
            kind: .cardAnswered,
            deckId: UUID(),
            cardId: UUID(),
            queueMode: "standard",
            elapsedMs: 4000,
            grade: 4
        )
        await service.append(cardAnswered)
        
        // Read recent events
        let events = await service.recentEvents(limit: 10)
        
        #expect(events.count == 3)
        #expect(events[0].kind == .sessionStarted)
        #expect(events[1].kind == .cardPresented)
        #expect(events[2].kind == .cardAnswered)
        #expect(events[0].sessionId == sessionId)
        #expect(events[1].sessionId == sessionId)
        #expect(events[2].sessionId == sessionId)
        #expect(events[2].elapsedMs == 4000)
        #expect(events[2].grade == 4)
    }
    
    @Test("Recent events returns chronological order")
    @MainActor
    func testChronologicalOrder() async throws {
        let controller = try makeTempController()
        let service = StudyEventLogService(storage: controller.storage)
        
        let sessionId = UUID()
        let baseTime = Date()
        
        // Append 5 events with increasing timestamps
        for i in 0..<5 {
            let event = StudyEvent(
                id: UUID(),
                timestamp: baseTime.addingTimeInterval(Double(i)),
                sessionId: sessionId,
                kind: .cardPresented,
                cardId: UUID()
            )
            await service.append(event)
        }
        
        let events = await service.recentEvents(limit: 10)
        
        #expect(events.count == 5)
        // Verify chronological order (oldest first)
        for i in 0..<4 {
            #expect(events[i].timestamp <= events[i + 1].timestamp)
        }
    }
    
    @Test("Limit parameter restricts number of events returned")
    @MainActor
    func testLimitParameter() async throws {
        let controller = try makeTempController()
        let service = StudyEventLogService(storage: controller.storage)

        let sessionId = UUID()
        // Use a fixed reference date to avoid floating-point precision issues
        // when round-tripping through SQLite REAL storage.
        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)

        // Append 10 events with well-separated timestamps (10s apart)
        for i in 0..<10 {
            let event = StudyEvent(
                id: UUID(),
                timestamp: baseTime.addingTimeInterval(Double(i) * 10),
                sessionId: sessionId,
                kind: .cardPresented,
                cardId: UUID()
            )
            await service.append(event)
        }

        // Request only last 3 events
        let limitedEvents = await service.recentEvents(limit: 3)

        #expect(limitedEvents.count == 3)

        // Read all events to verify the limited set matches the 3 most recent
        let allEvents = await service.recentEvents(limit: 100)
        #expect(allEvents.count == 10)

        // The limited events should be the last 3 from the full list
        let expectedSlice = Array(allEvents.suffix(3))
        for i in 0..<3 {
            #expect(limitedEvents[i].id == expectedSlice[i].id)
        }
    }

    @Test("Persists extended engagement telemetry fields")
    @MainActor
    func testExtendedTelemetryPersistence() async throws {
        let controller = try makeTempController()
        let service = StudyEventLogService(storage: controller.storage)

        let sessionId = UUID()
        let event = StudyEvent(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            sessionId: sessionId,
            kind: .nudgeOffered,
            deckId: UUID(),
            cardId: UUID(),
            queueMode: "standard",
            adaptiveSuccessRate: 0.71,
            adaptiveTargetPSuccess: 0.7,
            adaptiveChosenPSuccess: 0.66,
            xpAmount: 25,
            xpReason: "hard_card",
            streakAtAward: 4,
            celebrationType: "streak",
            threshold: 3,
            intensity: "balanced",
            nudgeType: "hard_mode",
            nudgeScore: 0.84,
            source: "proactive",
            cooldownRemainingSec: 120,
            nudgeActionValue: "accepted",
            hintLevel: 2,
            entryPoint: "inline",
            challengeModeActionValue: "enabled",
            predictedRecallBucket: "medium",
            badgeId: "first_streak",
            badgeTier: "bronze",
            progressBefore: 0.2,
            progressAfter: 0.5,
            conceptCount: 3,
            wasSuccessful: true
        )

        await service.append(event)
        let events = await service.recentEvents(limit: 10)
        #expect(events.count == 1)

        let persisted = events[0]
        #expect(persisted.kind == .nudgeOffered)
        #expect(persisted.adaptiveSuccessRate == 0.71)
        #expect(persisted.adaptiveTargetPSuccess == 0.7)
        #expect(persisted.adaptiveChosenPSuccess == 0.66)
        #expect(persisted.xpAmount == 25)
        #expect(persisted.xpReason == "hard_card")
        #expect(persisted.streakAtAward == 4)
        #expect(persisted.celebrationType == "streak")
        #expect(persisted.threshold == 3)
        #expect(persisted.intensity == "balanced")
        #expect(persisted.nudgeType == "hard_mode")
        #expect(persisted.nudgeScore == 0.84)
        #expect(persisted.source == "proactive")
        #expect(persisted.cooldownRemainingSec == 120)
        #expect(persisted.nudgeActionValue == "accepted")
        #expect(persisted.hintLevel == 2)
        #expect(persisted.entryPoint == "inline")
        #expect(persisted.challengeModeActionValue == "enabled")
        #expect(persisted.predictedRecallBucket == "medium")
        #expect(persisted.badgeId == "first_streak")
        #expect(persisted.badgeTier == "bronze")
        #expect(persisted.progressBefore == 0.2)
        #expect(persisted.progressAfter == 0.5)
        #expect(persisted.conceptCount == 3)
        #expect(persisted.wasSuccessful == true)
    }
}
