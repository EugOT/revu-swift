@preconcurrency import Foundation

/// A timed exam containing multiple-choice questions.
/// Exams live inside folders and are first-class library items alongside decks.
struct Exam: Identifiable, Codable, Equatable, Hashable, Sendable {
    /// Configuration options for exam behavior
    struct Config: Codable, Equatable, Hashable, Sendable {
        /// Optional time limit in seconds
        var timeLimit: Int?
        /// Whether to shuffle question order when taking the exam
        var shuffleQuestions: Bool

        enum CodingKeys: String, CodingKey {
            case timeLimit
            case shuffleQuestions
        }

        init(timeLimit: Int? = nil, shuffleQuestions: Bool = true) {
            self.timeLimit = timeLimit
            self.shuffleQuestions = shuffleQuestions
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            timeLimit = try container.decodeIfPresent(Int.self, forKey: .timeLimit)
            shuffleQuestions = try container.decodeIfPresent(Bool.self, forKey: .shuffleQuestions) ?? true
        }
    }

    /// A multiple-choice question in the exam
    struct Question: Identifiable, Codable, Equatable, Hashable, Sendable {
        var id: UUID
        var prompt: String
        var choices: [String]
        var correctChoiceIndex: Int

        enum CodingKeys: String, CodingKey {
            case id
            case prompt
            case choices
            case correctChoiceIndex
        }

        init(
            id: UUID = UUID(),
            prompt: String,
            choices: [String],
            correctChoiceIndex: Int
        ) {
            self.id = id
            self.prompt = prompt
            self.choices = choices
            self.correctChoiceIndex = correctChoiceIndex
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            prompt = try container.decode(String.self, forKey: .prompt)
            choices = try container.decodeIfPresent([String].self, forKey: .choices) ?? []
            correctChoiceIndex = try container.decodeIfPresent(Int.self, forKey: .correctChoiceIndex) ?? 0
        }
    }

    var id: UUID
    var parentFolderId: UUID?
    var courseId: UUID?
    var originLessonId: UUID?
    var title: String
    var config: Config
    var questions: [Question]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case parentFolderId
        case courseId
        case originLessonId
        case title
        case config
        case questions
        case createdAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        parentFolderId: UUID? = nil,
        courseId: UUID? = nil,
        originLessonId: UUID? = nil,
        title: String,
        config: Config = Config(),
        questions: [Question] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.parentFolderId = parentFolderId
        self.courseId = courseId
        self.originLessonId = originLessonId
        self.title = title
        self.config = config
        self.questions = questions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentFolderId = try container.decodeIfPresent(UUID.self, forKey: .parentFolderId)
        courseId = try container.decodeIfPresent(UUID.self, forKey: .courseId)
        originLessonId = try container.decodeIfPresent(UUID.self, forKey: .originLessonId)
        title = try container.decode(String.self, forKey: .title)
        config = try container.decodeIfPresent(Config.self, forKey: .config) ?? Config()
        questions = try container.decodeIfPresent([Question].self, forKey: .questions) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(parentFolderId, forKey: .parentFolderId)
        try container.encodeIfPresent(courseId, forKey: .courseId)
        try container.encodeIfPresent(originLessonId, forKey: .originLessonId)
        try container.encode(title, forKey: .title)
        try container.encode(config, forKey: .config)
        if !questions.isEmpty {
            try container.encode(questions, forKey: .questions)
        }
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
