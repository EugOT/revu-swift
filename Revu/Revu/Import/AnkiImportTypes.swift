import CryptoKit
import Foundation

enum AnkiImportError: Error, LocalizedError, Equatable {
    case noSourceSelected
    case missingCollection
    case packageExtractionFailed(String)
    case unreadableMediaMapping
    case sqliteOpenFailed(String)
    case sqliteQueryFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSourceSelected:
            return "No Anki source selected."
        case .missingCollection:
            return "Could not find Anki collection database (collection.anki2 / collection.anki21)."
        case .packageExtractionFailed(let detail):
            if detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Could not extract the Anki package."
            }
            return "Could not extract the Anki package: \(detail)"
        case .unreadableMediaMapping:
            return "Could not read Anki media mapping file."
        case .sqliteOpenFailed(let detail):
            return "Could not open Anki collection: \(detail)"
        case .sqliteQueryFailed(let detail):
            return "Could not read Anki data: \(detail)"
        }
    }
}

struct AnkiCollectionLocation: Sendable, Hashable {
    var databaseURL: URL
    var mediaDirectoryURL: URL?
    var mediaMappingURL: URL?
    var displayName: String

    init(
        databaseURL: URL,
        mediaDirectoryURL: URL?,
        mediaMappingURL: URL?,
        displayName: String
    ) {
        self.databaseURL = databaseURL
        self.mediaDirectoryURL = mediaDirectoryURL
        self.mediaMappingURL = mediaMappingURL
        self.displayName = displayName
    }
}

struct AnkiDeckMetadata: Sendable, Hashable {
    var ankiID: Int64
    var id: UUID
    var name: String
    var description: String?
    var isDynamic: Bool
}

struct AnkiModelMetadata: Sendable, Hashable {
    var ankiID: Int64
    var name: String
    var isCloze: Bool
    var fieldNames: [String]
    var templates: [AnkiTemplateMetadata]
    var clozeFieldName: String?
}

struct AnkiTemplateMetadata: Sendable, Hashable {
    var name: String
    var questionFormat: String
    var answerFormat: String
}

struct AnkiImportOptions: Sendable, Hashable {
    var includeScheduling: Bool
    var includeMedia: Bool

    init(includeScheduling: Bool = true, includeMedia: Bool = true) {
        self.includeScheduling = includeScheduling
        self.includeMedia = includeMedia
    }
}

enum StableAnkiUUID {
    static func deckID(_ ankiID: Int64) -> UUID {
        stableUUID("anki.deck.\(ankiID)")
    }

    static func deckPathID(_ path: String) -> UUID {
        stableUUID("anki.deckpath.\(path.lowercased())")
    }

    static func cardID(_ ankiID: Int64) -> UUID {
        stableUUID("anki.card.\(ankiID)")
    }

    static func noteID(_ ankiID: Int64) -> UUID {
        stableUUID("anki.note.\(ankiID)")
    }

    private static func stableUUID(_ name: String) -> UUID {
        let digest = SHA256.hash(data: Data(name.utf8))
        let bytes = Array(digest)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
