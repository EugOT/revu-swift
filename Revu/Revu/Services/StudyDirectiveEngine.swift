@preconcurrency import Foundation

// MARK: - Study Directive

struct StudyDirective: Sendable, Equatable {
    let headline: String
    let body: String
    let courseId: UUID?
    let courseName: String?
    let weakConcepts: [String]
    let sessionType: SessionType
    let estimatedMinutes: Int
    let urgency: Urgency
    let examCountdown: ExamCountdown?

    enum SessionType: String, Sendable {
        case review
        case learnNew
        case examPrep
        case maintenance
        case celebrate
    }

    enum Urgency: String, Sendable {
        case critical
        case high
        case normal
        case low
    }

    struct ExamCountdown: Sendable, Equatable {
        let courseName: String
        let daysRemaining: Int
        let estimatedScore: Double?
    }

    static let empty = StudyDirective(
        headline: "All Caught Up",
        body: "Great work! You've cleared your queue. Import new material or study ahead to stay sharp.",
        courseId: nil,
        courseName: nil,
        weakConcepts: [],
        sessionType: .celebrate,
        estimatedMinutes: 0,
        urgency: .low,
        examCountdown: nil
    )
}

// MARK: - Study Directive Engine

struct StudyDirectiveEngine {
    private let storage: Storage
    private let dailyPlanner: DailyPlannerService
    private let learningIntelligence: LearningIntelligenceService
    private let conceptTracer: ConceptTracerService

    init(storage: Storage) {
        self.storage = storage
        self.dailyPlanner = DailyPlannerService(storage: storage)
        self.learningIntelligence = LearningIntelligenceService(storage: storage)
        self.conceptTracer = ConceptTracerService(storage: storage)
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    // MARK: - Public API

    /// Generate the primary directive for the current moment.
    func generateDirective(referenceDate: Date = Date()) async -> StudyDirective {
        let dailyPlan = await dailyPlanner.buildDailyPlan(referenceDate: referenceDate)
        let snapshot = await learningIntelligence.sessionCuratorSnapshot(for: referenceDate)
        let conceptStates = (try? await conceptTracer.allConceptStates()) ?? []

        let topCourse = dailyPlan.courseItems.first
        let urgency = determineUrgency(topCourse: topCourse, totalDue: dailyPlan.totalDueCards)

        switch urgency {
        case .critical:
            return examImminentDirective(
                course: topCourse!,
                conceptStates: conceptStates,
                snapshot: snapshot,
                plan: dailyPlan
            )
        case .high:
            return highPriorityDirective(
                course: topCourse!,
                conceptStates: conceptStates,
                snapshot: snapshot,
                plan: dailyPlan
            )
        case .normal:
            if dailyPlan.totalDueCards > 0 {
                return standardReviewDirective(
                    plan: dailyPlan,
                    conceptStates: conceptStates,
                    snapshot: snapshot
                )
            } else {
                return exploreNewDirective(plan: dailyPlan)
            }
        case .low:
            return celebrationDirective(plan: dailyPlan)
        }
    }

    /// Generate a post-session directive based on session outcomes.
    func postSessionDirective(
        completedCards: Int,
        lapseCount: Int,
        weakConceptKeys: [String],
        courseName: String?
    ) async -> StudyDirective {
        let conceptStates = (try? await conceptTracer.allConceptStates()) ?? []
        let conceptLookup = Dictionary(uniqueKeysWithValues: conceptStates.map { ($0.key, $0) })

        // Resolve weak concept display names
        let weakNames = weakConceptKeys.compactMap { key -> String? in
            conceptLookup[key]?.displayName ?? key
        }.prefix(3)

        let headline: String
        let body: String
        let sessionType: StudyDirective.SessionType

        if lapseCount == 0 && completedCards > 0 {
            headline = "Strong Session"
            let courseContext = courseName.map { " in \($0)" } ?? ""
            body = "You reviewed \(completedCards) cards\(courseContext) with no lapses. Keep this momentum going."
            sessionType = .maintenance
        } else if !weakNames.isEmpty {
            let weakList = weakNames.joined(separator: ", ")
            headline = "Tomorrow: Focus on \(weakNames.first ?? "Weak Areas")"
            let courseContext = courseName.map { " in \($0)" } ?? ""
            body = "Good session \u{2014} \(completedCards) cards reviewed\(courseContext). "
                + "\(weakList) came up and you missed \(lapseCount). Prioritize \(lapseCount == 1 ? "it" : "them") tomorrow."
            sessionType = .review
        } else if lapseCount > 0 {
            headline = "Review Lapses Tomorrow"
            let courseContext = courseName.map { " in \($0)" } ?? ""
            body = "\(completedCards) cards reviewed\(courseContext) with \(lapseCount) \(lapseCount == 1 ? "lapse" : "lapses"). "
                + "Those cards will resurface soon \u{2014} stay sharp."
            sessionType = .review
        } else {
            headline = "Session Complete"
            body = "No cards were reviewed this session. Import new material or come back when cards are due."
            sessionType = .celebrate
        }

        return StudyDirective(
            headline: headline,
            body: body,
            courseId: nil,
            courseName: courseName,
            weakConcepts: Array(weakNames),
            sessionType: sessionType,
            estimatedMinutes: 0,
            urgency: .normal,
            examCountdown: nil
        )
    }

    /// Generate a folder-level context directive.
    func folderDirective(folderId: UUID) async -> StudyDirective? {
        let deckService = DeckService(storage: storage)
        guard let folder = await deckService.deck(withId: folderId) else { return nil }

        let allDecks = await deckService.allDecks(includeArchived: false)
        let hierarchy = DeckHierarchy(decks: allDecks)
        let subtreeIds = hierarchy.subtreeDeckIDs(of: folderId)

        let now = Date()
        var totalDue = 0
        var totalCards = 0
        var newCards = 0

        for deckId in subtreeIds {
            let cards = (try? await storage.cards(deckId: deckId)) ?? []
            totalCards += cards.count
            for card in cards where !card.isSuspended {
                if card.srs.dueDate <= now {
                    totalDue += 1
                }
                if card.srs.queue == .new && card.srs.fsrsReps == 0 {
                    newCards += 1
                }
            }
        }

        // Gather concept states and find weak concepts in this folder's cards
        let conceptStates = (try? await conceptTracer.allConceptStates()) ?? []
        let weakConcepts = extractWeakConcepts(from: conceptStates)

        let estimatedMinutes = estimateSessionTime(dueReviewCards: totalDue, newCards: 0)

        let headline: String
        let body: String
        let sessionType: StudyDirective.SessionType
        let urgency: StudyDirective.Urgency

        if totalDue == 0 && newCards == 0 {
            headline = "\(folder.name) Is Clear"
            body = "No cards due in this folder. All \(totalCards) cards are up to date."
            sessionType = .celebrate
            urgency = .low
        } else if totalDue == 0 && newCards > 0 {
            headline = "New Material in \(folder.name)"
            body = "This folder has \(newCards) new cards ready to learn across \(totalCards) total cards."
            sessionType = .learnNew
            urgency = .normal
        } else {
            let weakSuffix: String
            if !weakConcepts.isEmpty {
                let weakList = weakConcepts.prefix(3).joined(separator: ", ")
                weakSuffix = " \(weakList) \(weakConcepts.count == 1 ? "is" : "are") below 50% mastery."
            } else {
                weakSuffix = ""
            }
            headline = "\(totalDue) Cards Due in \(folder.name)"
            body = "This folder has \(totalDue) cards due out of \(totalCards) total."
                + (newCards > 0 ? " Plus \(newCards) new cards to learn." : "")
                + weakSuffix
            sessionType = .review
            urgency = totalDue > 50 ? .high : .normal
        }

        return StudyDirective(
            headline: headline,
            body: body,
            courseId: folder.courseId,
            courseName: folder.name,
            weakConcepts: weakConcepts,
            sessionType: sessionType,
            estimatedMinutes: estimatedMinutes,
            urgency: urgency,
            examCountdown: nil
        )
    }

    // MARK: - Urgency Determination

    private func determineUrgency(
        topCourse: DailyPlan.CoursePlanItem?,
        totalDue: Int
    ) -> StudyDirective.Urgency {
        guard let course = topCourse else {
            return totalDue > 0 ? .normal : .low
        }
        if let days = course.daysUntilExam {
            if days <= 3 && course.overallMastery < 0.7 { return .critical }
            if days <= 7 && course.overallMastery < 0.8 { return .high }
        }
        if totalDue > 50 { return .high }
        if totalDue > 0 { return .normal }
        return .low
    }

    // MARK: - Directive Templates

    private func examImminentDirective(
        course: DailyPlan.CoursePlanItem,
        conceptStates: [ConceptState],
        snapshot: SessionCuratorSnapshot,
        plan: DailyPlan
    ) -> StudyDirective {
        let weakConcepts = extractWeakConcepts(from: conceptStates, topicGaps: course.topicGaps)
        let daysRemaining = course.daysUntilExam ?? 0
        let masteryPercent = Int(course.overallMastery * 100)
        let estimatedMinutes = estimateSessionTime(dueReviewCards: course.dueCards, newCards: 0)

        let weakDescription: String
        if !weakConcepts.isEmpty {
            weakDescription = weakConcepts.joined(separator: " and ")
                + " \(weakConcepts.count == 1 ? "is" : "are") at \(masteryPercent)% mastery"
        } else {
            weakDescription = "overall mastery is at \(masteryPercent)%"
        }

        let headline: String
        if let firstWeak = weakConcepts.first {
            headline = "\(firstWeak) Needs You"
        } else {
            headline = "\(course.courseName) Exam in \(daysRemaining) \(daysRemaining == 1 ? "Day" : "Days")"
        }

        let body = "Your \(course.courseName) exam is in \(daysRemaining) \(daysRemaining == 1 ? "day" : "days"). "
            + "\(weakDescription.prefix(1).uppercased())\(weakDescription.dropFirst()). "
            + "Start there \u{2014} \(course.dueCards) cards due."

        return StudyDirective(
            headline: headline,
            body: body,
            courseId: course.courseId,
            courseName: course.courseName,
            weakConcepts: weakConcepts,
            sessionType: .examPrep,
            estimatedMinutes: estimatedMinutes,
            urgency: .critical,
            examCountdown: StudyDirective.ExamCountdown(
                courseName: course.courseName,
                daysRemaining: daysRemaining,
                estimatedScore: course.overallMastery
            )
        )
    }

    private func highPriorityDirective(
        course: DailyPlan.CoursePlanItem,
        conceptStates: [ConceptState],
        snapshot: SessionCuratorSnapshot,
        plan: DailyPlan
    ) -> StudyDirective {
        let weakConcepts = extractWeakConcepts(from: conceptStates, topicGaps: course.topicGaps)
        let estimatedMinutes = estimateSessionTime(dueReviewCards: plan.totalDueCards, newCards: 0)

        let headline: String
        let body: String
        let examCountdown: StudyDirective.ExamCountdown?

        if let days = course.daysUntilExam {
            let weakSuffix: String
            if !weakConcepts.isEmpty {
                weakSuffix = " Focus on \(weakConcepts.joined(separator: ", "))."
            } else {
                weakSuffix = ""
            }
            headline = "\(course.courseName) Needs Attention"
            body = "Exam in \(days) \(days == 1 ? "day" : "days") with \(course.dueCards) cards due."
                + weakSuffix
            examCountdown = StudyDirective.ExamCountdown(
                courseName: course.courseName,
                daysRemaining: days,
                estimatedScore: course.overallMastery
            )
        } else {
            headline = "\(plan.totalDueCards) Cards Overdue"
            body = "You have \(plan.totalDueCards) cards due across \(plan.courseItems.count) "
                + "\(plan.courseItems.count == 1 ? "course" : "courses"). Chip away at the backlog today."
            examCountdown = nil
        }

        return StudyDirective(
            headline: headline,
            body: body,
            courseId: course.courseId,
            courseName: course.courseName,
            weakConcepts: weakConcepts,
            sessionType: course.daysUntilExam != nil ? .examPrep : .review,
            estimatedMinutes: estimatedMinutes,
            urgency: .high,
            examCountdown: examCountdown
        )
    }

    private func standardReviewDirective(
        plan: DailyPlan,
        conceptStates: [ConceptState],
        snapshot: SessionCuratorSnapshot
    ) -> StudyDirective {
        let weakConcepts = extractWeakConcepts(from: conceptStates)
        let courseCount = plan.courseItems.count
        let estimatedMinutes = estimateSessionTime(dueReviewCards: plan.totalDueCards, newCards: 0)

        let headline: String
        let body: String
        var examCountdown: StudyDirective.ExamCountdown?
        let topCourse = plan.courseItems.first

        if courseCount == 1, let course = topCourse {
            headline = "\(plan.totalDueCards) Cards in \(course.courseName)"
            let weakSuffix: String
            if let firstWeak = weakConcepts.first {
                let masteryPercent = conceptStates
                    .first { $0.displayName == firstWeak }
                    .map { Int($0.pKnown * 100) } ?? 50
                weakSuffix = " \(firstWeak) still shaky at \(masteryPercent)%."
            } else {
                weakSuffix = " You're making solid progress."
            }
            body = "\(course.courseName) has \(course.dueCards) cards due." + weakSuffix

            if let days = course.daysUntilExam {
                examCountdown = StudyDirective.ExamCountdown(
                    courseName: course.courseName,
                    daysRemaining: days,
                    estimatedScore: course.overallMastery
                )
            }
        } else if courseCount > 1 {
            headline = "\(plan.totalDueCards) Cards Across \(courseCount) Courses"
            let summaries = plan.courseItems.prefix(2).map { course -> String in
                "\(course.courseName) has \(course.dueCards) cards"
            }
            let weakSuffix: String
            if let firstWeak = weakConcepts.first {
                weakSuffix = " \(firstWeak) needs extra attention."
            } else {
                weakSuffix = ""
            }
            body = summaries.joined(separator: ". ") + "." + weakSuffix

            if let course = topCourse, let days = course.daysUntilExam {
                examCountdown = StudyDirective.ExamCountdown(
                    courseName: course.courseName,
                    daysRemaining: days,
                    estimatedScore: course.overallMastery
                )
            }
        } else {
            // Due cards exist but no courses (unlinked cards)
            headline = "\(plan.totalDueCards) Cards Due"
            body = "You have \(plan.totalDueCards) cards ready for review."
            examCountdown = nil
        }

        return StudyDirective(
            headline: headline,
            body: body,
            courseId: topCourse?.courseId,
            courseName: topCourse?.courseName,
            weakConcepts: weakConcepts,
            sessionType: .review,
            estimatedMinutes: estimatedMinutes,
            urgency: .normal,
            examCountdown: examCountdown
        )
    }

    private func exploreNewDirective(plan: DailyPlan) -> StudyDirective {
        let headline = "New Material Ready"
        let body: String

        if let topCourse = plan.courseItems.first, topCourse.totalCards > 0 {
            let newCount = topCourse.totalCards - topCourse.dueCards
            body = "Your \(topCourse.courseName) material has \(newCount) cards to explore. Start with the basics."
        } else {
            body = "No cards are due, but you can import new material or study ahead to stay sharp."
        }

        return StudyDirective(
            headline: headline,
            body: body,
            courseId: plan.courseItems.first?.courseId,
            courseName: plan.courseItems.first?.courseName,
            weakConcepts: [],
            sessionType: .learnNew,
            estimatedMinutes: 0,
            urgency: .normal,
            examCountdown: nil
        )
    }

    private func celebrationDirective(plan: DailyPlan) -> StudyDirective {
        .empty
    }

    // MARK: - Helpers

    /// Extract the top 3 weakest concepts (pKnown < 0.5), optionally cross-referenced with topic gaps.
    private func extractWeakConcepts(
        from conceptStates: [ConceptState],
        topicGaps: [DailyPlan.TopicGap] = []
    ) -> [String] {
        let weak = conceptStates
            .filter { $0.pKnown < 0.5 }
            .sorted { $0.pKnown < $1.pKnown }

        if !topicGaps.isEmpty {
            let gapNames = Set(topicGaps.map { $0.topicName.lowercased() })
            // Prefer concepts that match topic gaps
            let matched = weak.filter { gapNames.contains($0.key.lowercased()) || gapNames.contains($0.displayName.lowercased()) }
            if !matched.isEmpty {
                return Array(matched.prefix(3).map(\.displayName))
            }
        }

        return Array(weak.prefix(3).map(\.displayName))
    }

    /// Estimate session time: ~30s per due review card, ~2min per new card, cap at 45 min.
    private func estimateSessionTime(dueReviewCards: Int, newCards: Int) -> Int {
        let reviewSeconds = Double(dueReviewCards) * 30.0
        let newSeconds = Double(newCards) * 120.0
        let totalMinutes = Int(ceil((reviewSeconds + newSeconds) / 60.0))
        return min(totalMinutes, 45)
    }
}
