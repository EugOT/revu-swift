import Foundation
import Combine

enum DeckStudyMode: String, CaseIterable, Identifiable {
    case dueToday
    case all

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .dueToday:
            return "Due Today"
        case .all:
            return "All Cards"
        }
    }

    var description: String {
        switch self {
        case .dueToday:
            return "Reviews scheduled for today"
        case .all:
            return "Entire deck, regardless of schedule"
        }
    }

    var icon: String {
        switch self {
        case .dueToday:
            return "calendar"
        case .all:
            return "square.stack"
        }
    }
}

@MainActor
final class StudySessionViewModel: ObservableObject {
    enum QueueMode {
        case standard
        case ahead
    }

    @Published private(set) var currentCard: Card?
    @Published private(set) var queue: [Card] = []
    @Published private(set) var completed: Int = 0
    @Published private(set) var newCount: Int = 0
    @Published private(set) var reviewCount: Int = 0
    @Published private(set) var lapseCount: Int = 0
    @Published var isRevealed: Bool = false
    @Published var isFinished: Bool = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var deckLookup: [UUID: Deck] = [:]
    @Published private(set) var gradePreviews: [ReviewGrade: ScheduleResult] = [:]
    @Published private(set) var queueMode: QueueMode = .standard
    @Published private(set) var pendingIntervention: PendingIntervention?
    @Published private(set) var currentItem: SessionItem?
    @Published private(set) var sessionXP: Int = 0
    @Published private(set) var milestonesTriggered: Set<Int> = []
    @Published private(set) var maxStreak: Int = 0
    @Published private(set) var hintLevelByCard: [UUID: Int] = [:]
    @Published private(set) var challengeModeEnabled: Bool = false

    var currentDeckName: String {
        guard let card = currentCard, let deckId = card.deckId else { return "" }
        return deckLookup[deckId]?.name ?? ""
    }

    var isCrossCourseSession: Bool {
        crossCourseIds != nil
    }

    /// Exposes keyboard hints setting for UI grade buttons.
    var showKeyboardHints: Bool {
        settings.keyboardHints
    }

    private let dataController: DataController
    private var sessionEngine: MixedFormatSessionEngine
    private let cardService: CardService
    private let srsService: SRSStateService
    private let reviewLogService: ReviewLogService
    private let studyEventLogService: StudyEventLogService
    private let deckService: DeckService
    private let courseService: CourseService
    private var settings: UserSettings
    private let deckFilter: Deck?
    private let deckStudyMode: DeckStudyMode
    private let crossCourseIds: [UUID]?
    private var sessionId: UUID?
    private var activeStart: Date?
    private var durationAccumulator: TimeInterval = 0
    private var decksNeedingPlanRefresh: Set<UUID> = []
    private let aheadHorizonDays: Int = 3
    private var elapsedTimerCancellable: AnyCancellable?
    
    // Adaptive difficulty tracking
    private var rollingOutcomes: [Bool] = []
    private let adaptivePolicy = AdaptiveDifficultyPolicy()

    // Session graduation tracking — counts correct answers per card in this session
    private var sessionGraduations: [UUID: Int] = [:]

    // Interventions
    private let confusionDetector = ConfusionDetector()
    private let interventionPolicy = InterventionPolicy()
    private var lastInterventionOfferAt: Date?
    private var interventionsSuppressedThisSession: Bool = false
    private var lastAnsweredConceptKeys: Set<String> = []

    /// Total item count including completed, current, and remaining in the mixed-format engine.
    var totalItemCount: Int {
        completed + sessionEngine.remainingCount + (currentItem == nil ? 0 : 1)
    }

    var isStudyingAhead: Bool {
        queueMode == .ahead
    }

    var aheadWindowDescription: String {
        "next \(aheadHorizonDays) day\(aheadHorizonDays == 1 ? "" : "s")"
    }

    init(deck: Deck? = nil, mode: DeckStudyMode = .dueToday, courseIds: [UUID]? = nil, dataController: DataController) {
        self.deckFilter = deck
        self.deckStudyMode = deck == nil ? .dueToday : mode
        self.crossCourseIds = courseIds
        self.dataController = dataController
        self.sessionEngine = MixedFormatSessionEngine(storage: dataController.storage)
        self.cardService = CardService(storage: dataController.storage)
        self.srsService = SRSStateService(storage: dataController.storage)
        self.reviewLogService = ReviewLogService(storage: dataController.storage)
        self.studyEventLogService = StudyEventLogService(storage: dataController.storage)
        self.deckService = DeckService(storage: dataController.storage)
        self.courseService = CourseService(storage: dataController.storage)
        self.settings = UserSettings()
        if let deck {
            deckLookup[deck.id] = deck
        }
        Task { await bootstrap() }
    }

    convenience init(deck: Deck? = nil, mode: DeckStudyMode = .dueToday, courseIds: [UUID]? = nil) {
        self.init(deck: deck, mode: mode, courseIds: courseIds, dataController: DataController.shared)
    }

    deinit {
        elapsedTimerCancellable?.cancel()
    }

    func reloadSettings() {
        Task { await loadSettings() }
    }

    func loadQueue() {
        Task { await loadQueueInternal(mode: queueMode) }
    }

    func restartScheduledQueue() {
        Task { await loadQueueInternal(mode: .standard) }
    }

    func loadAheadQueue() {
        Task { await loadQueueInternal(mode: .ahead) }
    }

    func advance() {
        // Try mixed-format engine first; fall back to legacy card queue
        if let nextItem = sessionEngine.next() {
            isFinished = false
            isRevealed = false
            currentItem = nextItem

            switch nextItem {
            case .flashcard(let card):
                currentCard = card
                queue = sessionEngine.remainingFlashcards()
                activeStart = Date()
                startElapsedTimer()
                if card.srs.queue == .new {
                    newCount += 1
                } else {
                    reviewCount += 1
                }
                refreshGradePreviews(for: card)
                Task { await ensureDeck(for: card) }

                // Emit cardPresented event
                if let sessionId = sessionId {
                    let successRate = rollingOutcomes.isEmpty ? nil : Double(rollingOutcomes.filter { $0 }.count) / Double(rollingOutcomes.count)
                    let chosenPSuccess = card.srs.predictedRecall(retentionTarget: settings.retentionTarget)
                    let conceptKeys = extractConceptKeys(for: card)

                    let event = StudyEvent(
                        id: UUID(),
                        timestamp: Date(),
                        sessionId: sessionId,
                        kind: .cardPresented,
                        deckId: card.deckId,
                        cardId: card.id,
                        queueMode: queueMode == .standard ? "standard" : "ahead",
                        attemptIndex: nil,
                        conceptsAtTime: conceptKeys.isEmpty ? nil : conceptKeys,
                        adaptiveSuccessRate: successRate,
                        adaptiveChosenPSuccess: chosenPSuccess
                    )
                    Task { await studyEventLogService.append(event) }
                }

            default:
                // Non-flashcard items don't use card state
                currentCard = nil
                refreshGradePreviews(for: nil)
            }
            return
        }

        // Legacy fallback: advance from the card queue directly
        guard !queue.isEmpty else {
            stopElapsedTimer(resetActiveStart: true)
            currentCard = nil
            currentItem = nil
            isFinished = true
            refreshGradePreviews(for: nil)
            return
        }
        isFinished = false
        isRevealed = false
        activeStart = Date()
        let next = queue.removeFirst()
        currentCard = next
        currentItem = .flashcard(next)
        startElapsedTimer()
        if next.srs.queue == .new {
            newCount += 1
        } else {
            reviewCount += 1
        }
        refreshGradePreviews(for: next)
        Task { await ensureDeck(for: next) }

        // Emit cardPresented event
        if let sessionId = sessionId {
            // Calculate adaptive diagnostics
            let successRate = rollingOutcomes.isEmpty ? nil : Double(rollingOutcomes.filter { $0 }.count) / Double(rollingOutcomes.count)
            let chosenPSuccess = next.srs.predictedRecall(retentionTarget: settings.retentionTarget)
            let conceptKeys = extractConceptKeys(for: next)

            let event = StudyEvent(
                id: UUID(),
                timestamp: Date(),
                sessionId: sessionId,
                kind: .cardPresented,
                deckId: next.deckId,
                cardId: next.id,
                queueMode: queueMode == .standard ? "standard" : "ahead",
                attemptIndex: nil,
                conceptsAtTime: conceptKeys.isEmpty ? nil : conceptKeys,
                adaptiveSuccessRate: successRate,
                adaptiveChosenPSuccess: chosenPSuccess
            )
            Task { await studyEventLogService.append(event) }
        }
    }

    func reveal() {
        guard currentCard != nil else { return }
        isRevealed = true
    }

    func recordOutcome(_ outcome: RecallOutcome) {
        Task { await processOutcome(outcome) }
    }

    /// Submit a 4-grade response directly (Again/Hard/Good/Easy).
    /// Bypasses RecallOutcome conversion for precise scheduling control.
    func recordGrade(_ grade: ReviewGrade) {
        Task { await processGradeOutcome(grade) }
    }

    /// Count of consecutive correct answers at the tail of rollingOutcomes.
    var currentStreak: Int {
        var count = 0
        for outcome in rollingOutcomes.reversed() {
            if outcome { count += 1 } else { break }
        }
        return count
    }

    func recordItemOutcome(for item: SessionItem, wasSuccessful: Bool) {
        Task {
            _ = await sessionEngine.processOutcome(
                for: item,
                wasSuccessful: wasSuccessful,
                confusionScore: 0,
                courseId: nil
            )
            completed += 1
            advance()
        }
    }

    func requestExplanation(for card: Card) {
        Task {
            await sessionEngine.insertExplanation(
                for: card,
                courseId: card.deckId.flatMap { deckLookup[$0]?.courseId }
            )
            advance()
        }
    }

    enum TutorHandoffMode {
        case hint
        case coach
        case explain
    }

    struct TutorHandoff: Sendable, Equatable {
        var deckId: UUID?
        var draftMessage: String
    }

    func deferPendingInterventionForSession() {
        guard let intervention = pendingIntervention else { return }
        interventionsSuppressedThisSession = true
        logInterventionAction("deferred", intervention: intervention)
        pendingIntervention = nil
    }

    func disableProactiveInterventions() {
        guard let intervention = pendingIntervention else { return }
        interventionsSuppressedThisSession = true
        settings.proactiveInterventionsEnabled = false
        Task { await dataController.save(settings: settings) }
        logInterventionAction("disabled", intervention: intervention)
        pendingIntervention = nil
    }

    func prepareTutorHandoff(mode: TutorHandoffMode) async -> TutorHandoff? {
        guard let intervention = pendingIntervention else { return nil }
        let action: String
        switch mode {
        case .hint:
            action = "accepted_hint"
        case .coach:
            action = "accepted_coach"
        case .explain:
            action = "accepted_explain"
        }

        logInterventionAction(action, intervention: intervention)
        pendingIntervention = nil
        lastInterventionOfferAt = Date()

        let draft = await tutorDraftMessage(for: intervention, mode: mode)
        return TutorHandoff(deckId: intervention.context.deckId, draftMessage: draft)
    }

    func buryCurrentCard() {
        Task { await buryCard() }
    }

    func suspendCurrentCard() {
        Task { await suspendCard() }
    }

    func deckName(for card: Card) -> String {
        guard let deckId = card.deckId else { return "" }
        return deckLookup[deckId]?.name ?? ""
    }

    private func bootstrap() async {
        await loadSettings()
        await loadQueueInternal(mode: .standard)
    }

    private func loadSettings() async {
        if let updated = try? await dataController.loadSettings() {
            await MainActor.run {
                settings = updated
                challengeModeEnabled = updated.challengeModeDefaultEnabled
                refreshGradePreviews(for: currentCard)
            }
        }
    }

    private func loadQueueInternal(mode: QueueMode) async {
        await loadSettings()
        decksNeedingPlanRefresh.removeAll()
        stopElapsedTimer(resetActiveStart: true)
        
        // Create new sessionId for this study session
        sessionId = UUID()
        pendingIntervention = nil
        lastInterventionOfferAt = nil
        interventionsSuppressedThisSession = false
        lastAnsweredConceptKeys = []
        sessionXP = 0
        milestonesTriggered.removeAll()
        maxStreak = 0
        hintLevelByCard = [:]
        challengeModeEnabled = settings.challengeModeDefaultEnabled
        
        let now = Date()
        let decks = await deckService.allDecks(includeArchived: false)
        for deck in decks {
            deckLookup[deck.id] = deck
        }

        // Cross-course session: load cards from all linked decks with priority ordering
        if let courseIds = crossCourseIds, !courseIds.isEmpty {
            let crossCourseCards = await loadCrossCourseCards(courseIds: courseIds, now: now)
            let adaptiveOrdered = applyAdaptiveDifficulty(to: crossCourseCards)
            _ = sessionEngine.buildQueue(from: adaptiveOrdered)
            queue = adaptiveOrdered
            completed = 0
            newCount = 0
            reviewCount = 0
            lapseCount = 0
            durationAccumulator = 0
            elapsedSeconds = 0
            queueMode = mode
            rollingOutcomes = []
            sessionGraduations = [:]
            isFinished = queue.isEmpty
            if let card = queue.first {
                await ensureDeck(for: card)
            }
            if let sessionId = sessionId {
                let event = StudyEvent(
                    id: UUID(),
                    timestamp: now,
                    sessionId: sessionId,
                    kind: .sessionStarted,
                    deckId: nil,
                    queueMode: "cross-course"
                )
                await studyEventLogService.append(event)
            }
            advance()
            return
        }

        let hierarchy = DeckHierarchy(decks: decks)
        let deckFilterIds = deckFilter.map { Set(hierarchy.subtreeDeckIDs(of: $0.id)) }

        var horizon = mode == .ahead ? resolveAheadHorizon(now: now, decks: decks) : 0
        var dueCards = await srsService.dueCards(for: now, settings: settings, horizonDays: horizon)
        if mode == .ahead {
            let expansionCap = resolveAheadExpansionCap(now: now, decks: decks, initial: horizon)
            var expanded = horizon
            while dueCards.isEmpty && expanded < expansionCap {
                expanded = min(expansionCap, expanded + aheadHorizonDays)
                dueCards = await srsService.dueCards(for: now, settings: settings, horizonDays: expanded)
            }
            horizon = max(horizon, expanded)
        }

        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: max(horizon + 1, 1),
            to: Calendar.current.startOfDay(for: now)
        ) ?? now

        let dueDateDecks = dueDateDecks(for: deckFilter, in: decks)
        let overridesNewLimit = !dueDateDecks.isEmpty
        let isDeckSpecificDueDate = deckFilter.map { candidate in
            dueDateDecks.contains(where: { $0.id == candidate.id })
        } ?? false

        var newCards: [Card] = []
        if overridesNewLimit {
            let dueDriven = await dueDateDrivenNewCards(for: dueDateDecks, cutoff: cutoffDate, now: now)
            newCards.append(contentsOf: dueDriven)
        }

        if settings.dailyNewLimit > 0 && (!overridesNewLimit || !isDeckSpecificDueDate) {
            let baseLimit = settings.dailyNewLimit
            let limit = mode == .ahead ? max(baseLimit, baseLimit * 2) : baseLimit
            let poolLimit = max(max(limit * 3, limit + 20), 60)
            var pool = await srsService.newCards(limit: poolLimit)
            if overridesNewLimit {
                let dueDeckIds = Set(dueDateDecks.map(\.id))
                pool = pool.filter { card in
                    guard let deckId = card.deckId else { return true }
                    return !dueDeckIds.contains(deckId)
                }
            }
            if let deckFilterIds {
                pool = pool.filter { card in
                    guard let deckId = card.deckId else { return false }
                    return deckFilterIds.contains(deckId)
                }
            }
            newCards.append(contentsOf: pool.prefix(limit))
        }

        let ordered: [Card]
        if let deckFilter, let deckFilterIds {
            switch deckStudyMode {
            case .dueToday:
                let filteredDue = dueCards.filter { $0.deckId.map(deckFilterIds.contains) ?? false }
                let filteredNew = newCards.filter { $0.deckId.map(deckFilterIds.contains) ?? false }
                ordered = prioritize(dueCards: filteredDue, newCards: filteredNew)
            case .all:
                ordered = await deckWideQueue(rootDeckId: deckFilter.id, deckIds: deckFilterIds, dueCards: dueCards, newCards: newCards)
            }
        } else {
            ordered = prioritize(dueCards: dueCards, newCards: newCards)
        }
        
        // Apply adaptive difficulty reordering
        let adaptiveOrdered = applyAdaptiveDifficulty(to: ordered)

        _ = sessionEngine.buildQueue(from: adaptiveOrdered)
        queue = adaptiveOrdered
        completed = 0
        newCount = 0
        reviewCount = 0
        lapseCount = 0
        durationAccumulator = 0
        elapsedSeconds = 0
        queueMode = mode
        rollingOutcomes = [] // Reset adaptive history for new session
        sessionGraduations = [:]
        isFinished = queue.isEmpty
        if let card = queue.first {
            await ensureDeck(for: card)
        }
        
        // Emit sessionStarted event
        if let sessionId = sessionId {
            let event = StudyEvent(
                id: UUID(),
                timestamp: now,
                sessionId: sessionId,
                kind: .sessionStarted,
                deckId: deckFilter?.id,
                queueMode: mode == .standard ? "standard" : "ahead"
            )
            await studyEventLogService.append(event)
        }
        
        advance()
    }

    private func prioritize(dueCards: [Card], newCards: [Card]) -> [Card] {
        var combined: [UUID: Card] = [:]
        for card in dueCards + newCards {
            guard !card.isSuspended else { continue }
            combined[card.id] = card
        }
        return combined.values.sorted { lhs, rhs in
            if lhs.srs.dueDate == rhs.srs.dueDate {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.srs.dueDate < rhs.srs.dueDate
        }
    }

    private func deckWideQueue(rootDeckId: UUID, deckIds: Set<UUID>, dueCards: [Card], newCards: [Card]) async -> [Card] {
        let prioritized = prioritize(
            dueCards: dueCards.filter { $0.deckId.map(deckIds.contains) ?? false },
            newCards: newCards.filter { $0.deckId.map(deckIds.contains) ?? false }
        )
        let prioritizedIds = Set(prioritized.map { $0.id })
        let deckCards = await cardService.cards(deckId: rootDeckId).filter { !$0.isSuspended }
        let remainder = deckCards.filter { !prioritizedIds.contains($0.id) }.sorted { lhs, rhs in
            if lhs.srs.dueDate == rhs.srs.dueDate {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.srs.dueDate < rhs.srs.dueDate
        }
        return prioritized + remainder
    }

    private func loadCrossCourseCards(courseIds: [UUID], now: Date) async -> [Card] {
        struct CoursePriority {
            let courseId: UUID
            let examProximityWeight: Double
            let mastery: Double
            let deckIds: Set<UUID>
        }

        var priorities: [CoursePriority] = []
        for courseId in courseIds {
            let progress = await courseService.courseProgress(courseId: courseId)
            let linkedDecks = await courseService.decks(courseId: courseId)
            let deckIds = Set(linkedDecks.map(\.id))

            let examWeight: Double
            if let days = progress.daysUntilExam {
                if days <= 0 {
                    examWeight = 0.3
                } else if days <= 7 {
                    examWeight = 3.0
                } else if days <= 14 {
                    examWeight = 2.0
                } else if days <= 30 {
                    examWeight = 1.5
                } else {
                    examWeight = 1.0
                }
            } else {
                examWeight = 0.5
            }

            priorities.append(CoursePriority(
                courseId: courseId,
                examProximityWeight: examWeight,
                mastery: progress.overallMastery,
                deckIds: deckIds
            ))
        }

        // Build a lookup from deckId → priority score
        var deckPriority: [UUID: Double] = [:]
        for p in priorities {
            let score = p.examProximityWeight * (1.0 - p.mastery)
            for deckId in p.deckIds {
                deckPriority[deckId] = score
            }
        }

        // Collect all due cards from linked decks
        let allDeckIds = priorities.flatMap(\.deckIds)
        var allCards: [Card] = []
        for deckId in allDeckIds {
            let cards = await cardService.cards(deckId: deckId, includeSubdecks: false)
            let dueCards = cards.filter { !$0.isSuspended && $0.srs.dueDate <= now }
            allCards.append(contentsOf: dueCards)
        }

        // Sort: higher priority score first, then by due date
        return allCards.sorted { lhs, rhs in
            let lhsScore = lhs.deckId.flatMap { deckPriority[$0] } ?? 0
            let rhsScore = rhs.deckId.flatMap { deckPriority[$0] } ?? 0
            if abs(lhsScore - rhsScore) > 0.01 {
                return lhsScore > rhsScore
            }
            return lhs.srs.dueDate < rhs.srs.dueDate
        }
    }

    private func resolveAheadHorizon(now: Date, decks: [Deck]) -> Int {
        let base = aheadHorizonDays
        guard let offset = earliestDueOffset(in: decks, from: now) else { return base }
        return min(max(base, offset), 45)
    }

    private func resolveAheadExpansionCap(now: Date, decks: [Deck], initial: Int) -> Int {
        let baseline = max(initial, aheadHorizonDays)
        let minimumCap = max(aheadHorizonDays * 4, 14)
        let startingCap = max(baseline, minimumCap)
        guard let offset = earliestDueOffset(in: decks, from: now) else {
            return min(startingCap, 60)
        }
        return min(max(startingCap, offset), 60)
    }

    private func earliestDueOffset(in decks: [Deck], from date: Date) -> Int? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        var minimum: Int?
        for deck in decks {
            guard let due = deck.dueDate else { continue }
            let dueStart = calendar.startOfDay(for: due)
            let raw = calendar.dateComponents([.day], from: startOfDay, to: dueStart).day ?? 0
            let clamped = max(0, raw)
            if let current = minimum {
                minimum = min(current, clamped)
            } else {
                minimum = clamped
            }
        }
        return minimum
    }

    private func dueDateDecks(for filter: Deck?, in decks: [Deck]) -> [Deck] {
        let withDueDate = decks.filter { $0.dueDate != nil }
        guard let filter else { return withDueDate }
        return withDueDate.filter { $0.id == filter.id }
    }

    private func dueDateDrivenNewCards(for decks: [Deck], cutoff: Date, now: Date) async -> [Card] {
        guard !decks.isEmpty else { return [] }
        var collected: [Card] = []

        for deck in decks {
            let threshold = dueDateThreshold(for: deck, cutoff: cutoff, now: now)
            let cards = await cardService.cards(deckId: deck.id)
            for card in cards where !card.isSuspended {
                let state = card.srs
                guard state.queue == .new && state.fsrsReps == 0 else { continue }
                if state.dueDate <= threshold {
                    collected.append(card)
                }
            }
        }

        return collected.sorted { lhs, rhs in
            if lhs.srs.dueDate == rhs.srs.dueDate {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.srs.dueDate < rhs.srs.dueDate
        }
    }

    private func dueDateThreshold(for deck: Deck, cutoff: Date, now: Date) -> Date {
        guard let dueDate = deck.dueDate else { return cutoff }
        if dueDate <= now {
            return cutoff
        }
        return min(cutoff, dueDate)
    }

    var sessionContextTitle: String {
        if let deck = deckFilter {
            switch deckStudyMode {
            case .dueToday:
                return queueMode == .ahead ? "\(deck.name) • Ahead" : deck.name
            case .all:
                let base = "\(deck.name) • All Cards"
                return queueMode == .ahead ? "\(base) • Ahead" : base
            }
        }
        return queueMode == .ahead ? "Studying Ahead" : "Due Today"
    }

    var sessionContextSubtitle: String {
        if deckFilter != nil {
            switch deckStudyMode {
            case .dueToday:
                return queueMode == .ahead ? "Working ahead on the \(aheadWindowDescription)" : "Due cards scheduled for today"
            case .all:
                return queueMode == .ahead ? "Complete run-through with \(aheadWindowDescription) of work" : "Complete run-through of this deck"
            }
        }
        return queueMode == .ahead ? "Working ahead on the \(aheadWindowDescription) across all decks" : "Due cards across all decks"
    }

    var canShuffleUpcoming: Bool {
        queue.count > 1
    }

    var canShuffleEntireSession: Bool {
        let active = currentCard == nil ? 0 : 1
        return active + queue.count > 1
    }

    private func processOutcome(_ outcome: RecallOutcome) async {
        guard var card = currentCard else { return }
        pendingIntervention = nil
        let now = Date()
        let elapsed = now.timeIntervalSince(activeStart ?? now)
        let elapsedMs = Int((elapsed * 1000).rounded())
        updateElapsed(now: now)

        var state = card.srs
        let previousSnapshot = SRSStateSnapshot(model: state)
        let result = Scheduler.review(
            state: &state,
            outcome: outcome,
            settings: settings,
            now: now,
            deckDueDate: deckDueDate(for: card),
            responseTime: elapsed
        )
        card.srs = state
        card.updatedAt = now

        if outcome == .forgot {
            lapseCount += 1
        }

        let assignedGrade = Scheduler.grade(for: outcome)
        let log = ReviewLog(
            cardId: card.id,
            timestamp: now,
            grade: assignedGrade.rawValue,
            elapsedMs: elapsedMs,
            prevInterval: previousSnapshot.interval,
            nextInterval: state.interval,
            prevEase: previousSnapshot.easeFactor,
            nextEase: state.easeFactor,
            prevStability: previousSnapshot.stability,
            nextStability: state.stability,
            prevDifficulty: previousSnapshot.difficulty,
            nextDifficulty: state.difficulty,
            predictedRecall: result.predictedRecall,
            requestedRetention: settings.retentionTarget
        )

        await reviewLogService.append(log)
        
        // Emit cardAnswered event
        let conceptKeys = extractConceptKeys(for: card)
        if let sessionId = sessionId {
            let event = StudyEvent(
                id: UUID(),
                timestamp: now,
                sessionId: sessionId,
                kind: .cardAnswered,
                deckId: card.deckId,
                cardId: card.id,
                queueMode: queueMode == .standard ? "standard" : "ahead",
                conceptsAtTime: conceptKeys.isEmpty ? nil : conceptKeys,
                elapsedMs: elapsedMs,
                grade: assignedGrade.rawValue,
                predictedRecallAtStart: result.predictedRecall
            )
            await studyEventLogService.append(event)
        }

        // Confusion detection + intervention decision (data-only; UI in next plan)
        let wasSuccessful = (outcome == .rememberedEasy)
        let consecutiveFailures = consecutiveFailureCount(priorOutcomes: rollingOutcomes, currentWasSuccessful: wasSuccessful)
        let repeatedConcept = !conceptKeys.isEmpty && !lastAnsweredConceptKeys.isEmpty && !Set(conceptKeys).isDisjoint(with: lastAnsweredConceptKeys)
        let confusion = confusionDetector.score(input: ConfusionDetector.Input(
            outcome: outcome,
            elapsedMs: elapsedMs,
            predictedRecallAtStart: result.predictedRecall,
            consecutiveFailures: consecutiveFailures,
            repeatedConcept: repeatedConcept
        ))

        if let sessionId = sessionId,
           let kind = interventionPolicy.decide(input: InterventionPolicy.Input(
                now: now,
                settings: settings,
                confusion: confusion,
                consecutiveFailures: consecutiveFailures,
                lastOfferedAt: lastInterventionOfferAt,
                suppressedThisSession: interventionsSuppressedThisSession,
                outcome: outcome
           )) {
            lastInterventionOfferAt = now
            pendingIntervention = PendingIntervention(
                kind: kind,
                score: confusion.score,
                reasons: confusion.reasons,
                createdAt: now,
                context: PendingIntervention.Context(
                    deckId: card.deckId,
                    deckName: card.deckId.flatMap { deckLookup[$0]?.name },
                    cardId: card.id,
                    cardFront: card.front,
                    cardBack: card.back,
                    conceptKeys: conceptKeys,
                    elapsedMs: elapsedMs,
                    predictedRecallAtStart: result.predictedRecall,
                    grade: assignedGrade.rawValue
                )
            )

            let offerEvent = StudyEvent(
                id: UUID(),
                timestamp: now,
                sessionId: sessionId,
                kind: .interventionOffered,
                deckId: card.deckId,
                cardId: card.id,
                queueMode: queueMode == .standard ? "standard" : "ahead",
                conceptsAtTime: conceptKeys.isEmpty ? nil : conceptKeys,
                elapsedMs: elapsedMs,
                grade: assignedGrade.rawValue,
                predictedRecallAtStart: result.predictedRecall,
                confusionScore: confusion.score,
                confusionReasons: confusion.reasons.map(\.rawValue),
                interventionKind: kind.rawValue
            )
            await studyEventLogService.append(offerEvent)
        }
        lastAnsweredConceptKeys = Set(conceptKeys)

        // Feed outcome into mixed-format engine for adaptive insertions
        let sessionItem = SessionItem.flashcard(card)
        _ = await sessionEngine.processOutcome(
            for: sessionItem,
            wasSuccessful: wasSuccessful,
            confusionScore: confusion.score,
            courseId: card.deckId.flatMap { deckLookup[$0]?.courseId }
        )

        await cardService.upsert(card: card, updateTimestamp: false)
        if queueMode == .ahead, let deckId = card.deckId {
            decksNeedingPlanRefresh.insert(deckId)
        }
        if settings.burySiblings, let currentSiblingKey = siblingKey(for: card) {
            queue.removeAll { candidate in
                guard candidate.id != card.id else { return false }
                return siblingKey(for: candidate) == currentSiblingKey
            }
        }
        // Smart re-queue logic with session graduation tracking
        let wasCorrect = (outcome != .forgot)
        let sessionCorrectCount = sessionGraduations[card.id, default: 0]
        if wasCorrect {
            sessionGraduations[card.id] = sessionCorrectCount + 1
        }

        let shouldRequeue: Bool
        if outcome == .forgot {
            // Always re-queue failed cards
            shouldRequeue = true
        } else if sessionCorrectCount >= 2 {
            // Answered correctly 3+ times this session (current + 2 prior) — graduate out
            shouldRequeue = false
        } else if result.nextInterval <= 600 {
            // Very short interval (<=10 min) and not yet graduated — re-queue for reinforcement
            shouldRequeue = true
        } else {
            // Interval > 10 min — FSRS has determined this card is learned for now
            shouldRequeue = false
        }

        if shouldRequeue {
            // Insert re-queued card 3-5 positions from end to add spacing (not appended immediately)
            let insertIndex = max(0, queue.count - min(4, queue.count))
            queue.insert(card, at: insertIndex)
        }
        
        // Track outcome for adaptive difficulty
        rollingOutcomes.append(wasSuccessful)
        updateMaxStreak()

        completed += 1
        currentCard = nil
        advance()
        if queue.isEmpty {
            Task { @MainActor in await refreshAheadPlansIfNeeded() }
        }
    }

    /// Process a 4-grade outcome directly, bypassing RecallOutcome conversion.
    private func processGradeOutcome(_ grade: ReviewGrade) async {
        guard var card = currentCard else { return }
        pendingIntervention = nil
        let now = Date()
        let elapsed = now.timeIntervalSince(activeStart ?? now)
        let elapsedMs = Int((elapsed * 1000).rounded())
        updateElapsed(now: now)

        var state = card.srs
        let previousSnapshot = SRSStateSnapshot(model: state)
        let snapshot = SRSStateSnapshot(model: state)
        let config = SchedulerConfig.from(settings: settings)
        let result = Scheduler.review(
            state: snapshot,
            grade: grade,
            now: now,
            config: config,
            deckDueDate: deckDueDate(for: card),
            responseTime: elapsed
        )
        result.updatedState.applying(to: &state)
        card.srs = state
        card.updatedAt = now

        if grade == .again {
            lapseCount += 1
        }

        let log = ReviewLog(
            cardId: card.id,
            timestamp: now,
            grade: grade.rawValue,
            elapsedMs: elapsedMs,
            prevInterval: previousSnapshot.interval,
            nextInterval: state.interval,
            prevEase: previousSnapshot.easeFactor,
            nextEase: state.easeFactor,
            prevStability: previousSnapshot.stability,
            nextStability: state.stability,
            prevDifficulty: previousSnapshot.difficulty,
            nextDifficulty: state.difficulty,
            predictedRecall: result.predictedRecall,
            requestedRetention: settings.retentionTarget
        )

        await reviewLogService.append(log)

        // Emit cardAnswered event
        let conceptKeys = extractConceptKeys(for: card)
        if let sessionId = sessionId {
            let event = StudyEvent(
                id: UUID(),
                timestamp: now,
                sessionId: sessionId,
                kind: .cardAnswered,
                deckId: card.deckId,
                cardId: card.id,
                queueMode: queueMode == .standard ? "standard" : "ahead",
                conceptsAtTime: conceptKeys.isEmpty ? nil : conceptKeys,
                elapsedMs: elapsedMs,
                grade: grade.rawValue,
                predictedRecallAtStart: result.predictedRecall
            )
            await studyEventLogService.append(event)
        }

        let wasSuccessful = (grade != .again)
        let consecutiveFailures = consecutiveFailureCount(priorOutcomes: rollingOutcomes, currentWasSuccessful: wasSuccessful)
        let repeatedConcept = !conceptKeys.isEmpty && !lastAnsweredConceptKeys.isEmpty && !Set(conceptKeys).isDisjoint(with: lastAnsweredConceptKeys)
        let recallOutcome: RecallOutcome = wasSuccessful ? .rememberedEasy : .forgot
        let confusion = confusionDetector.score(input: ConfusionDetector.Input(
            outcome: recallOutcome,
            elapsedMs: elapsedMs,
            predictedRecallAtStart: result.predictedRecall,
            consecutiveFailures: consecutiveFailures,
            repeatedConcept: repeatedConcept
        ))

        if let sessionId = sessionId,
           let kind = interventionPolicy.decide(input: InterventionPolicy.Input(
                now: now,
                settings: settings,
                confusion: confusion,
                consecutiveFailures: consecutiveFailures,
                lastOfferedAt: lastInterventionOfferAt,
                suppressedThisSession: interventionsSuppressedThisSession,
                outcome: recallOutcome
           )) {
            lastInterventionOfferAt = now
            pendingIntervention = PendingIntervention(
                kind: kind,
                score: confusion.score,
                reasons: confusion.reasons,
                createdAt: now,
                context: PendingIntervention.Context(
                    deckId: card.deckId,
                    deckName: card.deckId.flatMap { deckLookup[$0]?.name },
                    cardId: card.id,
                    cardFront: card.front,
                    cardBack: card.back,
                    conceptKeys: conceptKeys,
                    elapsedMs: elapsedMs,
                    predictedRecallAtStart: result.predictedRecall,
                    grade: grade.rawValue
                )
            )

            let offerEvent = StudyEvent(
                id: UUID(),
                timestamp: now,
                sessionId: sessionId,
                kind: .interventionOffered,
                deckId: card.deckId,
                cardId: card.id,
                queueMode: queueMode == .standard ? "standard" : "ahead",
                conceptsAtTime: conceptKeys.isEmpty ? nil : conceptKeys,
                elapsedMs: elapsedMs,
                grade: grade.rawValue,
                predictedRecallAtStart: result.predictedRecall,
                confusionScore: confusion.score,
                confusionReasons: confusion.reasons.map(\.rawValue),
                interventionKind: kind.rawValue
            )
            await studyEventLogService.append(offerEvent)
        }
        lastAnsweredConceptKeys = Set(conceptKeys)

        // Feed outcome into mixed-format engine for adaptive insertions
        let sessionItem = SessionItem.flashcard(card)
        _ = await sessionEngine.processOutcome(
            for: sessionItem,
            wasSuccessful: wasSuccessful,
            confusionScore: confusion.score,
            courseId: card.deckId.flatMap { deckLookup[$0]?.courseId }
        )

        await cardService.upsert(card: card, updateTimestamp: false)
        if queueMode == .ahead, let deckId = card.deckId {
            decksNeedingPlanRefresh.insert(deckId)
        }
        if settings.burySiblings, let currentSiblingKey = siblingKey(for: card) {
            queue.removeAll { candidate in
                guard candidate.id != card.id else { return false }
                return siblingKey(for: candidate) == currentSiblingKey
            }
        }

        // Smart re-queue with session graduation tracking
        let sessionCorrectCount = sessionGraduations[card.id, default: 0]
        if wasSuccessful {
            sessionGraduations[card.id] = sessionCorrectCount + 1
        }

        let shouldRequeue: Bool
        if grade == .again {
            shouldRequeue = true
        } else if sessionCorrectCount >= 2 {
            shouldRequeue = false
        } else if result.nextInterval <= 600 {
            shouldRequeue = true
        } else {
            shouldRequeue = false
        }

        if shouldRequeue {
            let insertIndex = max(0, queue.count - min(4, queue.count))
            queue.insert(card, at: insertIndex)
        }

        // Track outcome for adaptive difficulty
        rollingOutcomes.append(wasSuccessful)
        updateMaxStreak()

        completed += 1
        currentCard = nil
        advance()
        if queue.isEmpty {
            Task { @MainActor in await refreshAheadPlansIfNeeded() }
        }
    }

    private func consecutiveFailureCount(priorOutcomes: [Bool], currentWasSuccessful: Bool) -> Int {
        guard !currentWasSuccessful else { return 0 }
        var count = 1
        for wasSuccessful in priorOutcomes.reversed() {
            if wasSuccessful {
                break
            }
            count += 1
        }
        return count
    }

    private func updateMaxStreak() {
        maxStreak = max(maxStreak, currentStreak)
    }

    private func logInterventionAction(_ action: String, intervention: PendingIntervention) {
        guard let sessionId = sessionId else { return }
        let context = intervention.context
        let conceptKeys = context.conceptKeys

        let event = StudyEvent(
            id: UUID(),
            timestamp: Date(),
            sessionId: sessionId,
            kind: .interventionAction,
            deckId: context.deckId,
            cardId: context.cardId,
            queueMode: queueMode == .standard ? "standard" : "ahead",
            conceptsAtTime: conceptKeys.isEmpty ? nil : conceptKeys,
            elapsedMs: context.elapsedMs,
            grade: context.grade,
            predictedRecallAtStart: context.predictedRecallAtStart,
            confusionScore: intervention.score,
            confusionReasons: intervention.reasons.map(\.rawValue),
            interventionKind: intervention.kind.rawValue,
            interventionAction: action
        )

        Task { await studyEventLogService.append(event) }
    }

    private func tutorDraftMessage(for intervention: PendingIntervention, mode: TutorHandoffMode) async -> String {
        let context = intervention.context
        let deckName = context.deckName ?? (context.deckId.flatMap { deckLookup[$0]?.name } ?? "this deck")

        let front = compactText(context.cardFront, limit: 600)
        let back = compactText(context.cardBack, limit: 600)

        var sections: [String] = []
        sections.append("I'm studying \(deckName) and I just got stuck on this card.")

        var signals: [String] = []
        if let elapsedMs = context.elapsedMs {
            signals.append("time: \(String(format: "%.1fs", Double(elapsedMs) / 1000.0))")
        }
        if let predicted = context.predictedRecallAtStart {
            signals.append("expected recall: \(String(format: "%.0f%%", predicted * 100))")
        }
        if let grade = context.grade {
            signals.append("grade: \(grade)")
        }
        if !signals.isEmpty {
            sections.append("Signals: " + signals.joined(separator: " • "))
        }

        if !context.conceptKeys.isEmpty {
            sections.append("Tags/concepts: " + context.conceptKeys.prefix(8).joined(separator: ", "))
        }

        sections.append("""
Card:
Front: \(front)
Back: \(back)
""")

        let instruction: String
        switch mode {
        case .hint:
            instruction = "Give me a short hint (no full answer), then ask one quick check question."
        case .coach:
            instruction = "Coach me Socratically: ask 2–4 guiding questions and wait for my response."
        case .explain:
            instruction = "Explain step-by-step, but keep it grounded and include 1–2 check questions."
        }
        sections.append("Request: \(instruction)")

        if let deckId = context.deckId, !context.conceptKeys.isEmpty {
            let related = await relatedCardsSnippet(deckId: deckId, excludeCardId: context.cardId, tags: Set(context.conceptKeys))
            if !related.isEmpty {
                sections.append("Related cards:\n" + related)
            }
        }

        return sections.joined(separator: "\n\n")
    }

    private func relatedCardsSnippet(deckId: UUID, excludeCardId: UUID, tags: Set<String>) async -> String {
        let matches = await cardService.searchCards(query: "", deckId: deckId, tags: tags)
            .filter { $0.id != excludeCardId }
            .prefix(6)

        let lines = matches.enumerated().map { index, card in
            let front = compactText(card.front, limit: 120)
            let back = compactText(card.back, limit: 120)
            return "\(index + 1). \(front) → \(back)"
        }

        return lines.joined(separator: "\n")
    }

    private func compactText(_ text: String, limit: Int) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(max(0, limit))
            .description
    }

    private func buryCard() async {
        guard var card = currentCard else { return }
        card.srs.dueDate = Date().addingTimeInterval(86_400)
        card.srs.queue = .review
        await cardService.upsert(card: card)
        if queueMode == .ahead, let deckId = card.deckId {
            decksNeedingPlanRefresh.insert(deckId)
        }
        queue.removeAll { $0.id == card.id }
        currentCard = nil
        advance()
        if queue.isEmpty {
            Task { @MainActor in await refreshAheadPlansIfNeeded() }
        }
    }

    private func suspendCard() async {
        guard var card = currentCard else { return }
        card.isSuspended = true
        card.suspendedByArchive = false
        await cardService.upsert(card: card)
        if queueMode == .ahead, let deckId = card.deckId {
            decksNeedingPlanRefresh.insert(deckId)
        }
        queue.removeAll { $0.id == card.id }
        currentCard = nil
        advance()
        if queue.isEmpty {
            Task { @MainActor in await refreshAheadPlansIfNeeded() }
        }
    }

    func shufflePending(includeCurrentCard: Bool = false) {
        if includeCurrentCard {
            guard let card = currentCard, (queue.count + 1) > 1 else { return }
            if card.srs.queue == .new {
                newCount = max(0, newCount - 1)
            } else {
                reviewCount = max(0, reviewCount - 1)
            }
            queue.append(card)
            currentCard = nil
            activeStart = nil
            isRevealed = false
            queue.shuffle()
            advance()
        } else {
            guard queue.count > 1 else { return }
            queue.shuffle()
        }
    }

    func endSessionEarly() {
        updateElapsed(now: Date())
        if let card = currentCard {
            queue.insert(card, at: 0)
        }
        currentCard = nil
        isRevealed = false
        isFinished = queue.isEmpty
        refreshGradePreviews(for: queue.first)
        Task { @MainActor in await refreshAheadPlansIfNeeded() }
    }

    private func refreshAheadPlansIfNeeded() async {
        guard queueMode == .ahead else {
            decksNeedingPlanRefresh.removeAll()
            return
        }
        let targets = decksNeedingPlanRefresh
        decksNeedingPlanRefresh.removeAll()
        guard !targets.isEmpty else { return }
        let planner = StudyPlanService(storage: dataController.storage)
        for deckId in targets {
            let dueDate = await resolveDueDate(for: deckId)
            _ = await planner.rebuildDeckPlan(forDeckId: deckId, dueDate: dueDate)
        }
    }

    private func resolveDueDate(for deckId: UUID) async -> Date? {
        if let deck = deckLookup[deckId] {
            return deck.dueDate
        }
        if let fetched = await deckService.deck(withId: deckId) {
            deckLookup[deckId] = fetched
            return fetched.dueDate
        }
        return nil
    }

    private func ensureDeck(for card: Card) async {
        guard let deckId = card.deckId else { return }
        if deckLookup[deckId] != nil { return }
        if let deck = await deckService.deck(withId: deckId) {
            deckLookup[deckId] = deck
        }
    }

    private func refreshGradePreviews(for card: Card?) {
        guard let card else {
            gradePreviews = [:]
            return
        }
        let snapshot = SRSStateSnapshot(model: card.srs)
        let config = SchedulerConfig.from(settings: settings)
        var previews: [ReviewGrade: ScheduleResult] = [:]
        for grade in ReviewGrade.allCases {
            previews[grade] = Scheduler.review(
                state: snapshot,
                grade: grade,
                now: Date(),
                config: config,
                deckDueDate: deckDueDate(for: card),
                responseTime: snapshot.lastElapsedSeconds
            )
        }
        gradePreviews = previews
    }

    func preview(for outcome: RecallOutcome) -> ScheduleResult? {
        gradePreviews[Scheduler.grade(for: outcome)]
    }

    func preview(for grade: ReviewGrade) -> ScheduleResult? {
        gradePreviews[grade]
    }

    private func updateElapsed(now: Date) {
        if let start = activeStart {
            durationAccumulator += now.timeIntervalSince(start)
            activeStart = nil
        }
        elapsedSeconds = durationAccumulator
        stopElapsedTimer(resetActiveStart: false)
    }

    private func refreshElapsedSnapshot(now: Date = Date()) {
        if let start = activeStart {
            elapsedSeconds = durationAccumulator + now.timeIntervalSince(start)
        } else {
            elapsedSeconds = durationAccumulator
        }
    }

    private func startElapsedTimer() {
        refreshElapsedSnapshot()
        elapsedTimerCancellable?.cancel()
        guard !isFinished else { return }
        elapsedTimerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshElapsedSnapshot()
            }
    }

    private func stopElapsedTimer(resetActiveStart: Bool = false) {
        elapsedTimerCancellable?.cancel()
        elapsedTimerCancellable = nil
        if resetActiveStart {
            activeStart = nil
        }
        refreshElapsedSnapshot()
    }

    private func siblingKey(for card: Card) -> String? {
        let deckComponent = (card.deckId?.uuidString ?? "global").lowercased()
        if let cloze = card.clozeSource?.trimmingCharacters(in: .whitespacesAndNewlines), !cloze.isEmpty {
            return "\(deckComponent)|cloze|\(normalizedSiblingToken(cloze))"
        }
        let prompt = card.front.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = card.displayPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPrompt = prompt.isEmpty ? fallback : prompt
        guard !resolvedPrompt.isEmpty else { return nil }
        return "\(deckComponent)|\(card.kind.rawValue)|\(normalizedSiblingToken(resolvedPrompt))"
    }

    private func normalizedSiblingToken(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive], locale: .current)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func deckDueDate(for card: Card) -> Date? {
        guard let deckId = card.deckId else { return nil }
        if let deck = deckLookup[deckId] {
            return deck.dueDate
        }
        Task {
            if let deck = await deckService.deck(withId: deckId) {
                await MainActor.run {
                    deckLookup[deckId] = deck
                    if card.id == currentCard?.id {
                        refreshGradePreviews(for: card)
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - Adaptive Difficulty
    
    /// Applies adaptive difficulty reordering using predicted recall and concept keys
    private func applyAdaptiveDifficulty(to cards: [Card]) -> [Card] {
        guard !cards.isEmpty else { return cards }
        
        // Wrap cards with adaptive metadata
        let candidates = cards.map { card -> AdaptiveCandidate in
            let pSuccess = card.srs.predictedRecall(retentionTarget: settings.retentionTarget)
            let conceptKeys = extractConceptKeys(for: card)
            return AdaptiveCandidate(card: card, pSuccessNow: pSuccess, conceptKeys: conceptKeys)
        }
        
        // Reorder using adaptive policy
        let ordered = adaptivePolicy.orderCandidates(candidates, rollingOutcomes: rollingOutcomes)
        
        // Unwrap back to cards
        return ordered.map { $0.card }
    }
    
    /// Extracts concept keys from card tags or deck name for variety constraint
    private func extractConceptKeys(for card: Card) -> [String] {
        // Prefer tags as primary concepts
        if !card.tags.isEmpty {
            return card.tags.map { $0.lowercased() }
        }
        
        // Fall back to deck name
        if let deckId = card.deckId, let deck = deckLookup[deckId] {
            return [deck.name.lowercased()]
        }
        
        return []
    }
}

/// Wrapper to make Card conform to AdaptiveDifficultyCandidate
private struct AdaptiveCandidate: AdaptiveDifficultyCandidate {
    let card: Card
    let pSuccessNow: Double
    let conceptKeys: [String]
}
