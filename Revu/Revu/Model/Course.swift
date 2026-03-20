@preconcurrency import Foundation

/// A top-level course representing a class or subject the student is studying.
/// Courses aggregate decks, exams, study guides, topics, and materials.
struct Course: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var courseCode: String?
    var examDate: Date?
    var weeklyTimeBudgetMinutes: Int?
    var colorHex: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case courseCode
        case examDate
        case weeklyTimeBudgetMinutes
        case colorHex
        case createdAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        courseCode: String? = nil,
        examDate: Date? = nil,
        weeklyTimeBudgetMinutes: Int? = nil,
        colorHex: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.courseCode = courseCode
        self.examDate = examDate
        self.weeklyTimeBudgetMinutes = weeklyTimeBudgetMinutes
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        courseCode = try container.decodeIfPresent(String.self, forKey: .courseCode)
        examDate = try container.decodeIfPresent(Date.self, forKey: .examDate)
        weeklyTimeBudgetMinutes = try container.decodeIfPresent(Int.self, forKey: .weeklyTimeBudgetMinutes)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(courseCode, forKey: .courseCode)
        try container.encodeIfPresent(examDate, forKey: .examDate)
        try container.encodeIfPresent(weeklyTimeBudgetMinutes, forKey: .weeklyTimeBudgetMinutes)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
