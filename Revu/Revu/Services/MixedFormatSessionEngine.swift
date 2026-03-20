import Foundation

// MARK: - Session Item Types

/// A single item in the mixed-format study session queue.
/// The queue can contain flashcards, explanations, concept checks, exam questions,
/// and reading blocks, enabling adaptive study sessions that respond to real-time performance.
enum SessionItem: Identifiable, Sendable {
    case flashcard(Card)
    case explanation(ExplanationItem)
    case conceptCheck(ConceptCheckItem)
    case examQuestion(ExamQuestionItem)
    case readingBlock(ReadingBlockItem)

    var id: UUID {
        switch self {
        case .flashcard(let card): return card.id
        case .explanation(let item): return item.id
        case .conceptCheck(let item): return item.id
        case .examQuestion(let item): return item.id
        case .readingBlock(let item): return item.id
        }
    }
}

enum ExplanationDisclosureLevel: String, Sendable {
    case concise
    case guided
    case detailed
}

struct ExplanationItem: Identifiable, Sendable {
    let id: UUID
    let conceptKey: String
    let conceptName: String
    let triggerCardId: UUID
    let materialChunks: [String]
    let masteryLevel: Double
    let disclosureLevel: ExplanationDisclosureLevel
}

struct ConceptCheckItem: Identifiable, Sendable {
    let id: UUID
    let conceptKey: String
    let conceptName: String
    let question: String
    let expectedInsight: String
    let precedingExplanationId: UUID
}

struct ExamQuestionItem: Identifiable, Sendable {
    let id: UUID
    let conceptKey: String
    let question: String
    let rubric: String?
    let sourceExamId: UUID?
}

struct ReadingBlockItem: Identifiable, Sendable {
    let id: UUID
    let conceptKey: String
    let title: String
    let content: String
    let sourceStudyGuideId: UUID?
}

// MARK: - Mixed Format Session Engine

/// Replaces the simple card queue with a heterogeneous item queue that can contain
/// flashcards, explanations, concept checks, exam questions, and reading blocks.
/// Decides what comes next based on real-time performance signals.
final class MixedFormatSessionEngine {
    private let storage: any Storage
    private let conceptTracer: ConceptTracerService
    private let confusionDetector: ConfusionDetector
    private let chunkService: ContentChunkService
    private var queue: [SessionItem] = []
    private var recentOutcomes: [Bool] = []
    private var consecutiveSuccesses: Int = 0
    private var consecutiveFailures: Int = 0

    init(storage: any Storage) {
        self.storage = storage
        self.conceptTracer = ConceptTracerService(storage: storage)
        self.confusionDetector = ConfusionDetector()
        self.chunkService = ContentChunkService(storage: storage)
    }

    // MARK: - Queue Management

    /// Build initial queue from cards (wraps each as .flashcard)
    func buildQueue(from cards: [Card]) -> [SessionItem] {
        queue = cards.map { .flashcard($0) }
        return queue
    }

    /// Process an outcome and decide what to insert next.
    /// Returns the list of newly inserted items.
    func processOutcome(
        for item: SessionItem,
        wasSuccessful: Bool,
        confusionScore: Double,
        courseId: UUID?
    ) async -> [SessionItem] {
        recentOutcomes.append(wasSuccessful)
        updateStreaks(wasSuccessful)

        var insertions: [SessionItem] = []

        switch item {
        case .flashcard(let card):
            if !wasSuccessful {
                // Failed flashcard -> insert explanation
                let explanation = await buildExplanation(for: card, courseId: courseId)
                insertions.append(.explanation(explanation))
            } else if consecutiveSuccesses >= 5 {
                // 5+ consecutive successes -> inject harder exam question
                if let examQ = await buildExamQuestion(for: card, courseId: courseId) {
                    insertions.append(.examQuestion(examQ))
                    consecutiveSuccesses = 0
                }
            }

        case .explanation(let explanation):
            // After explanation -> always insert concept check
            let check = buildConceptCheck(after: explanation)
            insertions.append(.conceptCheck(check))

        case .conceptCheck:
            if !wasSuccessful {
                // Failed concept check -> escalation handled by view layer
                // requesting another explanation at a higher disclosure level
            }
            // Success -> continue with queue

        case .examQuestion, .readingBlock:
            break // Continue with queue
        }

        // Frustration brake: if confusion high, insert calming content
        if confusionScore > 0.7 && consecutiveFailures >= 2 {
            if let reading = await buildReadingBlock(courseId: courseId) {
                insertions.append(.readingBlock(reading))
            }
        }

        // Insert items at position 0 (next in queue)
        for (index, insertion) in insertions.enumerated() {
            queue.insert(insertion, at: min(index, queue.count))
        }

        return insertions
    }

    /// Get next item from queue
    func next() -> SessionItem? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }

    /// Number of items remaining in the queue
    var remainingCount: Int { queue.count }

    /// Whether the queue is empty
    var isEmpty: Bool { queue.isEmpty }

    /// Remaining flashcards only, excluding mixed-format helper items.
    func remainingFlashcards() -> [Card] {
        queue.compactMap { item in
            guard case .flashcard(let card) = item else { return nil }
            return card
        }
    }

    // MARK: - Public Insertion (for "I don't get this" button, used by TASK-12)

    /// Insert an explanation for a card at the front of the queue.
    /// Called when the user explicitly requests help via the "I don't get this" button.
    func insertExplanation(for card: Card, courseId: UUID?) async {
        let explanation = await buildExplanation(for: card, courseId: courseId)
        queue.insert(.explanation(explanation), at: min(0, queue.count))
    }

    // MARK: - Private Helpers

    private func buildExplanation(for card: Card, courseId: UUID?) async -> ExplanationItem {
        let conceptKeys = card.tags.isEmpty ? [String(card.front.prefix(50))] : card.tags
        let conceptKey = conceptKeys.first ?? "unknown"

        // Fetch relevant material chunks
        var chunks: [String] = []
        if let courseId {
            let chunkResults = (try? await chunkService.relevantChunks(
                courseId: courseId,
                conceptKeys: conceptKeys.map { $0.lowercased() },
                tokenBudget: 1000
            )) ?? []
            chunks = chunkResults.map { chunk in
                var header = "From \(chunk.sourceFilename)"
                if let page = chunk.sourcePage { header += " (p.\(page))" }
                return "[\(header)] \(chunk.content)"
            }
        }

        // Get mastery level
        let mastery = (try? await conceptTracer.conceptState(forKey: conceptKey.lowercased()))?.pKnown ?? 0.3

        return ExplanationItem(
            id: UUID(),
            conceptKey: conceptKey,
            conceptName: conceptKey,
            triggerCardId: card.id,
            materialChunks: chunks,
            masteryLevel: mastery,
            disclosureLevel: .guided
        )
    }

    private func buildConceptCheck(after explanation: ExplanationItem) -> ConceptCheckItem {
        ConceptCheckItem(
            id: UUID(),
            conceptKey: explanation.conceptKey,
            conceptName: explanation.conceptName,
            question: "What is the key idea behind \(explanation.conceptName)?",
            expectedInsight: explanation.materialChunks.first ?? explanation.conceptName,
            precedingExplanationId: explanation.id
        )
    }

    private func buildExamQuestion(for card: Card, courseId: UUID?) async -> ExamQuestionItem? {
        let conceptKey = card.tags.first ?? String(card.front.prefix(50))

        return ExamQuestionItem(
            id: UUID(),
            conceptKey: conceptKey,
            question: "Explain how \(conceptKey) applies in practice using a short example.",
            rubric: "Include the core definition, one concrete example, and why it matters.",
            sourceExamId: nil
        )
    }

    private func buildReadingBlock(courseId: UUID?) async -> ReadingBlockItem? {
        guard courseId != nil else { return nil }

        return ReadingBlockItem(
            id: UUID(),
            conceptKey: "review",
            title: "Slow down and review the fundamentals",
            content: "Take a short pass through your notes, restate the concept in your own words, and then return to the next prompt.",
            sourceStudyGuideId: nil
        )
    }

    private func updateStreaks(_ wasSuccessful: Bool) {
        if wasSuccessful {
            consecutiveSuccesses += 1
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
            consecutiveSuccesses = 0
        }
    }
}
