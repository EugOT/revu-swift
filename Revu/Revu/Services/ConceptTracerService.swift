@preconcurrency import Foundation

/// Service for tracking concept-level mastery using Bayesian Knowledge Tracing (BKT-lite)
struct ConceptTracerService {
    private let storage: Storage
    
    // BKT-lite parameters
    private let pSlip: Double = 0.1   // P(incorrect | known)
    private let pGuess: Double = 0.25 // P(correct | unknown) - assumes 4-choice MCQ baseline
    
    init(storage: Storage) {
        self.storage = storage
    }
    
    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }
    
    // MARK: - Public API
    
    /// Update concept states based on a study event
    /// - Parameters:
    ///   - event: The study event containing concepts and grade
    /// - Returns: Updated concept states
    @discardableResult
    func updateFromStudyEvent(_ event: StudyEventDTO) async throws -> [ConceptState] {
        guard let concepts = event.conceptsAtTime, !concepts.isEmpty else { return [] }
        guard let grade = event.grade else { return [] }
        
        let isCorrect = grade >= 3 // FSRS: grades 3-4 are correct
        let creditPerConcept = 1.0 / Double(concepts.count)
        
        var updatedStates: [ConceptState] = []
        
        for conceptKey in concepts {
            // Load or create concept state
            var state = try await storage.conceptState(forKey: conceptKey) ?? ConceptState(
                key: conceptKey,
                displayName: conceptKey,
                pKnown: 0.3,
                attempts: 0,
                corrects: 0,
                updatedAt: Date()
            )
            
            // Update tracking counts
            state.attempts += 1
            if isCorrect {
                state.corrects += 1
            }
            
            // Apply BKT-lite update with credit splitting
            state.pKnown = bayesianUpdate(
                priorPKnown: state.pKnown,
                isCorrect: isCorrect,
                credit: creditPerConcept
            )
            
            state.updatedAt = Date()
            
            // Persist
            try await storage.upsert(conceptState: state)
            updatedStates.append(state)
        }
        
        return updatedStates
    }
    
    /// Load all concept states
    func allConceptStates() async throws -> [ConceptState] {
        try await storage.allConceptStates()
    }
    
    /// Load a specific concept state
    func conceptState(forKey key: String) async throws -> ConceptState? {
        try await storage.conceptState(forKey: key)
    }
    
    // MARK: - BKT-lite Logic
    
    /// Bayesian update with credit splitting
    /// - Parameters:
    ///   - priorPKnown: Prior probability of knowledge
    ///   - isCorrect: Whether the response was correct
    ///   - credit: Credit weight (1.0 for single concept, 1/N for multi-concept)
    /// - Returns: Updated probability of knowledge
    private func bayesianUpdate(priorPKnown: Double, isCorrect: Bool, credit: Double) -> Double {
        let p0 = priorPKnown.clamped(to: 0.01...0.99)
        
        if isCorrect {
            // P(known | correct) using Bayes' rule
            let pCorrect = p0 * (1 - pSlip) + (1 - p0) * pGuess
            let posteriorPKnown = (p0 * (1 - pSlip)) / pCorrect
            
            // Interpolate based on credit (partial update for multi-concept)
            return p0 + credit * (posteriorPKnown - p0)
        } else {
            // P(known | incorrect) using Bayes' rule
            let pIncorrect = p0 * pSlip + (1 - p0) * (1 - pGuess)
            let posteriorPKnown = (p0 * pSlip) / pIncorrect
            
            // Interpolate based on credit (partial update for multi-concept)
            return p0 + credit * (posteriorPKnown - p0)
        }
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
