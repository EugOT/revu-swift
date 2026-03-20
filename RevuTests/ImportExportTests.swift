//import XCTest
//import SwiftData
//@testable import Revu
//
//@MainActor
//final class ImportExportTests: XCTestCase {
//    private func makeContext() throws -> ModelContext {
//        let container = try RevuSchema.makeInMemoryContainer()
//        return ModelContext(container)
//    }
//
//    private func sampleJSON(updatedAt: String = "2025-10-03T12:00:00Z") -> Data {
//        let deckId = "550e8400-e29b-41d4-a716-446655440000"
//        let cardId = "2d931510-d99f-494a-8c67-87feb05e1594"
//        let json = """
//        {
//          "schema": "revu.flashcards",
//          "version": 1,
//          "exportedAt": "2025-10-03T12:00:00Z",
//          "decks": [
//            {
//              "id": "\(deckId)",
//              "name": "Demo",
//              "note": null,
//              "cards": [
//                {
//                  "id": "\(cardId)",
//                  "kind": "basic",
//                  "front": "Front",
//                  "back": "Back",
//                  "clozeSource": null,
//                  "tags": ["demo"],
//                  "media": [],
//                  "createdAt": "2025-10-03T10:00:00Z",
//                  "updatedAt": "\(updatedAt)"
//                }
//              ]
//            }
//          ]
//        }
//        """
//        return Data(json.utf8)
//    }
//
//    func testImportCreatesData() throws {
//        let context = try makeContext()
//        let importer = JSONImporter(context: context)
//        let result = try importer.performImport(from: sampleJSON())
//        XCTAssertEqual(result.decksInserted, 1)
//        XCTAssertEqual(result.cardsInserted, 1)
//        XCTAssertTrue(result.errors.isEmpty)
//
//        let decks = try context.fetch(FetchDescriptor<Deck>())
//        XCTAssertEqual(decks.count, 1)
//        XCTAssertEqual(decks.first?.cards.count, 1)
//    }
//
//    func testImportSkipsOlderCards() throws {
//        let context = try makeContext()
//        let importer = JSONImporter(context: context)
//        try importer.performImport(from: sampleJSON())
//
//        let olderData = sampleJSON(updatedAt: "2025-09-01T12:00:00Z")
//        let result = try importer.performImport(from: olderData)
//        XCTAssertEqual(result.cardsSkipped, 1)
//        XCTAssertEqual(result.cardsUpdated, 0)
//    }
//
//    func testPreviewReportsValidationError() throws {
//        let data = Data(
//            """
//            {
//              "schema": "revu.flashcards",
//              "version": 1,
//              "exportedAt": "2025-10-03T12:00:00Z",
//              "decks": [
//                {
//                  "id": "550e8400-e29b-41d4-a716-446655440000",
//                  "name": "",
//                  "note": null,
//                  "cards": [
//                    {
//                      "id": "2d931510-d99f-494a-8c67-87feb05e1594",
//                      "kind": "basic",
//                      "front": "",
//                      "back": "Back",
//                      "tags": [],
//                      "media": [],
//                      "createdAt": "2025-10-03T10:00:00Z",
//                      "updatedAt": "2025-10-03T12:00:00Z"
//                    }
//                  ]
//                }
//              ]
//            }
//            """.utf8
//        )
//        let context = try makeContext()
//        let importer = JSONImporter(context: context)
//        let preview = try importer.loadPreview(from: data)
//        XCTAssertEqual(preview.errors.count, 2)
//    }
//
//    func testExportRoundTrip() throws {
//        let context = try makeContext()
//        let importer = JSONImporter(context: context)
//        try importer.performImport(from: sampleJSON())
//
//        let decks = try context.fetch(FetchDescriptor<Deck>())
//        let exporter = JSONExporter(context: context)
//        let data = try exporter.export(decks: decks)
//        let decoder = JSONDecoder()
//        decoder.dateDecodingStrategy = .iso8601
//        let document = try decoder.decode(JSONFlashcardDocument.self, from: data)
//        XCTAssertEqual(document.decks.count, 1)
//        XCTAssertEqual(document.decks.first?.cards.count, 1)
//        XCTAssertEqual(document.decks.first?.cards.first?.front, "Front")
//    }
//}
