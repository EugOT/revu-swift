@preconcurrency import Foundation

enum LessonSourceType: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case upload
    case groupedUpload
    case legacy
    case manual
}

enum LessonStatus: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case ready
    case processing
    case failed
    case archived
}

enum CourseMaterialProcessingStatus: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case uploaded
    case ingesting
    case chunked
    case ready
    case failed
}

enum LessonArtifactKind: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case notes
    case quiz
    case flashcards
}

enum ArtifactStatus: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case notStarted
    case inProgress
    case ready
    case failed
}

struct Lesson: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var courseId: UUID
    var title: String
    var summary: String?
    var createdAt: Date
    var updatedAt: Date
    var sourceType: LessonSourceType
    var status: LessonStatus

    enum CodingKeys: String, CodingKey {
        case id
        case courseId
        case title
        case summary
        case createdAt
        case updatedAt
        case sourceType
        case status
    }

    init(
        id: UUID = UUID(),
        courseId: UUID,
        title: String,
        summary: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceType: LessonSourceType = .upload,
        status: LessonStatus = .ready
    ) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceType = sourceType
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        sourceType = try container.decodeIfPresent(LessonSourceType.self, forKey: .sourceType) ?? .upload
        status = try container.decodeIfPresent(LessonStatus.self, forKey: .status) ?? .ready
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(courseId, forKey: .courseId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encode(status, forKey: .status)
    }
}

struct LessonArtifactSummary: Equatable, Hashable, Sendable {
    let kind: LessonArtifactKind
    let status: ArtifactStatus
    let count: Int
    let error: String?
    let updatedAt: Date?
}

struct LessonDashboardSummary: Identifiable, Equatable, Hashable, Sendable {
    let lesson: Lesson
    let materialCount: Int
    let wordCount: Int
    let artifactSummaries: [LessonArtifactSummary]
    let notesIds: [UUID]
    let quizIds: [UUID]
    let flashcardDeckIds: [UUID]
    let readiness: Double
    let dueCards: Int

    var id: UUID { lesson.id }
}

struct MixedQuizSummary: Equatable, Hashable, Sendable {
    let examId: UUID?
    let status: ArtifactStatus
    let questionCount: Int
    let updatedAt: Date?
}

struct WeakLessonInsight: Identifiable, Equatable, Hashable, Sendable {
    let lessonId: UUID
    let lessonTitle: String
    let confidence: Double
    let missRate: Double
    let dueCards: Int
    let recommendation: String

    var id: UUID { lessonId }
}

enum CourseTimelineActionType: String, Equatable, Hashable, Sendable {
    case generateLessonArtifact
    case openLessonQuiz
    case openLessonNotes
    case openLessonFlashcards
    case generateMixedQuiz
    case openMixedQuiz
    case reviewWeakLesson
}

struct CourseTimelineCTA: Equatable, Hashable, Sendable {
    let title: String
    let actionType: CourseTimelineActionType
    let lessonId: UUID?
    let artifactKind: LessonArtifactKind?
    let examId: UUID?
    let deckId: UUID?
    let studyGuideId: UUID?
}

struct CourseTimelineItem: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let urgency: Int
    let dueAt: Date?
    let cta: CourseTimelineCTA

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        urgency: Int,
        dueAt: Date? = nil,
        cta: CourseTimelineCTA
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.urgency = urgency
        self.dueAt = dueAt
        self.cta = cta
    }
}

enum CourseDashboardPace: String, Equatable, Hashable, Sendable {
    case onTrack
    case atRisk
    case critical
    case noExam
}

struct CourseDashboardKPI: Equatable, Hashable, Sendable {
    let readiness: Double
    let dueItems: Int
    let pace: CourseDashboardPace
    let weakLessonCount: Int
    let lessonCount: Int
}

struct CourseDashboardSnapshot: Equatable, Hashable, Sendable {
    let courseId: UUID
    let lessonSummaries: [LessonDashboardSummary]
    let mixedQuiz: MixedQuizSummary
    let weakLessons: [WeakLessonInsight]
    let timelineItems: [CourseTimelineItem]
    let topKpis: CourseDashboardKPI
}
