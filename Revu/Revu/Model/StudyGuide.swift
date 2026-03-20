@preconcurrency import Foundation

struct StudyGuideAttachment: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var filename: String
    var relativePath: String
    var mimeType: String
    var sizeBytes: Int64
    var createdAt: Date

    init(
        id: UUID = UUID(),
        filename: String,
        relativePath: String,
        mimeType: String,
        sizeBytes: Int64,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.filename = filename
        self.relativePath = relativePath
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
    }
}

/// A markdown-based study guide document.
/// Study guides live inside folders and are first-class library items alongside decks.
struct StudyGuide: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var parentFolderId: UUID?
    var courseId: UUID?
    var originLessonId: UUID?
    var title: String
    var markdownContent: String
    var attachments: [StudyGuideAttachment]
    var tags: [String]
    var createdAt: Date
    var lastEditedAt: Date
    var updatedAt: Date {
        get { lastEditedAt }
        set { lastEditedAt = newValue }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case parentFolderId
        case courseId
        case originLessonId
        case title
        case markdownContent
        case attachments
        case tags
        case createdAt
        case lastEditedAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        parentFolderId: UUID? = nil,
        courseId: UUID? = nil,
        originLessonId: UUID? = nil,
        title: String,
        markdownContent: String = "",
        attachments: [StudyGuideAttachment] = [],
        tags: [String] = [],
        createdAt: Date = Date(),
        lastEditedAt: Date
    ) {
        self.id = id
        self.parentFolderId = parentFolderId
        self.courseId = courseId
        self.originLessonId = originLessonId
        self.title = title
        self.markdownContent = markdownContent
        self.attachments = attachments
        self.tags = tags
        self.createdAt = createdAt
        self.lastEditedAt = lastEditedAt
    }

    init(
        id: UUID = UUID(),
        parentFolderId: UUID? = nil,
        courseId: UUID? = nil,
        originLessonId: UUID? = nil,
        title: String,
        markdownContent: String = "",
        attachments: [StudyGuideAttachment] = [],
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(
            id: id,
            parentFolderId: parentFolderId,
            courseId: courseId,
            originLessonId: originLessonId,
            title: title,
            markdownContent: markdownContent,
            attachments: attachments,
            tags: tags,
            createdAt: createdAt,
            lastEditedAt: updatedAt
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentFolderId = try container.decodeIfPresent(UUID.self, forKey: .parentFolderId)
        courseId = try container.decodeIfPresent(UUID.self, forKey: .courseId)
        originLessonId = try container.decodeIfPresent(UUID.self, forKey: .originLessonId)
        title = try container.decode(String.self, forKey: .title)
        markdownContent = try container.decodeIfPresent(String.self, forKey: .markdownContent) ?? ""
        attachments = try container.decodeIfPresent([StudyGuideAttachment].self, forKey: .attachments) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        let decodedLastEditedAt = try container.decodeIfPresent(Date.self, forKey: .lastEditedAt)
        let decodedUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        lastEditedAt = decodedLastEditedAt ?? decodedUpdatedAt ?? createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(parentFolderId, forKey: .parentFolderId)
        try container.encodeIfPresent(courseId, forKey: .courseId)
        try container.encodeIfPresent(originLessonId, forKey: .originLessonId)
        try container.encode(title, forKey: .title)
        if !markdownContent.isEmpty {
            try container.encode(markdownContent, forKey: .markdownContent)
        }
        if !attachments.isEmpty {
            try container.encode(attachments, forKey: .attachments)
        }
        if !tags.isEmpty {
            try container.encode(tags, forKey: .tags)
        }
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastEditedAt, forKey: .lastEditedAt)
        try container.encode(lastEditedAt, forKey: .updatedAt)
    }
}
