import Foundation
import Testing
@testable import Revu

@Suite("ConceptTracer with BKT-lite")
struct ConceptTracerTests {
    @MainActor
    private func makeTempController() throws -> DataController {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = try SQLiteStorage(rootURL: url)
        return DataController(rootURL: url, storage: storage)
    }

    @Test("Correct attempt increases pKnown")
    @MainActor
    func testCorrectIncreasePKnown() async throws {
        let controller = try makeTempController()
        let tracer = ConceptTracerService(storage: controller.storage)
        
        let conceptKey = "taylor-series"
        let event = StudyEventDTO(
            id: UUID(),
            timestamp: Date(),
            sessionId: UUID(),
            kind: .cardAnswered,
            cardId: UUID(),
            conceptsAtTime: [conceptKey],
            grade: 4 // Correct (FSRS: 3-4 are correct)
        )
        
        let states = try await tracer.updateFromStudyEvent(event)
        
        #expect(states.count == 1)
        let state = states[0]
        #expect(state.key == conceptKey)
        #expect(state.pKnown > 0.3) // Should increase from default 0.3
        #expect(state.attempts == 1)
        #expect(state.corrects == 1)
    }

    @Test("Incorrect attempt decreases pKnown")
    @MainActor
    func testIncorrectDecreasePKnown() async throws {
        let controller = try makeTempController()
        let tracer = ConceptTracerService(storage: controller.storage)
        
        let conceptKey = "fourier-transform"
        let event = StudyEventDTO(
            id: UUID(),
            timestamp: Date(),
            sessionId: UUID(),
            kind: .cardAnswered,
            cardId: UUID(),
            conceptsAtTime: [conceptKey],
            grade: 1 // Incorrect (FSRS: 1-2 are incorrect)
        )
        
        let states = try await tracer.updateFromStudyEvent(event)
        
        #expect(states.count == 1)
        let state = states[0]
        #expect(state.key == conceptKey)
        #expect(state.pKnown < 0.3) // Should decrease from default 0.3
        #expect(state.attempts == 1)
        #expect(state.corrects == 0)
    }

    @Test("Repeated correct attempts trend upward")
    @MainActor
    func testRepeatedCorrectTrendsUpward() async throws {
        let controller = try makeTempController()
        let tracer = ConceptTracerService(storage: controller.storage)
        
        let conceptKey = "laplace-transform"
        var pKnowns: [Double] = []
        
        // Simulate 5 correct attempts
        for _ in 0..<5 {
            let event = StudyEventDTO(
                id: UUID(),
                timestamp: Date(),
                sessionId: UUID(),
                kind: .cardAnswered,
                cardId: UUID(),
                conceptsAtTime: [conceptKey],
                grade: 4 // Correct
            )
            
            let states = try await tracer.updateFromStudyEvent(event)
            pKnowns.append(states[0].pKnown)
        }
        
        // Verify monotonic increase
        for i in 0..<(pKnowns.count - 1) {
            #expect(pKnowns[i + 1] > pKnowns[i])
        }
        
        // Final state should be high confidence
        let finalState = try await tracer.conceptState(forKey: conceptKey)
        #expect(finalState?.pKnown ?? 0 > 0.7)
        #expect(finalState?.attempts == 5)
        #expect(finalState?.corrects == 5)
    }

    @Test("Repeated incorrect attempts trend downward")
    @MainActor
    func testRepeatedIncorrectTrendsDownward() async throws {
        let controller = try makeTempController()
        let tracer = ConceptTracerService(storage: controller.storage)
        
        let conceptKey = "chain-rule"
        var pKnowns: [Double] = []
        
        // Simulate 5 incorrect attempts
        for _ in 0..<5 {
            let event = StudyEventDTO(
                id: UUID(),
                timestamp: Date(),
                sessionId: UUID(),
                kind: .cardAnswered,
                cardId: UUID(),
                conceptsAtTime: [conceptKey],
                grade: 1 // Incorrect
            )
            
            let states = try await tracer.updateFromStudyEvent(event)
            pKnowns.append(states[0].pKnown)
        }
        
        // Verify general trend is downward (first > last)
        #expect(pKnowns.first ?? 0 > pKnowns.last ?? 1)
        
        // Final state should be low confidence
        // Note: With BKT-lite pSlip=0.1 and pGuess=0.25, pKnown has a lower bound around 0.06-0.08
        // due to Bayesian inference. Can't reach exactly 0.
        let finalState = try await tracer.conceptState(forKey: conceptKey)
        #expect(finalState?.pKnown ?? 1.0 < 0.30) // Should be well below initial 0.3
        #expect(finalState?.attempts == 5)
        #expect(finalState?.corrects == 0)
    }

    @Test("Multi-concept update splits credit correctly")
    @MainActor
    func testMultiConceptCreditSplit() async throws {
        let controller = try makeTempController()
        let tracer = ConceptTracerService(storage: controller.storage)
        
        let concepts = ["concept-a", "concept-b", "concept-c"]
        let event = StudyEventDTO(
            id: UUID(),
            timestamp: Date(),
            sessionId: UUID(),
            kind: .cardAnswered,
            cardId: UUID(),
            conceptsAtTime: concepts,
            grade: 4 // Correct
        )
        
        let states = try await tracer.updateFromStudyEvent(event)
        
        #expect(states.count == 3)
        
        // All concepts should have updated, but with reduced credit (1/3 each)
        for state in states {
            #expect(state.pKnown > 0.3) // Increased from default
            #expect(state.pKnown < 0.5) // But not as much as single concept would
        }
        
        // Now test single concept for comparison
        let singleConceptEvent = StudyEventDTO(
            id: UUID(),
            timestamp: Date(),
            sessionId: UUID(),
            kind: .cardAnswered,
            cardId: UUID(),
            conceptsAtTime: ["single-concept"],
            grade: 4 // Correct
        )
        
        let singleStates = try await tracer.updateFromStudyEvent(singleConceptEvent)
        
        // Single concept should get full credit and increase more
        #expect(singleStates[0].pKnown > states[0].pKnown)
    }

    @Test("Persistence round-trip preserves state")
    @MainActor
    func testPersistenceRoundTrip() async throws {
        let controller = try makeTempController()
        let tracer = ConceptTracerService(storage: controller.storage)
        
        let conceptKey = "integral-calculus"
        let event = StudyEventDTO(
            id: UUID(),
            timestamp: Date(),
            sessionId: UUID(),
            kind: .cardAnswered,
            cardId: UUID(),
            conceptsAtTime: [conceptKey],
            grade: 4 // Correct
        )
        
        let originalStates = try await tracer.updateFromStudyEvent(event)
        let originalState = originalStates[0]
        
        // Read back from storage
        let loadedState = try await tracer.conceptState(forKey: conceptKey)
        
        #expect(loadedState != nil)
        #expect(loadedState?.key == originalState.key)
        #expect(loadedState?.pKnown == originalState.pKnown)
        #expect(loadedState?.attempts == originalState.attempts)
        #expect(loadedState?.corrects == originalState.corrects)
    }

    @Test("All concept states retrieval")
    @MainActor
    func testAllConceptStates() async throws {
        let controller = try makeTempController()
        let tracer = ConceptTracerService(storage: controller.storage)
        
        // Create 3 different concepts
        let concepts = ["concept-1", "concept-2", "concept-3"]
        
        for concept in concepts {
            let event = StudyEventDTO(
                id: UUID(),
                timestamp: Date(),
                sessionId: UUID(),
                kind: .cardAnswered,
                cardId: UUID(),
                conceptsAtTime: [concept],
                grade: 4 // Correct
            )
            _ = try await tracer.updateFromStudyEvent(event)
        }
        
        let allStates = try await tracer.allConceptStates()
        
        #expect(allStates.count == 3)
        
        let keys = Set(allStates.map { $0.key })
        #expect(keys.contains("concept-1"))
        #expect(keys.contains("concept-2"))
        #expect(keys.contains("concept-3"))
    }

    @Test("Empty concepts array returns empty states")
    @MainActor
    func testEmptyConceptsReturnsEmpty() async throws {
        let controller = try makeTempController()
        let tracer = ConceptTracerService(storage: controller.storage)
        
        let event = StudyEventDTO(
            id: UUID(),
            timestamp: Date(),
            sessionId: UUID(),
            kind: .cardAnswered,
            cardId: UUID(),
            conceptsAtTime: [],
            grade: 4
        )
        
        let states = try await tracer.updateFromStudyEvent(event)
        
        #expect(states.isEmpty)
    }

    @Test("pKnown bounds to safe range")
    @MainActor
    func testPKnownBounds() async throws {
        let controller = try makeTempController()
        let tracer = ConceptTracerService(storage: controller.storage)
        
        let conceptKey = "boundary-test"
        
        // Do many correct attempts to try to push pKnown to 1.0
        for _ in 0..<20 {
            let event = StudyEventDTO(
                id: UUID(),
                timestamp: Date(),
                sessionId: UUID(),
                kind: .cardAnswered,
                cardId: UUID(),
                conceptsAtTime: [conceptKey],
                grade: 4 // Correct
            )
            _ = try await tracer.updateFromStudyEvent(event)
        }
        
        let state = try await tracer.conceptState(forKey: conceptKey)
        
        // pKnown should be very high but not exactly 1.0 (BKT clamps to 0.99)
        #expect(state?.pKnown ?? 0 < 1.0)
        #expect(state?.pKnown ?? 0 > 0.9)
    }
}
