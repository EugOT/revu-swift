import Foundation
import Combine

struct JSONFlashcardDocument: Codable {
    let schema: String
    let version: Int
    let exportedAt: Date
    let decks: [JSONDeck]

    static let expectedSchema = "revu.flashcards"
    static let supportedVersions: ClosedRange<Int> = 1...4
}

struct JSONDeck: Codable {
    let id: UUID
    let parentId: UUID?
    let name: String
    let note: String?
    let dueDate: Date?
    let cards: [JSONCard]
    let dueDateProvided: Bool
    let isArchived: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case parentId
        case name
        case note
        case dueDate
        case cards
        case isArchived
    }

    init(id: UUID, parentId: UUID?, name: String, note: String?, dueDate: Date?, cards: [JSONCard], isArchived: Bool) {
        self.id = id
        self.parentId = parentId
        self.name = name
        self.note = note
        self.dueDate = dueDate
        self.cards = cards
        self.dueDateProvided = dueDate != nil
        self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        name = try container.decode(String.self, forKey: .name)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        dueDateProvided = container.contains(.dueDate)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        cards = try container.decode([JSONCard].self, forKey: .cards)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(note, forKey: .note)
        if dueDateProvided, let dueDate {
            try container.encode(dueDate, forKey: .dueDate)
        }
        try container.encode(cards, forKey: .cards)
        if isArchived {
            try container.encode(isArchived, forKey: .isArchived)
        }
    }
}

struct JSONCard: Codable {
    enum Kind: String, Codable {
        case basic
        case cloze
        case multipleChoice
    }

    let id: UUID
    let kind: Kind
    let front: String?
    let back: String?
    let clozeSource: String?
    let choices: [String]?
    let correctChoiceIndex: Int?
    let tags: [String]?
    let media: [URL]?
    let createdAt: Date
    let updatedAt: Date
}
