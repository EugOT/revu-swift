@preconcurrency import Foundation

// MARK: - Gap Severity

/// Severity level for a detected knowledge gap.
enum GapSeverity: Int, Comparable, Sendable, CaseIterable {
    case low = 0
    case moderate = 1
    case high = 2
    case critical = 3

    static func < (lhs: GapSeverity, rhs: GapSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Weight multiplier used when ranking gaps.
    var weight: Double {
        switch self {
        case .low: return 0.25
        case .moderate: return 0.5
        case .high: return 0.75
        case .critical: return 1.0
        }
    }
}

// MARK: - Gap Signal

/// Signals that contributed to identifying a knowledge gap.
enum GapSignal: String, Sendable, CaseIterable {
    case lowMastery
    case repeatedFailures
    case highConfusion
    case insufficientCoverage
    case examProximity
    case forgettingRisk
}

// MARK: - Session Outcome

/// Outcome data for a single item answered during a study session.
struct SessionOutcome: Sendable {
    let cardId: UUID
    let deckId: UUID?
    let conceptKeys: [String]
    let wasSuccessful: Bool
    let confusionScore: Double
    let elapsedMs: Int
}

// MARK: - Concept Gap

/// A detected knowledge gap for a specific concept.
struct ConceptGap: Identifiable, Sendable {
    let id: UUID
    let conceptKey: String
    let conceptName: String
    let courseId: UUID
    let severity: GapSeverity
    let signals: [GapSignal]
    let suggestedCardCount: Int
    let existingCardCount: Int
    let materialChunksAvailable: Bool
}

// MARK: - Gap Report

/// Report summarizing detected gaps after a study session.
struct GapReport: Sendable {
    let courseId: UUID
    let gaps: [ConceptGap]
    let generatedAt: Date
    let sessionId: UUID

    var isEmpty: Bool { gaps.isEmpty }

    /// Top gaps sorted by severity (critical first), capped at a reasonable number.
    var topGaps: [ConceptGap] {
        Array(
            gaps.sorted { $0.severity > $1.severity }
                .prefix(5)
        )
    }
}

// MARK: - Gap Detection Engine

/// Analyzes post-session data to detect knowledge gaps by cross-referencing
/// concept mastery, coverage risk, and session outcomes.
struct GapDetectionEngine {
    private let storage: Storage
    private let conceptTracer: ConceptTracerService
    private let coverageRisk: CoverageRiskService
    private let courseService: CourseService

    init(storage: Storage) {
        self.storage = storage
        self.conceptTracer = ConceptTracerService(storage: storage)
        self.coverageRisk = CoverageRiskService(storage: storage)
        self.courseService = CourseService(storage: storage)
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    // MARK: - Public API

    /// Analyzes session outcomes and concept states to produce a gap report.
    func analyzePostSession(
        sessionOutcomes: [SessionOutcome],
        courseId: UUID
    ) async -> GapReport {
        let sessionId = UUID()
        let allStates = (try? await conceptTracer.allConceptStates()) ?? []
        let statesByKey = Dictionary(uniqueKeysWithValues: allStates.map { ($0.key, $0) })

        // Gather course-level risk info
        let risks = await coverageRisk.assessAllCourses()
        let courseRisk = risks.first(where: { $0.courseId == courseId })

        // Aggregate session outcomes per concept
        var conceptFailures: [String: Int] = [:]
        var conceptAttempts: [String: Int] = [:]
        var conceptConfusion: [String: Double] = [:]

        for outcome in sessionOutcomes {
            for key in outcome.conceptKeys {
                let normalized = key.lowercased()
                conceptAttempts[normalized, default: 0] += 1
                if !outcome.wasSuccessful {
                    conceptFailures[normalized, default: 0] += 1
                }
                let existing = conceptConfusion[normalized, default: 0]
                conceptConfusion[normalized] = max(existing, outcome.confusionScore)
            }
        }

        // Build the union of all concept keys seen in session + stored states
        var allConceptKeys = Set(conceptAttempts.keys)
        for state in allStates {
            allConceptKeys.insert(state.key)
        }

        var gaps: [ConceptGap] = []

        for key in allConceptKeys {
            var signals: [GapSignal] = []

            // Signal: low mastery from BKT
            let state = statesByKey[key]
            if let pKnown = state?.pKnown, pKnown < 0.5 {
                signals.append(.lowMastery)
            }

            // Signal: repeated failures in this session
            let failures = conceptFailures[key] ?? 0
            let attempts = conceptAttempts[key] ?? 0
            if failures >= 2 || (attempts > 0 && Double(failures) / Double(attempts) > 0.5) {
                signals.append(.repeatedFailures)
            }

            // Signal: high confusion score
            let confusion = conceptConfusion[key] ?? 0
            if confusion >= 0.6 {
                signals.append(.highConfusion)
            }

            // Signal: insufficient coverage (few existing cards for this concept)
            let existingCount = await countCardsForConcept(key, courseId: courseId)
            if existingCount < 3 {
                signals.append(.insufficientCoverage)
            }

            // Signal: exam proximity from course risk
            if let risk = courseRisk, risk.riskLevel == .critical {
                signals.append(.examProximity)
            } else if let risk = courseRisk, risk.riskLevel == .atRisk,
                      let days = risk.daysUntilExam, days <= 14 {
                signals.append(.examProximity)
            }

            // Signal: forgetting risk (stability dropping or many lapses)
            if let s = state, s.attempts >= 4 {
                let successRate = Double(s.corrects) / Double(s.attempts)
                if successRate < 0.4 {
                    signals.append(.forgettingRisk)
                }
            }

            guard !signals.isEmpty else { continue }

            let severity = computeSeverity(signals: signals)
            let displayName = state?.displayName ?? key

            // Check if material chunks exist for this concept
            let chunksAvailable = await hasChunksForConcept(key, courseId: courseId)

            // Suggest additional cards based on severity
            let suggestedCards: Int
            switch severity {
            case .critical: suggestedCards = 5
            case .high: suggestedCards = 3
            case .moderate: suggestedCards = 2
            case .low: suggestedCards = 1
            }

            gaps.append(ConceptGap(
                id: UUID(),
                conceptKey: key,
                conceptName: displayName,
                courseId: courseId,
                severity: severity,
                signals: signals,
                suggestedCardCount: suggestedCards,
                existingCardCount: existingCount,
                materialChunksAvailable: chunksAvailable
            ))
        }

        return GapReport(
            courseId: courseId,
            gaps: gaps,
            generatedAt: Date(),
            sessionId: sessionId
        )
    }

    /// Quick check whether a course has actionable gaps without building a full report.
    func hasActionableGaps(courseId: UUID) async -> Bool {
        let allStates = (try? await conceptTracer.allConceptStates()) ?? []
        let lowMasteryCount = allStates.filter { $0.pKnown < 0.4 }.count
        guard lowMasteryCount > 0 else { return false }

        let risks = await coverageRisk.assessAllCourses()
        if let risk = risks.first(where: { $0.courseId == courseId }),
           risk.riskLevel == .critical || risk.riskLevel == .atRisk {
            return true
        }

        return lowMasteryCount >= 2
    }

    // MARK: - Private Helpers

    /// Determines severity from a set of signals.
    private func computeSeverity(signals: [GapSignal]) -> GapSeverity {
        let signalSet = Set(signals)

        // Critical: multiple strong signals or exam + failures
        if signalSet.contains(.examProximity) && signalSet.contains(.repeatedFailures) {
            return .critical
        }
        if signalSet.contains(.highConfusion) && signalSet.contains(.repeatedFailures) {
            return .critical
        }
        if signals.count >= 4 {
            return .critical
        }

        // High: exam proximity with low mastery, or confusion with low mastery
        if signalSet.contains(.examProximity) && signalSet.contains(.lowMastery) {
            return .high
        }
        if signalSet.contains(.highConfusion) && signalSet.contains(.lowMastery) {
            return .high
        }
        if signals.count >= 3 {
            return .high
        }

        // Moderate: at least two signals
        if signals.count >= 2 {
            return .moderate
        }

        // Low: single signal
        return .low
    }

    /// Counts how many cards in the course's linked decks reference the given concept key.
    private func countCardsForConcept(_ conceptKey: String, courseId: UUID) async -> Int {
        let linkedDecks = await courseService.decks(courseId: courseId)
        var count = 0
        for deck in linkedDecks {
            let cards = (try? await storage.cards(deckId: deck.id)) ?? []
            for card in cards {
                let tags = card.tags.map { $0.lowercased() }
                if tags.contains(conceptKey) {
                    count += 1
                }
            }
        }
        return count
    }

    /// Checks if any content chunks exist for the given concept in the course.
    private func hasChunksForConcept(_ conceptKey: String, courseId: UUID) async -> Bool {
        let chunks = (try? await storage.searchChunks(
            courseId: courseId,
            keywords: [conceptKey],
            limit: 1
        )) ?? []
        return !chunks.isEmpty
    }
}
