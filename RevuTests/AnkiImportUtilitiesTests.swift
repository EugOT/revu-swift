import Foundation
import SQLite3
import Testing
@testable import Revu

@Suite("Anki import")
struct AnkiImportUtilitiesTests {
    @Test("Cloze transformation keeps only the target deletion hidden")
    func clozeTransformationKeepsTargetOnly() {
        let source = "ATP is produced in the {{c1::mitochondria}} and stored as {{c2::ATP::molecule}}."
        let c1 = AnkiImportUtilities.clozeSource(from: source, targetIndex: 1)
        #expect(c1.contains("{{c1::mitochondria}}"))
        #expect(!c1.contains("{{c2::"))
        #expect(c1.contains("stored as ATP"))

        let c2 = AnkiImportUtilities.clozeSource(from: source, targetIndex: 2)
        #expect(!c2.contains("{{c1::"))
        #expect(c2.contains("{{c2::ATP::molecule}}"))
        #expect(c2.contains("produced in the mitochondria"))
    }

    @Test("Media reference extraction finds images and sound")
    func mediaReferenceExtraction() {
        let html = #"""
        <div><img src="paste-123.png"></div>
        <div>[sound:audio-file.mp3]</div>
        <audio src="https://example.com/path/voice.m4a"></audio>
        """#

        let refs = AnkiImportUtilities.mediaReferences(in: html)
        #expect(refs.contains("paste-123.png"))
        #expect(refs.contains("audio-file.mp3"))
        #expect(refs.contains("voice.m4a"))
    }

    @Test("Preview counts cards by home deck (odid fallback)")
    func previewCountsCardsByHomeDeck() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let dbURL = root.appendingPathComponent("collection.anki2")
        var db: OpaquePointer?
        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK, let db else {
            Issue.record("Failed to create sqlite database")
            return
        }
        defer { sqlite3_close(db) }

        func exec(_ sql: String) {
            _ = sqlite3_exec(db, sql, nil, nil, nil)
        }

        exec("CREATE TABLE col (crt integer, decks text, models text);")
        exec("CREATE TABLE cards (id integer, did integer, odid integer);")

        let decksJSON = #"""
        {
          "123": { "id": 123, "name": "Test::Deck", "desc": "<b>Hello</b>", "dyn": 0 }
        }
        """#
        let modelsJSON = "{}"
        let insertCol = "INSERT INTO col (crt, decks, models) VALUES (0, '\(Self.escapeSQL(decksJSON))', '\(Self.escapeSQL(modelsJSON))');"
        exec(insertCol)

        // One card directly in the deck, one card temporarily in a filtered deck (odid points home).
        exec("INSERT INTO cards (id, did, odid) VALUES (1, 123, 0);")
        exec("INSERT INTO cards (id, did, odid) VALUES (2, 999, 123);")

        let location = AnkiCollectionLocation(
            databaseURL: dbURL,
            mediaDirectoryURL: nil,
            mediaMappingURL: nil,
            displayName: "Test"
        )

        let preview = try AnkiImportEngine.loadPreviewDetails(from: location)
        #expect(preview.deckCount == 1)
        #expect(preview.cardCount == 2)
        #expect(preview.decks.first?.cardCount == 2)
        #expect(preview.decks.first?.name == "Test::Deck")
    }

    private static func escapeSQL(_ input: String) -> String {
        input.replacingOccurrences(of: "'", with: "''")
    }
}
