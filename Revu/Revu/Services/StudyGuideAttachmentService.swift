import Foundation
import UniformTypeIdentifiers

struct StudyGuideAttachmentService {
    enum Error: LocalizedError {
        case attachmentStorageUnavailable
        case unreadableFile

        var errorDescription: String? {
            switch self {
            case .attachmentStorageUnavailable:
                return "Attachment storage is unavailable for this workspace."
            case .unreadableFile:
                return "Could not read the selected file."
            }
        }
    }

    private let attachmentsRoot: URL
    private let fileManager = FileManager.default

    init(storage: Storage) throws {
        guard let provider = storage as? AttachmentDirectoryProviding else {
            throw Error.attachmentStorageUnavailable
        }
        attachmentsRoot = provider.attachmentsDirectory
    }

    func importFile(from sourceURL: URL, guideId: UUID) throws -> StudyGuideAttachment {
        guard let data = try? Data(contentsOf: sourceURL) else {
            throw Error.unreadableFile
        }
        let mime = Self.mimeType(for: sourceURL) ?? "application/octet-stream"
        return try save(data: data, filename: sourceURL.lastPathComponent, mimeType: mime, guideId: guideId)
    }

    func save(data: Data, filename: String, mimeType: String, guideId: UUID) throws -> StudyGuideAttachment {
        let attachmentID = UUID()
        let sanitized = Self.sanitizedFilename(filename)
        let relativePath = Self.relativePath(guideId: guideId, attachmentId: attachmentID, sanitizedFilename: sanitized)
        let absolutePath = attachmentsRoot.appendingPathComponent(relativePath, isDirectory: false)

        let guideDirectory = attachmentsRoot
            .appendingPathComponent("study-guides", isDirectory: true)
            .appendingPathComponent(guideId.uuidString.lowercased(), isDirectory: true)
        if !fileManager.fileExists(atPath: guideDirectory.path) {
            try fileManager.createDirectory(at: guideDirectory, withIntermediateDirectories: true)
        }

        try data.write(to: absolutePath, options: .atomic)
        return StudyGuideAttachment(
            id: attachmentID,
            filename: filename,
            relativePath: relativePath,
            mimeType: mimeType,
            sizeBytes: Int64(data.count),
            createdAt: Date()
        )
    }

    func url(for attachment: StudyGuideAttachment) -> URL {
        attachmentsRoot.appendingPathComponent(attachment.relativePath, isDirectory: false)
    }

    static func relativePath(guideId: UUID, attachmentId: UUID, sanitizedFilename: String) -> String {
        "study-guides/\(guideId.uuidString.lowercased())/\(attachmentId.uuidString.lowercased())-\(sanitizedFilename)"
    }

    static func sanitizedFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "attachment" }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let sanitizedScalars = trimmed.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(sanitizedScalars).replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        let cleaned = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return cleaned.isEmpty ? "attachment" : cleaned
    }

    static func mimeType(for fileURL: URL) -> String? {
        if let type = UTType(filenameExtension: fileURL.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return nil
    }
}
