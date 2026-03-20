@preconcurrency import Foundation

/// A topic within a course, representing a distinct subject area or chapter.
/// Topics track coverage and link to generated study materials.
struct CourseTopic: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var courseId: UUID
    var name: String
    var sortOrder: Int
    var sourceDescription: String?

    enum CodingKeys: String, CodingKey {
        case id
        case courseId
        case name
        case sortOrder
        case sourceDescription
    }

    init(
        id: UUID = UUID(),
        courseId: UUID,
        name: String,
        sortOrder: Int = 0,
        sourceDescription: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.name = name
        self.sortOrder = sortOrder
        self.sourceDescription = sourceDescription
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        name = try container.decode(String.self, forKey: .name)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        sourceDescription = try container.decodeIfPresent(String.self, forKey: .sourceDescription)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(courseId, forKey: .courseId)
        try container.encode(name, forKey: .name)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encodeIfPresent(sourceDescription, forKey: .sourceDescription)
    }
}
