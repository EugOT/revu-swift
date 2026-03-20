import Foundation
import Testing
@testable import Revu

@Suite("Deck model")
struct DeckModelTests {

    // MARK: - Legacy decode default

    @Test("DeckDTO decodes legacy JSON without kind field as .deck")
    func legacyDecodeDefaultsToKindDeck() throws {
        // Simulate JSON from older versions that had no `kind` field
        let legacyJSON = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "Old Deck",
            "createdAt": "2025-01-15T12:00:00Z",
            "updatedAt": "2025-01-15T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(DeckDTO.self, from: legacyJSON)

        #expect(dto.kind == .deck, "Missing kind field should default to .deck")
        #expect(dto.name == "Old Deck")
    }

    @Test("Deck decodes legacy JSON without kind field as .deck")
    func deckLegacyDecodeDefaultsToKindDeck() throws {
        // Simulate JSON from older versions that had no `kind` field
        let legacyJSON = """
        {
            "id": "22222222-2222-2222-2222-222222222222",
            "name": "Old Deck Model",
            "createdAt": "2025-01-15T12:00:00Z",
            "updatedAt": "2025-01-15T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let deck = try decoder.decode(Deck.self, from: legacyJSON)

        #expect(deck.kind == .deck, "Missing kind field should default to .deck")
        #expect(deck.isFolder == false)
        #expect(deck.name == "Old Deck Model")
    }

    // MARK: - Round-trip with folder kind

    @Test("DeckDTO round-trips folder kind correctly")
    func deckDTORoundTripsFolderKind() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = DeckDTO(
            id: UUID(),
            parentId: nil,
            kind: .folder,
            name: "My Folder",
            note: "A test folder",
            dueDate: nil,
            createdAt: Date(),
            updatedAt: Date(),
            isArchived: false
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DeckDTO.self, from: data)

        #expect(decoded.kind == .folder, "Folder kind should survive round-trip")
        #expect(decoded.name == "My Folder")
    }

    @Test("Deck round-trips folder kind correctly")
    func deckRoundTripsFolderKind() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = Deck(
            id: UUID(),
            parentId: nil,
            kind: .folder,
            name: "Another Folder",
            note: nil,
            dueDate: nil,
            createdAt: Date(),
            updatedAt: Date(),
            isArchived: false
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Deck.self, from: data)

        #expect(decoded.kind == .folder, "Folder kind should survive round-trip")
        #expect(decoded.isFolder == true)
        #expect(decoded.name == "Another Folder")
    }

    @Test("DeckDTO round-trips deck kind correctly")
    func deckDTORoundTripsDeckKind() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = DeckDTO(
            id: UUID(),
            parentId: nil,
            kind: .deck,
            name: "Regular Deck",
            note: nil,
            dueDate: nil,
            createdAt: Date(),
            updatedAt: Date(),
            isArchived: false
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DeckDTO.self, from: data)

        #expect(decoded.kind == .deck, "Deck kind should survive round-trip")
        #expect(decoded.name == "Regular Deck")
    }

    // MARK: - JSON output verification

    @Test("Encoded JSON contains kind field")
    func encodedJSONContainsKindField() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys

        let folder = DeckDTO(
            id: UUID(),
            parentId: nil,
            kind: .folder,
            name: "Test",
            note: nil,
            dueDate: nil,
            createdAt: Date(),
            updatedAt: Date(),
            isArchived: false
        )

        let data = try encoder.encode(folder)
        let jsonString = String(data: data, encoding: .utf8)!

        #expect(jsonString.contains("\"kind\":\"folder\""), "Encoded JSON should contain kind field")
    }

    @Test("isFolder helper returns correct value")
    func isFolderHelper() {
        let folder = Deck(kind: .folder, name: "Folder")
        let deck = Deck(kind: .deck, name: "Deck")
        let defaultDeck = Deck(name: "Default")

        #expect(folder.isFolder == true)
        #expect(deck.isFolder == false)
        #expect(defaultDeck.isFolder == false, "Default kind should be .deck, so isFolder is false")
    }
}
