import Foundation

/// Adaptive difficulty policy that reorders candidate prompts to maintain ~70% success rate.
///
/// Uses rolling outcomes history to bias toward easier or harder items in real-time.
/// Includes guardrails for cold-start calibration, frustration/boredom brakes, and concept variety.
struct AdaptiveDifficultyPolicy {
    /// Target success rate (70%)
    private let targetSuccessRate: Double = 0.70
    
    /// Window size for rolling success rate calculation
    private let rollingWindow: Int = 15
    
    /// Calibration threshold - first N outcomes are less reactive
    private let calibrationThreshold: Int = 5
    
    /// Maximum consecutive items with same primary concept
    private let maxConsecutiveSameConcept: Int = 2
    
    /// Bias strength when adjusting difficulty
    private let biasStrength: Double = 0.3
    
    /// Frustration brake bias magnitude (toward easier)
    private let frustrationBrakeBias: Double = 0.25
    
    /// Boredom brake bias magnitude (toward harder)
    private let boredomBrakeBias: Double = -0.15
    
    /// Calibration mode bias dampening factor
    private let calibrationDampening: Double = 0.1
    
    init() {}
    
    /// Orders candidates based on rolling outcomes to target ~70% success rate.
    ///
    /// - Parameters:
    ///   - candidates: List of candidate items with predicted success probability and concept keys
    ///   - rollingOutcomes: Recent outcomes (true = success, false = failure), newest last
    /// - Returns: Ordered list of candidates
    func orderCandidates<T>(
        _ candidates: [T],
        rollingOutcomes: [Bool]
    ) -> [T] where T: AdaptiveDifficultyCandidate {
        guard !candidates.isEmpty else { return [] }
        guard !rollingOutcomes.isEmpty else {
            // No history - return baseline ordering (by pSuccess, medium first)
            return candidates.sorted { abs($0.pSuccessNow - 0.70) < abs($1.pSuccessNow - 0.70) }
        }
        
        // Calculate recent success rate
        let recentWindow = rollingOutcomes.suffix(rollingWindow)
        let successCount = recentWindow.filter { $0 }.count
        let recentSuccessRate = Double(successCount) / Double(recentWindow.count)
        
        // Check for calibration phase (first few picks)
        let isCalibrating = recentWindow.count < calibrationThreshold
        
        // Check for frustration brake (last 2 failures)
        let lastTwo = rollingOutcomes.suffix(2)
        let hasFrustrationBrake = lastTwo.count == 2 && lastTwo.allSatisfy { !$0 }
        
        // Check for boredom brake (last 5 successes)
        let lastFive = rollingOutcomes.suffix(5)
        let hasBoredomBrake = lastFive.count == 5 && lastFive.allSatisfy { $0 }
        
        // Calculate target difficulty bias
        let difficultyBias: Double
        if hasFrustrationBrake {
            // Frustration brake - strongly bias toward easier
            difficultyBias = frustrationBrakeBias
        } else if hasBoredomBrake {
            // Boredom brake - bias toward harder
            difficultyBias = boredomBrakeBias
        } else if isCalibrating {
            // Calibration - minimal bias, closer to neutral
            difficultyBias = (targetSuccessRate - recentSuccessRate) * calibrationDampening
        } else {
            // Normal adaptive mode
            difficultyBias = (targetSuccessRate - recentSuccessRate) * biasStrength
        }
        
        // Sort candidates by how well they match our target difficulty
        let targetPSuccess = 0.70 + difficultyBias
        let sorted: [T]
        if hasBoredomBrake {
            // Momentum mode: favor cards just above the student's comfort zone.
            // Select cards with the lowest pSuccess still above 0.4 (challenge without frustration).
            sorted = candidates.sorted { lhs, rhs in
                let lhsAboveFloor = lhs.pSuccessNow >= 0.4
                let rhsAboveFloor = rhs.pSuccessNow >= 0.4
                if lhsAboveFloor != rhsAboveFloor {
                    // Cards above floor come first
                    return lhsAboveFloor && !rhsAboveFloor
                }
                if lhsAboveFloor && rhsAboveFloor {
                    // Among above-floor cards: lower pSuccess = more challenging = preferred
                    return lhs.pSuccessNow < rhs.pSuccessNow
                }
                // Both below floor: order by distance to target as usual
                return abs(lhs.pSuccessNow - targetPSuccess) < abs(rhs.pSuccessNow - targetPSuccess)
            }
        } else {
            sorted = candidates.sorted { lhs, rhs in
                let lhsDist = abs(lhs.pSuccessNow - targetPSuccess)
                let rhsDist = abs(rhs.pSuccessNow - targetPSuccess)
                return lhsDist < rhsDist
            }
        }

        // Apply variety constraint to prevent same-concept runs
        return applyVarietyConstraint(sorted)
    }
    
    /// Reorders candidates to avoid >2 consecutive items with same primary concept.
    private func applyVarietyConstraint<T: AdaptiveDifficultyCandidate>(_ candidates: [T]) -> [T] {
        guard candidates.count > 2 else { return candidates }
        
        var result: [T] = []
        var remaining = candidates
        var lastConcept: String?
        var consecutiveCount = 0
        
        while !remaining.isEmpty {
            // Find best next candidate considering variety constraint
            var bestIndex = 0
            
            for (index, candidate) in remaining.enumerated() {
                let primaryConcept = candidate.conceptKeys.first ?? ""
                
                // If we've hit the consecutive limit for this concept, skip it (if alternatives exist)
                if primaryConcept == lastConcept && consecutiveCount >= maxConsecutiveSameConcept {
                    // Check if there's ANY alternative concept available
                    let hasAlternative = remaining.contains { ($0.conceptKeys.first ?? "") != lastConcept }
                    if hasAlternative {
                        continue // Skip this candidate
                    }
                }
                
                // Take the first valid candidate (they're already sorted by difficulty target)
                bestIndex = index
                break
            }
            
            let selected = remaining.remove(at: bestIndex)
            let selectedConcept = selected.conceptKeys.first ?? ""
            
            // Update tracking
            if selectedConcept == lastConcept {
                consecutiveCount += 1
            } else {
                consecutiveCount = 1
                lastConcept = selectedConcept
            }
            
            result.append(selected)
        }
        
        return result
    }
}

/// Protocol for candidates that can be adaptively ordered.
protocol AdaptiveDifficultyCandidate {
    /// Predicted success probability at "now" (0.0 - 1.0)
    var pSuccessNow: Double { get }

    /// Concept keys for variety constraint (empty if none)
    var conceptKeys: [String] { get }

    /// Consecutive correct answers in the current session (0 by default).
    /// Used to detect momentum and target appropriately challenging material.
    var sessionCorrectStreak: Int { get }
}

extension AdaptiveDifficultyCandidate {
    var sessionCorrectStreak: Int { 0 }
}
