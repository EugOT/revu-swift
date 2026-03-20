@preconcurrency import Foundation

/// A daily study plan aggregated across all courses.
struct DailyPlan: Equatable, Sendable {
    let generatedAt: Date
    let courseItems: [CoursePlanItem]
    let unlinkedDueCount: Int

    var totalDueCards: Int {
        courseItems.reduce(0) { $0 + $1.dueCards } + unlinkedDueCount
    }

    struct CoursePlanItem: Identifiable, Equatable, Sendable {
        let courseId: UUID
        let courseName: String
        let examDate: Date?
        let daysUntilExam: Int?
        let overallMastery: Double
        let dueCards: Int
        let totalCards: Int
        let priority: Double
        let topicGaps: [TopicGap]

        var id: UUID { courseId }
    }

    struct TopicGap: Identifiable, Equatable, Sendable {
        let topicId: UUID
        let topicName: String
        let mastery: Double

        var id: UUID { topicId }
    }
}

/// Aggregates study state across all courses to produce a prioritized daily plan.
struct DailyPlannerService {
    private let storage: Storage
    private let courseService: CourseService

    init(storage: Storage) {
        self.storage = storage
        self.courseService = CourseService(storage: storage)
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    /// Builds a daily plan with per-course breakdowns ordered by priority.
    func buildDailyPlan(referenceDate: Date = Date()) async -> DailyPlan {
        let courses = await courseService.allCourses()
        let now = referenceDate

        var courseItems: [DailyPlan.CoursePlanItem] = []

        for course in courses {
            let progress = await courseService.courseProgress(courseId: course.id)
            let linkedDecks = await courseService.decks(courseId: course.id)
            let deckIds = Set(linkedDecks.map(\.id))

            // Count due cards for this course
            var dueCount = 0
            for deckId in deckIds {
                let cards = (try? await storage.cards(deckId: deckId)) ?? []
                let due = cards.filter { !$0.isSuspended && $0.srs.dueDate <= now }
                dueCount += due.count
            }

            // Compute priority: closer exams with lower mastery get higher priority
            let priority = computePriority(
                daysUntilExam: progress.daysUntilExam,
                mastery: progress.overallMastery,
                dueCards: dueCount
            )

            // Identify coverage gaps (topics with mastery < 0.5)
            let gaps = progress.topicCoverage
                .filter { $0.mastery < 0.5 }
                .map { DailyPlan.TopicGap(
                    topicId: $0.topicId,
                    topicName: $0.topicName,
                    mastery: $0.mastery
                )}

            courseItems.append(DailyPlan.CoursePlanItem(
                courseId: course.id,
                courseName: course.name,
                examDate: course.examDate,
                daysUntilExam: progress.daysUntilExam,
                overallMastery: progress.overallMastery,
                dueCards: dueCount,
                totalCards: progress.totalCards,
                priority: priority,
                topicGaps: gaps
            ))
        }

        // Sort by priority descending (highest priority first)
        courseItems.sort { $0.priority > $1.priority }

        // Count unlinked due cards (cards in decks not linked to any course)
        let linkedDeckIds = Set(courseItems.flatMap { item in
            // Re-fetch linked deck IDs for each course
            // This is a simplification; in production we'd cache these
            [item.courseId]
        })
        let allDecks = (try? await storage.allDecks()) ?? []
        let unlinkedDecks = allDecks.filter { $0.courseId == nil }
        var unlinkedDue = 0
        for deck in unlinkedDecks {
            let cards = (try? await storage.cards(deckId: deck.id)) ?? []
            let due = cards.filter { !$0.isSuspended && $0.srs.dueDate <= now }
            unlinkedDue += due.count
        }

        return DailyPlan(
            generatedAt: now,
            courseItems: courseItems,
            unlinkedDueCount: unlinkedDue
        )
    }

    // MARK: - Priority Computation

    private func computePriority(daysUntilExam: Int?, mastery: Double, dueCards: Int) -> Double {
        // Base priority from due cards
        var priority = Double(min(dueCards, 100)) / 100.0

        // Exam proximity boost
        if let days = daysUntilExam {
            if days <= 0 {
                // Exam passed, low priority unless mastery is low
                priority += (1.0 - mastery) * 0.3
            } else if days <= 7 {
                priority += 2.0 * (1.0 - mastery)
            } else if days <= 14 {
                priority += 1.5 * (1.0 - mastery)
            } else if days <= 30 {
                priority += 1.0 * (1.0 - mastery)
            } else {
                priority += 0.5 * (1.0 - mastery)
            }
        } else {
            // No exam, moderate priority based on mastery gap
            priority += 0.3 * (1.0 - mastery)
        }

        return priority
    }
}
