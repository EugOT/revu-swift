@preconcurrency import Foundation

struct Deck: Identifiable, Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case deck
        case folder
    }

    var id: UUID
    var parentId: UUID?
    var courseId: UUID?
    var originLessonId: UUID?
    var kind: Kind
    var name: String
    var note: String?
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    var isFolder: Bool { kind == .folder }

    enum CodingKeys: String, CodingKey {
        case id
        case parentId
        case courseId
        case originLessonId
        case kind
        case name
        case note
        case dueDate
        case createdAt
        case updatedAt
        case isArchived
    }

    init(
        id: UUID = UUID(),
        parentId: UUID? = nil,
        courseId: UUID? = nil,
        originLessonId: UUID? = nil,
        kind: Kind = .deck,
        name: String,
        note: String? = nil,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.parentId = parentId
        self.courseId = courseId
        self.originLessonId = originLessonId
        self.kind = kind
        self.name = name
        self.note = note
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        courseId = try container.decodeIfPresent(UUID.self, forKey: .courseId)
        originLessonId = try container.decodeIfPresent(UUID.self, forKey: .originLessonId)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .deck
        name = try container.decode(String.self, forKey: .name)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encodeIfPresent(courseId, forKey: .courseId)
        try container.encodeIfPresent(originLessonId, forKey: .originLessonId)
        try container.encode(kind, forKey: .kind)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        if isArchived {
            try container.encode(isArchived, forKey: .isArchived)
        }
    }
}
