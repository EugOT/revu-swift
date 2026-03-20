import Foundation

final class AnkiImporter: DeckImporter {
    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    func loadPreview(from source: ImportSource) async throws -> ImportPreviewDetails {
        let workspace = try AnkiTemporaryWorkspace.fromPackageData(source.data, filename: source.filename)
        defer { workspace.cleanup() }
        return try AnkiImportEngine.loadPreviewDetails(from: workspace.location)
    }

    func performImport(from source: ImportSource, mergePlan: DeckMergePlan) async throws -> ImportResult {
        let workspace = try AnkiTemporaryWorkspace.fromPackageData(source.data, filename: source.filename)
        defer { workspace.cleanup() }
        return try await AnkiImportEngine.performImport(
            from: workspace.location,
            storage: storage,
            mergePlan: mergePlan
        )
    }
}

