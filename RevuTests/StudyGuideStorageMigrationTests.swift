import Foundation
import Testing
@testable import Revu

@Suite("Study guide storage migration")
struct StudyGuideStorageMigrationTests {
    @Test("Decodes legacy study_guides.json without new fields")
    func decodesLegacyStudyGuidesWithDefaults() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("revu-study-guide-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let guideID = UUID()
        let createdAt = "2026-01-01T10:00:00Z"
        let updatedAt = "2026-01-02T12:00:00Z"
        let legacyJSON = """
        [
          {
            "id": "\(guideID.uuidString)",
            "title": "Legacy Guide",
            "markdownContent": "# Legacy",
            "createdAt": "\(createdAt)",
            "updatedAt": "\(updatedAt)"
          }
        ]
        """
        try legacyJSON.data(using: .utf8)?.write(to: root.appendingPathComponent("study_guides.json"))

        let storage = try await MainActor.run { try SQLiteStorage(rootURL: root) }
        let guides = try await storage.allStudyGuides()
        let guide = try #require(guides.first)
        #expect(guide.attachments.isEmpty)
        #expect(guide.tags.isEmpty)
        #expect(guide.lastEditedAt == guide.updatedAt)
    }
}
