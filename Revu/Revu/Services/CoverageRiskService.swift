@preconcurrency import Foundation

/// Risk level for a course based on study pace and exam proximity.
enum RiskLevel: String, Equatable, Sendable {
    case onTrack
    case atRisk
    case critical

    var displayName: String {
        switch self {
        case .onTrack: return "On Track"
        case .atRisk: return "At Risk"
        case .critical: return "Critical"
        }
    }
}

/// Coverage risk assessment for a single course.
struct CoverageRisk: Identifiable, Equatable, Sendable {
    let courseId: UUID
    let courseName: String
    let riskLevel: RiskLevel
    let currentPaceCardsPerDay: Double
    let requiredPaceCardsPerDay: Double
    let daysUntilExam: Int?
    let overallMastery: Double
    let weakTopics: [String]

    var id: UUID { courseId }
}

/// Computes coverage risk for courses based on study pace and exam proximity.
struct CoverageRiskService {
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

    /// Assesses coverage risk for all courses, sorted by severity (critical first).
    func assessAllCourses(referenceDate: Date = Date()) async -> [CoverageRisk] {
        let courses = await courseService.allCourses()
        var results: [CoverageRisk] = []

        // Load all recent review logs once (large limit to cover 7 days of activity)
        let allLogs = (try? await storage.recentLogs(limit: 10_000)) ?? []

        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate

        for course in courses {
            let progress = await courseService.courseProgress(courseId: course.id)
            let linkedDecks = await courseService.decks(courseId: course.id)
            let deckIds = Set(linkedDecks.map(\.id))

            // Collect all card IDs for this course's linked decks
            var allCardIds: Set<UUID> = []
            var totalCards = 0
            var masteredCardCount = 0
            for deckId in deckIds {
                let cards = (try? await storage.cards(deckId: deckId)) ?? []
                let activeCards = cards.filter { !$0.isSuspended }
                for card in activeCards {
                    allCardIds.insert(card.id)
                }
                totalCards += activeCards.count
                masteredCardCount += activeCards.filter {
                    $0.srs.fsrsReps >= 2 && $0.srs.stability >= 5.0
                }.count
            }

            // Current pace: reviews in the last 7 days for this course's cards, divided by 7
            let recentReviews = allLogs.filter { log in
                allCardIds.contains(log.cardId) && log.timestamp >= sevenDaysAgo && log.timestamp <= referenceDate
            }
            let currentPace = Double(recentReviews.count) / 7.0

            // Required pace: remaining non-mastered cards / days until exam
            let remainingCards = totalCards - masteredCardCount
            var requiredPace: Double = 0
            if let examDate = course.examDate {
                let daysLeft = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: referenceDate),
                    to: calendar.startOfDay(for: examDate)
                ).day ?? 0
                if daysLeft > 0 {
                    requiredPace = Double(remainingCards) / Double(daysLeft)
                }
            }

            // Risk level determination
            let riskLevel = computeRiskLevel(
                currentPace: currentPace,
                requiredPace: requiredPace,
                daysUntilExam: progress.daysUntilExam,
                overallMastery: progress.overallMastery,
                hasExam: course.examDate != nil
            )

            // Weak topics: topics with mastery < 0.5
            let weakTopics = progress.topicCoverage
                .filter { $0.mastery < 0.5 }
                .map(\.topicName)

            results.append(CoverageRisk(
                courseId: course.id,
                courseName: course.name,
                riskLevel: riskLevel,
                currentPaceCardsPerDay: currentPace,
                requiredPaceCardsPerDay: requiredPace,
                daysUntilExam: progress.daysUntilExam,
                overallMastery: progress.overallMastery,
                weakTopics: weakTopics
            ))
        }

        // Sort by risk severity: critical first, then atRisk, then onTrack
        results.sort { lhs, rhs in
            lhs.riskLevel.sortOrder < rhs.riskLevel.sortOrder
        }

        return results
    }

    // MARK: - Private

    private func computeRiskLevel(
        currentPace: Double,
        requiredPace: Double,
        daysUntilExam: Int?,
        overallMastery: Double,
        hasExam: Bool
    ) -> RiskLevel {
        // No exam date: always on track
        guard hasExam else { return .onTrack }

        // Critical: exam within 3 days and mastery below 0.7
        if let days = daysUntilExam, days <= 3, overallMastery < 0.7 {
            return .critical
        }

        // If no required pace (exam passed or zero remaining), base on mastery
        guard requiredPace > 0 else {
            return overallMastery >= 0.7 ? .onTrack : .atRisk
        }

        // Pace gap analysis
        let gap = requiredPace - currentPace
        if gap <= 0 {
            // Current pace meets or exceeds required pace
            return .onTrack
        }

        let gapRatio = gap / requiredPace
        if gapRatio >= 0.5 {
            // Gap is 50% or more of required pace
            return .critical
        }

        // Gap exists but less than 50%
        return .atRisk
    }
}

// MARK: - RiskLevel Sort Order

private extension RiskLevel {
    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .atRisk: return 1
        case .onTrack: return 2
        }
    }
}
