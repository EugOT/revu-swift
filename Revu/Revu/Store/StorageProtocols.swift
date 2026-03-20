import Foundation

protocol DeckRepository {
    func allDecks() async throws -> [DeckDTO]
    func deck(withId id: UUID) async throws -> DeckDTO?
    func upsert(deck: DeckDTO) async throws
    func deleteDeck(id: UUID) async throws
}

protocol CardRepository {
    func allCards() async throws -> [CardDTO]
    func cards(deckId: UUID) async throws -> [CardDTO]
    func card(withId id: UUID) async throws -> CardDTO?
    func searchCards(text: String, tags: Set<String>, deckId: UUID?) async throws -> [CardDTO]
    func upsert(card: CardDTO) async throws
    func deleteCard(id: UUID) async throws
}

protocol SRSRepository {
    func dueCards(on date: Date, limit: Int?) async throws -> [CardDTO]
    func newCards(limit: Int) async throws -> [CardDTO]
    func save(card: CardDTO) async throws
}

protocol ReviewLogRepository {
    func recentLogs(limit: Int) async throws -> [ReviewLogDTO]
    func append(log: ReviewLogDTO) async throws
}

protocol StudyEventRepository {
    func recentEvents(limit: Int) async throws -> [StudyEventDTO]
    func append(event: StudyEventDTO) async throws
}

protocol SettingsRepository {
    func loadSettings() async throws -> UserSettingsDTO
    func save(settings: UserSettingsDTO) async throws
}

protocol ExamRepository {
    func allExams() async throws -> [ExamDTO]
    func exams(parentFolderId: UUID) async throws -> [ExamDTO]
    func exam(withId id: UUID) async throws -> ExamDTO?
    func upsert(exam: ExamDTO) async throws
    func deleteExam(id: UUID) async throws
}

protocol StudyGuideRepository {
    func allStudyGuides() async throws -> [StudyGuideDTO]
    func studyGuides(parentFolderId: UUID) async throws -> [StudyGuideDTO]
    func searchStudyGuides(query: String, parentFolderId: UUID?) async throws -> [StudyGuideDTO]
    func studyGuide(withId id: UUID) async throws -> StudyGuideDTO?
    func upsert(studyGuide: StudyGuideDTO) async throws
    func deleteStudyGuide(id: UUID) async throws
}

protocol ConceptStateRepository {
    func allConceptStates() async throws -> [ConceptState]
    func conceptState(forKey key: String) async throws -> ConceptState?
    func upsert(conceptState: ConceptState) async throws
}

protocol CourseRepository {
    func allCourses() async throws -> [CourseDTO]
    func course(withId id: UUID) async throws -> CourseDTO?
    func upsert(course: CourseDTO) async throws
    func deleteCourse(id: UUID) async throws
}

protocol CourseTopicRepository {
    func allTopics() async throws -> [CourseTopicDTO]
    func topics(courseId: UUID) async throws -> [CourseTopicDTO]
    func topic(withId id: UUID) async throws -> CourseTopicDTO?
    func upsert(topic: CourseTopicDTO) async throws
    func deleteTopic(id: UUID) async throws
}

protocol LessonRepository {
    func allLessons() async throws -> [LessonDTO]
    func lessons(courseId: UUID) async throws -> [LessonDTO]
    func lesson(withId id: UUID) async throws -> LessonDTO?
    func upsert(lesson: LessonDTO) async throws
    func deleteLesson(id: UUID) async throws
}

protocol CourseMaterialRepository {
    func allMaterials() async throws -> [CourseMaterialDTO]
    func materials(courseId: UUID) async throws -> [CourseMaterialDTO]
    func material(withId id: UUID) async throws -> CourseMaterialDTO?
    func upsert(material: CourseMaterialDTO) async throws
    func deleteMaterial(id: UUID) async throws
}

protocol LessonGenerationJobRepository {
    func lessonGenerationJobs(lessonId: UUID) async throws -> [LessonGenerationJobDTO]
    func upsert(lessonGenerationJob: LessonGenerationJobDTO) async throws
    func deleteLessonGenerationJobs(lessonId: UUID) async throws
}

protocol ContentChunkRepository {
    func allChunks(courseId: UUID) async throws -> [ContentChunk]
    func searchChunks(courseId: UUID, keywords: [String], limit: Int) async throws -> [ContentChunk]
    func upsert(chunk: ContentChunk) async throws
    func deleteChunks(courseId: UUID) async throws
}

protocol Storage: DeckRepository, CardRepository, SRSRepository, ReviewLogRepository, StudyEventRepository, SettingsRepository, ExamRepository, StudyGuideRepository, ConceptStateRepository, CourseRepository, CourseTopicRepository, LessonRepository, CourseMaterialRepository, ContentChunkRepository, LessonGenerationJobRepository {}

enum SyncMutationOperation: String, Codable, Sendable {
    case upsert
    case delete
}

struct SyncMutation: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var clientMutationID: String
    var entity: String
    var entityID: String
    var operation: SyncMutationOperation
    var payload: Data?
    var baseServerVersion: Int64?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        clientMutationID: String,
        entity: String,
        entityID: String,
        operation: SyncMutationOperation,
        payload: Data?,
        baseServerVersion: Int64? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.clientMutationID = clientMutationID
        self.entity = entity
        self.entityID = entityID
        self.operation = operation
        self.payload = payload
        self.baseServerVersion = baseServerVersion
        self.createdAt = createdAt
    }
}

struct RemoteChangeBatch: Codable, Equatable, Hashable, Sendable {
    var cursor: Int64
    var changes: [SyncMutation]

    init(cursor: Int64, changes: [SyncMutation]) {
        self.cursor = cursor
        self.changes = changes
    }
}

protocol SyncRepository {
    func enqueueMutation(_ mutation: SyncMutation) async throws
    func pendingMutations(limit: Int) async throws -> [SyncMutation]
    func markMutationSynced(clientMutationID: String) async throws
    func applyRemoteChanges(_ batch: RemoteChangeBatch) async throws
    func syncCursor() async throws -> Int64
    func setSyncCursor(_ cursor: Int64) async throws
}

protocol LocalStore: Storage, AttachmentDirectoryProviding {
    func storeEvents() -> StoreEvents
    func tagsSnapshot() async -> [String]
    func wipeAllLocalData() async throws
    func withBatchUpdates<T>(_ operation: () async throws -> T) async throws -> T
    func flush() async throws
}

enum StorageError: Error {
    case initializationFailed(String)
    case encodingFailed(String)
    case decodingFailed(String)
    case entityNotFound(String)
    case migrationRequired
}
