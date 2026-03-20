@preconcurrency import Foundation

struct Card: Identifiable, Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case basic
        case cloze
        case multipleChoice

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .basic:
                return "Flashcard"
            case .cloze:
                return "Cloze"
            case .multipleChoice:
                return "Multiple Choice"
            }
        }
    }

    var id: UUID
    var deckId: UUID?
    var kind: Kind
    var front: String
    var back: String
    var clozeSource: String?
    var choices: [String]
    var correctChoiceIndex: Int?
    var tags: [String]
    var sourceRef: String?
    var media: [URL]
    var createdAt: Date
    var updatedAt: Date
    var isSuspended: Bool
    var suspendedByArchive: Bool
    var srs: SRSState

    init(
        id: UUID = UUID(),
        deckId: UUID? = nil,
        kind: Kind,
        front: String = "",
        back: String = "",
        clozeSource: String? = nil,
        choices: [String] = [],
        correctChoiceIndex: Int? = nil,
        tags: [String] = [],
        sourceRef: String? = nil,
        media: [URL] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSuspended: Bool = false,
        suspendedByArchive: Bool = false,
        srs: SRSState = SRSState()
    ) {
        self.id = id
        self.deckId = deckId
        self.kind = kind
        self.front = front
        self.back = back
        self.clozeSource = clozeSource
        self.choices = choices
        self.correctChoiceIndex = correctChoiceIndex
        self.tags = tags
        self.sourceRef = sourceRef
        self.media = media
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSuspended = isSuspended
        self.suspendedByArchive = suspendedByArchive
        var state = srs
        state.cardId = id
        self.srs = state
    }
}
