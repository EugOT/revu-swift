import Foundation
import UniformTypeIdentifiers

struct ImportErrorDetail: Identifiable, Error, Equatable {
    let id = UUID()
    let line: Int?
    let path: String
    let message: String
}

struct ImportPreview: Identifiable {
    struct DeckSummary: Identifiable {
        let id: UUID
        let name: String
        let cardCount: Int
        let token: ImportDeckToken
    }

    let id = UUID()
    let formatIdentifier: String
    let formatName: String
    let deckCount: Int
    let cardCount: Int
    let decks: [DeckSummary]
    let errors: [ImportErrorDetail]
}

struct ImportResult {
    let decksInserted: Int
    let decksUpdated: Int
    let cardsInserted: Int
    let cardsUpdated: Int
    let cardsSkipped: Int
    let errors: [ImportErrorDetail]
}

struct ImportPreviewDetails {
    let deckCount: Int
    let cardCount: Int
    let decks: [ImportPreview.DeckSummary]
    let errors: [ImportErrorDetail]
}

struct ImportedDocument {
    let decks: [ImportedDeck]
}

struct ImportedDeck {
    let id: UUID
    let parentId: UUID?
    let name: String
    let note: String?
    let dueDate: Date?
    let dueDateProvided: Bool
    let isArchived: Bool
    let cards: [ImportedCard]
    let token: ImportDeckToken
}

struct ImportedCard {
    let id: UUID
    let kind: Card.Kind
    let front: String?
    let back: String?
    let clozeSource: String?
    let choices: [String]
    let correctChoiceIndex: Int?
    let tags: [String]
    let media: [URL]
    let createdAt: Date
    let updatedAt: Date
    let isSuspended: Bool?
    let srs: SRSState?
}

struct ImportSource {
    let data: Data
    let filename: String?
    let contentType: UTType?
}

struct ImportDeckToken: Codable {
    let sourceIndex: Int
    let originalID: UUID?
}

extension ImportDeckToken: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(sourceIndex)
        hasher.combine(originalID)
    }
    
    static func == (lhs: ImportDeckToken, rhs: ImportDeckToken) -> Bool {
        lhs.sourceIndex == rhs.sourceIndex && lhs.originalID == rhs.originalID
    }
}

struct DeckMergeTarget: Identifiable, Hashable, Equatable {
    let id: UUID
    let parentId: UUID?
    let name: String
    let note: String?
    let dueDate: Date?
    let isArchived: Bool
}

struct DeckMergePlan: Equatable {
    struct Assignment: Equatable {
        enum Destination: Equatable {
            case createNew
            case existing(DeckMergeTarget)
        }

        var destination: Destination

        static let createNew = Assignment(destination: .createNew)
    }

    private var assignments: [ImportDeckToken: Assignment] = [:]

    init(assignments: [ImportDeckToken: Assignment] = [:]) {
        self.assignments = assignments
    }

    static let empty = DeckMergePlan()

    func assignment(for token: ImportDeckToken) -> Assignment {
        assignments[token] ?? .createNew
    }

    mutating func setAssignment(_ assignment: Assignment, for token: ImportDeckToken) {
        assignments[token] = assignment
    }

    func applying(to deck: ImportedDeck) -> ImportedDeck {
        let assignment = assignment(for: deck.token)
        switch assignment.destination {
        case .createNew:
            return deck
        case .existing(let target):
            return ImportedDeck(
                id: target.id,
                parentId: target.parentId,
                name: target.name,
                note: target.note,
                dueDate: target.dueDate,
                dueDateProvided: false,
                isArchived: target.isArchived,
                cards: deck.cards,
                token: deck.token
            )
        }
    }
}
