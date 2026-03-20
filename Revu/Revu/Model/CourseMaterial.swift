@preconcurrency import Foundation

/// An uploaded file associated with a course, containing extracted text for AI processing.
struct CourseMaterial: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var courseId: UUID
    var topicId: UUID?
    var lessonId: UUID?
    var filename: String
    var fileType: String
    var extractedText: String?
    var wordCount: Int?
    var processingStatus: CourseMaterialProcessingStatus
    var processingError: String?
    var processedAt: Date?
    var importedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case courseId
        case topicId
        case lessonId
        case filename
        case fileType
        case extractedText
        case wordCount
        case processingStatus
        case processingError
        case processedAt
        case importedAt
    }

    init(
        id: UUID = UUID(),
        courseId: UUID,
        topicId: UUID? = nil,
        lessonId: UUID? = nil,
        filename: String,
        fileType: String,
        extractedText: String? = nil,
        wordCount: Int? = nil,
        processingStatus: CourseMaterialProcessingStatus = .ready,
        processingError: String? = nil,
        processedAt: Date? = nil,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.topicId = topicId
        self.lessonId = lessonId
        self.filename = filename
        self.fileType = fileType
        self.extractedText = extractedText
        self.wordCount = wordCount
        self.processingStatus = processingStatus
        self.processingError = processingError
        self.processedAt = processedAt
        self.importedAt = importedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        topicId = try container.decodeIfPresent(UUID.self, forKey: .topicId)
        lessonId = try container.decodeIfPresent(UUID.self, forKey: .lessonId)
        filename = try container.decode(String.self, forKey: .filename)
        fileType = try container.decode(String.self, forKey: .fileType)
        extractedText = try container.decodeIfPresent(String.self, forKey: .extractedText)
        wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount)
        processingStatus = try container.decodeIfPresent(CourseMaterialProcessingStatus.self, forKey: .processingStatus) ?? .ready
        processingError = try container.decodeIfPresent(String.self, forKey: .processingError)
        processedAt = try container.decodeIfPresent(Date.self, forKey: .processedAt)
        importedAt = try container.decodeIfPresent(Date.self, forKey: .importedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(courseId, forKey: .courseId)
        try container.encodeIfPresent(topicId, forKey: .topicId)
        try container.encodeIfPresent(lessonId, forKey: .lessonId)
        try container.encode(filename, forKey: .filename)
        try container.encode(fileType, forKey: .fileType)
        try container.encodeIfPresent(extractedText, forKey: .extractedText)
        try container.encodeIfPresent(wordCount, forKey: .wordCount)
        try container.encode(processingStatus, forKey: .processingStatus)
        try container.encodeIfPresent(processingError, forKey: .processingError)
        try container.encodeIfPresent(processedAt, forKey: .processedAt)
        try container.encode(importedAt, forKey: .importedAt)
    }
}
