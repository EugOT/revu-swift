import XCTest
@testable import Revu

final class AdaptiveDifficultyPolicyTests: XCTestCase {
    
    struct Candidate: Equatable, AdaptiveDifficultyCandidate {
        let id: String
        let pSuccess: Double
        let conceptKeys: [String]
        
        var pSuccessNow: Double { pSuccess }
    }
    
    // MARK: - Bias toward easier items when success rate is low
    
    func testLowSuccessRateBiasesEasier() {
        // Recent history: 2 failures out of last 3 attempts (~33% success)
        let history: [Bool] = [false, true, false]
        
        let candidates = [
            Candidate(id: "hard", pSuccess: 0.35, conceptKeys: ["algebra"]),
            Candidate(id: "medium", pSuccess: 0.65, conceptKeys: ["geometry"]),
            Candidate(id: "easy", pSuccess: 0.85, conceptKeys: ["arithmetic"])
        ]
        
        let policy = AdaptiveDifficultyPolicy()
        let ordered = policy.orderCandidates(candidates, rollingOutcomes: history)
        
        // Should prioritize easier items (higher pSuccess) to stabilize success rate
        XCTAssertTrue(ordered.first?.id == "easy" || ordered.first?.id == "medium")
        XCTAssertEqual(ordered.last?.id, "hard")
    }
    
    // MARK: - Bias toward harder items when success rate is high
    
    func testHighSuccessRateBiasesHarder() {
        // Recent history: 9 successes out of last 10 attempts (90% success)
        // Failure is early so last 5 are all successes → triggers boredom brake (momentum mode)
        let history: [Bool] = [false, true, true, true, true, true, true, true, true, true]

        // In momentum mode: prefer above-floor (pSuccess >= 0.4) cards ordered by ascending pSuccess.
        // Cards below 0.4 floor are placed last (too hard to be useful during momentum streaks).
        let candidates = [
            Candidate(id: "hard", pSuccess: 0.35, conceptKeys: ["calculus"]),   // below 0.4 floor
            Candidate(id: "medium", pSuccess: 0.65, conceptKeys: ["algebra"]),  // above floor, harder
            Candidate(id: "easy", pSuccess: 0.90, conceptKeys: ["arithmetic"])  // above floor, easier
        ]

        let policy = AdaptiveDifficultyPolicy()
        let ordered = policy.orderCandidates(candidates, rollingOutcomes: history)

        // Momentum mode: medium (0.65) should come before easy (0.90) — more challenging above floor.
        // hard (0.35) should be last — below the frustration floor.
        XCTAssertEqual(ordered.first?.id, "medium")
        XCTAssertEqual(ordered.last?.id, "hard")
    }
    
    // MARK: - Frustration brake after consecutive failures
    
    func testFrustrationBrakeAfterConsecutiveFailures() {
        // Recent history: last 2 attempts were failures
        let history: [Bool] = [true, true, false, false]
        
        let candidates = [
            Candidate(id: "hard", pSuccess: 0.30, conceptKeys: ["physics"]),
            Candidate(id: "easy", pSuccess: 0.85, conceptKeys: ["basics"])
        ]
        
        let policy = AdaptiveDifficultyPolicy()
        let ordered = policy.orderCandidates(candidates, rollingOutcomes: history)
        
        // Frustration brake should kick in - prioritize easier items
        XCTAssertEqual(ordered.first?.id, "easy")
    }
    
    // MARK: - Boredom brake after fast success streak
    
    func testBoredomBrakeAfterSuccessStreak() {
        // Recent history: 5 consecutive successes
        let history: [Bool] = [true, true, true, true, true]
        
        let candidates = [
            Candidate(id: "veryEasy", pSuccess: 0.95, conceptKeys: ["trivial"]),
            Candidate(id: "medium", pSuccess: 0.65, conceptKeys: ["normal"])
        ]
        
        let policy = AdaptiveDifficultyPolicy()
        let ordered = policy.orderCandidates(candidates, rollingOutcomes: history)
        
        // Boredom brake should encourage harder items
        XCTAssertEqual(ordered.first?.id, "medium")
    }
    
    // MARK: - Variety constraint prevents same-concept runs
    
    func testVarietyConstraintPreventsSameConceptRuns() {
        // Build a sequence where all items have same concept "algebra"
        let history: [Bool] = [true, false, true] // Neutral history
        
        let candidates = [
            Candidate(id: "alg1", pSuccess: 0.70, conceptKeys: ["algebra"]),
            Candidate(id: "alg2", pSuccess: 0.71, conceptKeys: ["algebra"]),
            Candidate(id: "alg3", pSuccess: 0.72, conceptKeys: ["algebra"]),
            Candidate(id: "geo1", pSuccess: 0.69, conceptKeys: ["geometry"])
        ]
        
        let policy = AdaptiveDifficultyPolicy()
        let ordered = policy.orderCandidates(candidates, rollingOutcomes: history)
        
        // Check that we don't have 3+ consecutive algebra items
        var consecutiveAlgebra = 0
        var maxConsecutiveAlgebra = 0
        for candidate in ordered {
            if candidate.conceptKeys.contains("algebra") {
                consecutiveAlgebra += 1
                maxConsecutiveAlgebra = max(maxConsecutiveAlgebra, consecutiveAlgebra)
            } else {
                consecutiveAlgebra = 0
            }
        }
        
        XCTAssertLessThanOrEqual(maxConsecutiveAlgebra, 2)
    }
    
    // MARK: - Calibration phase (first N picks less reactive)
    
    func testCalibrationPhaseIsLessReactive() {
        // Very short history - should be in calibration mode
        let shortHistory: [Bool] = [false] // Only 1 attempt
        
        let candidates = [
            Candidate(id: "hard", pSuccess: 0.40, conceptKeys: ["advanced"]),
            Candidate(id: "easy", pSuccess: 0.80, conceptKeys: ["basic"])
        ]
        
        let policy = AdaptiveDifficultyPolicy()
        let ordered = policy.orderCandidates(candidates, rollingOutcomes: shortHistory)
        
        // During calibration, should not overreact to single failure
        // Order should be more balanced, not extreme
        XCTAssertEqual(ordered.count, 2)
        // Either order is acceptable during calibration - we're just testing it doesn't crash
    }
    
    // MARK: - Empty/edge cases
    
    func testEmptyCandidatesReturnsEmpty() {
        let candidates: [Candidate] = []
        let history: [Bool] = [true, false]
        
        let policy = AdaptiveDifficultyPolicy()
        let ordered = policy.orderCandidates(candidates, rollingOutcomes: history)
        
        XCTAssertTrue(ordered.isEmpty)
    }
    
    func testEmptyHistoryFallsBackToBaseline() {
        let candidates = [
            Candidate(id: "hard", pSuccess: 0.40, conceptKeys: ["hard"]),
            Candidate(id: "medium", pSuccess: 0.70, conceptKeys: ["medium"]),
            Candidate(id: "easy", pSuccess: 0.90, conceptKeys: ["easy"])
        ]
        let history: [Bool] = []

        let policy = AdaptiveDifficultyPolicy()
        let ordered = policy.orderCandidates(candidates, rollingOutcomes: history)

        // Should return some ordering (exact order depends on implementation)
        XCTAssertEqual(ordered.count, 3)
    }

    // MARK: - Momentum mode targets above-comfort-zone cards after 5+ streak

    func testMomentumModeTargetsAboveComfortZoneAfterHighStreak() {
        // 6 consecutive successes → triggers boredom brake (momentum mode)
        let history: [Bool] = [true, true, true, true, true, true]

        // Four candidates with varying difficulty
        let candidates = [
            Candidate(id: "too-easy", pSuccess: 0.90, conceptKeys: ["trivial"]),
            Candidate(id: "comfort", pSuccess: 0.70, conceptKeys: ["normal"]),
            Candidate(id: "challenge", pSuccess: 0.55, conceptKeys: ["harder"]),
            Candidate(id: "too-hard", pSuccess: 0.30, conceptKeys: ["impossible"])
        ]

        let policy = AdaptiveDifficultyPolicy()
        let ordered = policy.orderCandidates(candidates, rollingOutcomes: history)

        // Momentum mode: first candidate should be challenging but above 0.4 floor
        // too-hard (0.30) is below floor → should be last
        // Candidates above floor ordered by ascending pSuccess: challenge(0.55), comfort(0.70), too-easy(0.90)
        XCTAssertEqual(ordered.count, 4)
        XCTAssertEqual(ordered.first?.id, "challenge")
        XCTAssertEqual(ordered.last?.id, "too-hard")
    }
}
