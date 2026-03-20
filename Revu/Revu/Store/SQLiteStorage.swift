@preconcurrency import Foundation

final class SQLiteStorage: LocalStore, SyncRepository {
    private let store: SQLiteStore
    private let events: StoreEvents
    private let notificationBatcher = SQLiteNotificationBatcher()

    private let attachmentsDirectoryURL: URL

    @MainActor
    init(rootURL: URL? = nil, events: StoreEvents) throws {
        self.events = events
        self.store = try SQLiteStore(rootURL: rootURL)
        self.attachmentsDirectoryURL = rootURL?.appendingPathComponent("attachments", isDirectory: true)
            ?? FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("revu", isDirectory: true)
                .appendingPathComponent("v1", isDirectory: true)
                .appendingPathComponent("attachments", isDirectory: true)
    }

    @MainActor
    convenience init(rootURL: URL? = nil) throws {
        try self.init(rootURL: rootURL, events: StoreEvents())
    }

    // MARK: - DeckRepository

    func allDecks() async throws -> [DeckDTO] {
        try await store.allDecks()
    }

    func deck(withId id: UUID) async throws -> DeckDTO? {
        try await store.deck(id: id)
    }

    func upsert(deck: DeckDTO) async throws {
        try await store.upsert(deck: deck)
        await notify(.decksChanged)
    }

    func deleteDeck(id: UUID) async throws {
        try await store.deleteDeck(id: id)
        await notify(.decksChanged)
        await notify(.cardsChanged)
    }

    // MARK: - CardRepository

    func allCards() async throws -> [CardDTO] {
        try await store.allCards()
    }

    func cards(deckId: UUID) async throws -> [CardDTO] {
        try await store.cards(deckId: deckId)
    }

    func card(withId id: UUID) async throws -> CardDTO? {
        try await store.card(id: id)
    }

    func searchCards(text: String, tags: Set<String>, deckId: UUID?) async throws -> [CardDTO] {
        try await store.searchCards(text: text, tags: tags, deckId: deckId)
    }

    func upsert(card: CardDTO) async throws {
        try await store.upsert(card: card)
        await notify(.cardsChanged)
    }

    func deleteCard(id: UUID) async throws {
        try await store.deleteCard(id: id)
        await notify(.cardsChanged)
    }

    // MARK: - SRSRepository

    func dueCards(on date: Date, limit: Int?) async throws -> [CardDTO] {
        try await store.dueCards(on: date, limit: limit)
    }

    func newCards(limit: Int) async throws -> [CardDTO] {
        try await store.newCards(limit: limit)
    }

    func save(card: CardDTO) async throws {
        try await store.upsert(card: card)
        await notify(.cardsChanged)
    }

    // MARK: - ReviewLogRepository

    func recentLogs(limit: Int) async throws -> [ReviewLogDTO] {
        try await store.recentLogs(limit: limit)
    }

    func append(log: ReviewLogDTO) async throws {
        try await store.append(log: log)
        await notify(.reviewLogsChanged)
    }

    // MARK: - StudyEventRepository

    func recentEvents(limit: Int) async throws -> [StudyEventDTO] {
        try await store.recentEvents(limit: limit)
    }

    func append(event: StudyEventDTO) async throws {
        try await store.append(event: event)
    }

    // MARK: - SettingsRepository

    func loadSettings() async throws -> UserSettingsDTO {
        if let cached = try await store.loadSettings() {
            return cached
        }

        let defaults = UserSettingsDTO(
            id: UUID(),
            dailyNewLimit: AppSettingsDefaults.dailyNewLimit,
            dailyReviewLimit: AppSettingsDefaults.dailyReviewLimit,
            learningStepsMinutes: AppSettingsDefaults.learningStepsMinutes,
            lapseStepsMinutes: AppSettingsDefaults.lapseStepsMinutes,
            easeMin: AppSettingsDefaults.easeMin,
            burySiblings: AppSettingsDefaults.burySiblings,
            keyboardHints: AppSettingsDefaults.keyboardHints,
            autoAdvance: AppSettingsDefaults.autoAdvance,
            retentionTarget: AppSettingsDefaults.retentionTarget,
            enableResponseTimeTuning: AppSettingsDefaults.enableResponseTimeTuning,
            proactiveInterventionsEnabled: AppSettingsDefaults.proactiveInterventionsEnabled,
            interventionSensitivity: AppSettingsDefaults.interventionSensitivity.rawValue,
            interventionCooldownMinutes: AppSettingsDefaults.interventionCooldownMinutes,
            challengeModeDefaultEnabled: AppSettingsDefaults.challengeModeDefaultEnabled,
            celebrationIntensity: AppSettingsDefaults.celebrationIntensity.rawValue,
            dailyGoalTarget: AppSettingsDefaults.dailyGoalTarget,
            useCloudSync: AppSettingsDefaults.useCloudSync,
            notificationsEnabled: AppSettingsDefaults.notificationsEnabled,
            notificationHour: AppSettingsDefaults.notificationHour,
            notificationMinute: AppSettingsDefaults.notificationMinute,
            dataLocationBookmark: nil,
            appearanceMode: nil,
            deckSortOrder: [],
            deckSortMode: AppSettingsDefaults.deckSortMode.rawValue,
            hasCompletedOnboarding: AppSettingsDefaults.hasCompletedOnboarding,
            userName: AppSettingsDefaults.userName,
            studyGoal: AppSettingsDefaults.studyGoal
        )

        try await store.save(settings: defaults)
        await notify(.settingsChanged)
        return defaults
    }

    func save(settings: UserSettingsDTO) async throws {
        try await store.save(settings: settings)
        await notify(.settingsChanged)
    }

    func flush() async throws {
        // SQLite commits each statement transactionally. Nothing to flush.
    }

    // MARK: - ExamRepository

    func allExams() async throws -> [ExamDTO] {
        try await store.allExams()
    }

    func exams(parentFolderId: UUID) async throws -> [ExamDTO] {
        try await store.exams(parentFolderId: parentFolderId)
    }

    func exam(withId id: UUID) async throws -> ExamDTO? {
        try await store.exam(id: id)
    }

    func upsert(exam: ExamDTO) async throws {
        try await store.upsert(exam: exam)
        await notify(.examsChanged)
    }

    func deleteExam(id: UUID) async throws {
        try await store.deleteExam(id: id)
        await notify(.examsChanged)
    }

    // MARK: - StudyGuideRepository

    func allStudyGuides() async throws -> [StudyGuideDTO] {
        try await store.allStudyGuides()
    }

    func studyGuides(parentFolderId: UUID) async throws -> [StudyGuideDTO] {
        try await store.studyGuides(parentFolderId: parentFolderId)
    }

    func searchStudyGuides(query: String, parentFolderId: UUID?) async throws -> [StudyGuideDTO] {
        try await store.searchStudyGuides(query: query, parentFolderId: parentFolderId)
    }

    func studyGuide(withId id: UUID) async throws -> StudyGuideDTO? {
        try await store.studyGuide(id: id)
    }

    func upsert(studyGuide: StudyGuideDTO) async throws {
        try await store.upsert(studyGuide: studyGuide)
        await notify(.studyGuidesChanged)
    }

    func deleteStudyGuide(id: UUID) async throws {
        try await store.deleteStudyGuide(id: id)
        await notify(.studyGuidesChanged)
    }

    // MARK: - ConceptStateRepository

    func allConceptStates() async throws -> [ConceptState] {
        try await store.allConceptStates()
    }

    func conceptState(forKey key: String) async throws -> ConceptState? {
        try await store.conceptState(forKey: key)
    }

    func upsert(conceptState: ConceptState) async throws {
        try await store.upsert(conceptState: conceptState)
    }

    // MARK: - CourseRepository

    func allCourses() async throws -> [CourseDTO] {
        try await store.allCourses()
    }

    func course(withId id: UUID) async throws -> CourseDTO? {
        try await store.course(id: id)
    }

    func upsert(course: CourseDTO) async throws {
        try await store.upsert(course: course)
        await notify(.coursesChanged)
    }

    func deleteCourse(id: UUID) async throws {
        try await store.deleteCourse(id: id)
        await notify(.coursesChanged)
    }

    // MARK: - CourseTopicRepository

    func allTopics() async throws -> [CourseTopicDTO] {
        try await store.allTopics()
    }

    func topics(courseId: UUID) async throws -> [CourseTopicDTO] {
        try await store.topics(courseId: courseId)
    }

    func topic(withId id: UUID) async throws -> CourseTopicDTO? {
        try await store.topic(id: id)
    }

    func upsert(topic: CourseTopicDTO) async throws {
        try await store.upsert(topic: topic)
        await notify(.coursesChanged)
    }

    func deleteTopic(id: UUID) async throws {
        try await store.deleteTopic(id: id)
        await notify(.coursesChanged)
    }

    // MARK: - LessonRepository

    func allLessons() async throws -> [LessonDTO] {
        try await store.allLessons()
    }

    func lessons(courseId: UUID) async throws -> [LessonDTO] {
        try await store.lessons(courseId: courseId)
    }

    func lesson(withId id: UUID) async throws -> LessonDTO? {
        try await store.lesson(id: id)
    }

    func upsert(lesson: LessonDTO) async throws {
        try await store.upsert(lesson: lesson)
        await notify(.coursesChanged)
    }

    func deleteLesson(id: UUID) async throws {
        try await store.deleteLesson(id: id)
        await notify(.coursesChanged)
    }

    // MARK: - CourseMaterialRepository

    func allMaterials() async throws -> [CourseMaterialDTO] {
        try await store.allMaterials()
    }

    func materials(courseId: UUID) async throws -> [CourseMaterialDTO] {
        try await store.materials(courseId: courseId)
    }

    func material(withId id: UUID) async throws -> CourseMaterialDTO? {
        try await store.material(id: id)
    }

    func upsert(material: CourseMaterialDTO) async throws {
        try await store.upsert(material: material)
        await notify(.coursesChanged)
    }

    func deleteMaterial(id: UUID) async throws {
        try await store.deleteMaterial(id: id)
        await notify(.coursesChanged)
    }

    // MARK: - ContentChunkRepository

    func allChunks(courseId: UUID) async throws -> [ContentChunk] {
        try await store.allChunks(courseId: courseId)
    }

    func searchChunks(courseId: UUID, keywords: [String], limit: Int) async throws -> [ContentChunk] {
        try await store.searchChunks(courseId: courseId, keywords: keywords, limit: limit)
    }

    func upsert(chunk: ContentChunk) async throws {
        try await store.upsert(chunk: chunk)
    }

    func deleteChunks(courseId: UUID) async throws {
        try await store.deleteChunks(courseId: courseId)
    }

    // MARK: - LessonGenerationJobRepository

    func lessonGenerationJobs(lessonId: UUID) async throws -> [LessonGenerationJobDTO] {
        try await store.lessonGenerationJobs(lessonId: lessonId)
    }

    func upsert(lessonGenerationJob: LessonGenerationJobDTO) async throws {
        try await store.upsert(lessonGenerationJob: lessonGenerationJob)
        await notify(.coursesChanged)
    }

    func deleteLessonGenerationJobs(lessonId: UUID) async throws {
        try await store.deleteLessonGenerationJobs(lessonId: lessonId)
        await notify(.coursesChanged)
    }

    // MARK: - LocalStore

    func storeEvents() -> StoreEvents {
        events
    }

    func tagsSnapshot() async -> [String] {
        (try? await store.tagsSnapshot()) ?? []
    }

    var attachmentsDirectory: URL { attachmentsDirectoryURL }

    func wipeAllLocalData() async throws {
        try await store.wipeAllData()
        await MainActor.run { events.notify() }
    }

    func withBatchUpdates<T>(_ operation: () async throws -> T) async throws -> T {
        await notificationBatcher.begin()
        try await store.beginBatch()

        do {
            let result = try await operation()
            try await store.endBatch()
            let shouldNotify = await notificationBatcher.end()
            if shouldNotify {
                await MainActor.run { events.notify() }
            }
            return result
        } catch {
            await store.rollbackBatch()
            let shouldNotify = await notificationBatcher.end()
            if shouldNotify {
                await MainActor.run { events.notify() }
            }
            throw error
        }
    }

    // MARK: - SyncRepository

    func enqueueMutation(_ mutation: SyncMutation) async throws {
        try await store.enqueueMutation(mutation)
    }

    func pendingMutations(limit: Int) async throws -> [SyncMutation] {
        try await store.pendingMutations(limit: limit)
    }

    func markMutationSynced(clientMutationID: String) async throws {
        try await store.markMutationSynced(clientMutationID: clientMutationID)
    }

    func applyRemoteChanges(_ batch: RemoteChangeBatch) async throws {
        // Domain-specific application is handled by SyncService orchestration.
        // Store currently persists cursor and outbox durability primitives.
        try await store.setSyncCursor(batch.cursor)
    }

    func syncCursor() async throws -> Int64 {
        try await store.syncCursor()
    }

    func setSyncCursor(_ cursor: Int64) async throws {
        try await store.setSyncCursor(cursor)
    }

    // MARK: - Notifications

    private func notify(_ event: StoreEvent) async {
        if await notificationBatcher.record(event) {
            return
        }
        await MainActor.run { events.notify() }
    }
}

private actor SQLiteNotificationBatcher {
    private var depth: Int = 0
    private var pendingNotify: Bool = false

    func begin() {
        depth += 1
    }

    func end() -> Bool {
        guard depth > 0 else { return pendingNotify }
        depth -= 1
        guard depth == 0 else { return false }
        let pending = pendingNotify
        pendingNotify = false
        return pending
    }

    func record(_ event: StoreEvent) -> Bool {
        guard depth > 0 else { return false }
        pendingNotify = true
        return true
    }
}
