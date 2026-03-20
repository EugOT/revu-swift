import Foundation
import Testing
@testable import Revu

@Suite("Local data management")
struct LocalDataManagementTests {
    @Test("wipeAllLocalData clears decks, cards, and attachments")
    func testWipeAllLocalData() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = try await MainActor.run { try SQLiteStorage(rootURL: root) }

        let deck = Deck(name: "Biology")
        try await storage.upsert(deck: deck.toDTO())
        let card = Card(deckId: deck.id, kind: .basic, front: "Q", back: "A")
        try await storage.upsert(card: card.toDTO())

        var settings = try await storage.loadSettings()
        settings.dailyNewLimit = 42
        try await storage.save(settings: settings)

        let attachmentDir = (storage as AttachmentDirectoryProviding).attachmentsDirectory
        let attachmentURL = attachmentDir.appendingPathComponent("fixture.txt")
        try Data("hello".utf8).write(to: attachmentURL, options: [.atomic])

        #expect(try await storage.allDecks().isEmpty == false)
        #expect(try await storage.allCards().isEmpty == false)
        #expect(FileManager.default.fileExists(atPath: attachmentURL.path))

        try await storage.wipeAllLocalData()

        #expect(try await storage.allDecks().isEmpty)
        #expect(try await storage.allCards().isEmpty)
        #expect(FileManager.default.fileExists(atPath: attachmentURL.path) == false)

        let freshSettings = try await storage.loadSettings()
        #expect(freshSettings.dailyNewLimit == AppSettingsDefaults.dailyNewLimit)
    }

    @Test("archiveAllDecks marks decks archived and suspends cards")
    func testArchiveAllDecks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = try await MainActor.run { try SQLiteStorage(rootURL: root) }

        let deckA = Deck(name: "Deck A")
        let deckB = Deck(name: "Deck B")
        try await storage.upsert(deck: deckA.toDTO())
        try await storage.upsert(deck: deckB.toDTO())

        let activeCard = Card(deckId: deckA.id, kind: .basic, front: "Q1", back: "A1")
        var manuallySuspended = Card(deckId: deckB.id, kind: .basic, front: "Q2", back: "A2")
        manuallySuspended.isSuspended = true
        manuallySuspended.suspendedByArchive = false

        try await storage.upsert(card: activeCard.toDTO())
        try await storage.upsert(card: manuallySuspended.toDTO())

        await DeckService(storage: storage).archiveAllDecks()

        let decks = try await storage.allDecks().map { $0.toDomain() }
        #expect(decks.allSatisfy { $0.isArchived })

        let cards = try await storage.allCards().map { $0.toDomain() }
        let updatedActive = try #require(cards.first(where: { $0.id == activeCard.id }))
        #expect(updatedActive.isSuspended)
        #expect(updatedActive.suspendedByArchive)

        let updatedManual = try #require(cards.first(where: { $0.id == manuallySuspended.id }))
        #expect(updatedManual.isSuspended)
        #expect(updatedManual.suspendedByArchive == false)
    }
}
