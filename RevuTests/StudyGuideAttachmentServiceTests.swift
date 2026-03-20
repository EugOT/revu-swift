import Foundation
import Testing
@testable import Revu

@Suite("Study guide attachment service")
struct StudyGuideAttachmentServiceTests {
    @Test("Stores attachments under study-guides layout and returns relative path")
    func storesAttachmentAtExpectedPath() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("revu-study-guide-attachments-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storage = try await MainActor.run { try SQLiteStorage(rootURL: root) }
        let service = try StudyGuideAttachmentService(storage: storage)

        let guideID = UUID()
        let attachment = try service.save(
            data: Data("hello".utf8),
            filename: "My Notes!.txt",
            mimeType: "text/plain",
            guideId: guideID
        )

        #expect(attachment.relativePath.hasPrefix("study-guides/\(guideID.uuidString.lowercased())/"))
        #expect(attachment.relativePath.contains("-My-Notes-.txt"))
        #expect(FileManager.default.fileExists(atPath: service.url(for: attachment).path))
    }

    @Test("Attachment fields survive DTO encoding/decoding")
    func attachmentSerializationRoundTrips() throws {
        let attachment = StudyGuideAttachmentDTO(
            id: UUID(),
            filename: "diagram.png",
            relativePath: "study-guides/g/a-diagram.png",
            mimeType: "image/png",
            sizeBytes: 123,
            createdAt: Date()
        )
        let dto = StudyGuideDTO(
            id: UUID(),
            parentFolderId: nil,
            title: "Guide",
            markdownContent: "![diagram](study-guides/g/a-diagram.png)",
            attachments: [attachment],
            tags: ["bio"],
            createdAt: Date(),
            lastEditedAt: Date()
        )

        let encoded = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(StudyGuideDTO.self, from: encoded)
        #expect(decoded.attachments.count == 1)
        #expect(decoded.tags == ["bio"])
    }
}
