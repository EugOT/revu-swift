import Foundation
import UniformTypeIdentifiers

protocol DeckImporter {
    func loadPreview(from source: ImportSource) async throws -> ImportPreviewDetails
    func performImport(from source: ImportSource, mergePlan: DeckMergePlan) async throws -> ImportResult
}

struct DeckImporterDescriptor {
    let id: String
    let displayName: String
    let supportedContentTypes: [UTType]
    let supportedFileExtensions: [String]
    let priority: Int
    private let matcher: (ImportSource) -> Bool
    private let factory: (Storage) -> DeckImporter

    init(
        id: String,
        displayName: String,
        supportedContentTypes: [UTType] = [],
        supportedFileExtensions: [String] = [],
        priority: Int = 0,
        matcher: @escaping (ImportSource) -> Bool,
        factory: @escaping (Storage) -> DeckImporter
    ) {
        self.id = id
        self.displayName = displayName
        self.supportedContentTypes = supportedContentTypes
        self.supportedFileExtensions = supportedFileExtensions.map { $0.lowercased() }
        self.priority = priority
        self.matcher = matcher
        self.factory = factory
    }

    func matches(_ source: ImportSource) -> Bool {
        extensionMatches(source) || contentTypeMatches(source) || matcher(source)
    }

    func makeImporter(storage: Storage) -> DeckImporter {
        factory(storage)
    }

    func extensionMatches(_ source: ImportSource) -> Bool {
        guard !supportedFileExtensions.isEmpty else { return false }
        guard let filename = source.filename?.lowercased(), let ext = filename.split(separator: ".").last else {
            return false
        }
        return supportedFileExtensions.contains(String(ext))
    }

    func contentTypeMatches(_ source: ImportSource) -> Bool {
        guard let type = source.contentType, type != .plainText else { return false }
        return supportedContentTypes.contains(where: { type.conforms(to: $0) })
    }

    func heuristicMatches(_ source: ImportSource) -> Bool {
        matcher(source)
    }
}

final class DeckImportCoordinator {
    private let storage: Storage
    private let descriptors: [DeckImporterDescriptor]

    init(storage: Storage, descriptors: [DeckImporterDescriptor]? = nil) {
        self.storage = storage
        let resolvedDescriptors = descriptors ?? Self.makeDefaultDescriptors()
        self.descriptors = resolvedDescriptors.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.id < rhs.id
            }
            return lhs.priority > rhs.priority
        }
    }

    static var supportedContentTypes: [UTType] {
        var set = Set<UTType>()
        for descriptor in makeDefaultDescriptors() {
            set.formUnion(descriptor.supportedContentTypes)
        }
        if let markdown = UTType(filenameExtension: "md") {
            set.insert(markdown)
        }
        set.insert(.plainText)
        return Array(set)
    }

    func loadPreview(from source: ImportSource) async throws -> (preview: ImportPreview, descriptorID: String) {
        let descriptor = try resolveDescriptor(for: source)
        let importer = descriptor.makeImporter(storage: storage)
        let details = try await importer.loadPreview(from: source)
        let preview = ImportPreview(
            formatIdentifier: descriptor.id,
            formatName: descriptor.displayName,
            deckCount: details.deckCount,
            cardCount: details.cardCount,
            decks: details.decks,
            errors: details.errors
        )
        return (preview, descriptor.id)
    }

    func performImport(using descriptorID: String, source: ImportSource, mergePlan: DeckMergePlan? = nil) async throws -> ImportResult {
        guard let descriptor = descriptors.first(where: { $0.id == descriptorID }) else {
            throw ImportErrorDetail(line: nil, path: "format", message: "Unsupported import format: \(descriptorID)")
        }
        let importer = descriptor.makeImporter(storage: storage)
        let effectiveMergePlan = mergePlan ?? DeckMergePlan()
        return try await importer.performImport(from: source, mergePlan: effectiveMergePlan)
    }

    private func resolveDescriptor(for source: ImportSource) throws -> DeckImporterDescriptor {
        if let match = descriptors.first(where: { $0.extensionMatches(source) }) {
            return match
        }
        if let match = descriptors.first(where: { $0.contentTypeMatches(source) }) {
            return match
        }
        if let match = descriptors.first(where: { $0.heuristicMatches(source) }) {
            return match
        }
        throw ImportErrorDetail(line: nil, path: "format", message: "No importer available for this file")
    }
}

private extension DeckImportCoordinator {
    static func makeDefaultDescriptors() -> [DeckImporterDescriptor] {
        let ankiTypes: [UTType] = {
            var types: [UTType] = []
            if let apkg = UTType(filenameExtension: "apkg") { types.append(apkg) }
            if let colpkg = UTType(filenameExtension: "colpkg") { types.append(colpkg) }
            return types
        }()

        let ankiDescriptor = DeckImporterDescriptor(
            id: "anki",
            displayName: "Anki Package",
            supportedContentTypes: ankiTypes,
            supportedFileExtensions: ["apkg", "colpkg"],
            priority: 95,
            matcher: { source in
                // Prefer explicit package extensions. Otherwise, only claim ZIPs that advertise an Anki collection inside.
                if let filename = source.filename?.lowercased(), filename.hasSuffix(".apkg") || filename.hasSuffix(".colpkg") {
                    return true
                }
                guard source.data.starts(with: [0x50, 0x4B]) else { return false }
                let sample = source.data.prefix(2_000_000)
                guard let text = String(data: sample, encoding: .utf8) else { return false }
                return text.contains("collection.anki2") || text.contains("collection.anki21")
            },
            factory: { storage in AnkiImporter(storage: storage) }
        )

        let jsonDescriptor = DeckImporterDescriptor(
            id: "json",
            displayName: "Revu JSON",
            supportedContentTypes: [.json],
            supportedFileExtensions: ["json"],
            priority: 100,
            matcher: { source in
                guard let first = source.data.firstNonWhitespaceCharacter else { return false }
                return first == "{" || first == "["
            },
            factory: { storage in JSONImporter(storage: storage) }
        )

        let csvTypes: [UTType] = {
            let result: [UTType] = [
                .commaSeparatedText,
                .tabSeparatedText,
                .plainText
            ]
            return result
        }()

        let csvDescriptor = DeckImporterDescriptor(
            id: "csv",
            displayName: "CSV / TSV",
            supportedContentTypes: csvTypes,
            supportedFileExtensions: ["csv", "tsv"],
            priority: 80,
            matcher: { source in
                guard let sample = String(data: source.data.prefix(2048), encoding: .utf8) else {
                    return false
                }
                guard let headerLine = sample.split(whereSeparator: \.isNewline).first else {
                    return false
                }

                let separators: [Character] = [",", "\t"]
                guard let separator = separators.first(where: { headerLine.contains($0) }) else {
                    return false
                }

                let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{feff}"))
                let columns = headerLine
                    .split(separator: separator)
                    .map { $0.trimmingCharacters(in: trimSet).lowercased() }
                    .filter { !$0.isEmpty }

                guard columns.count >= 2 else { return false }

                let expectedHeaders: Set<String> = ["deck", "front", "back", "prompt", "cloze", "choices", "kind"]
                return columns.contains(where: { expectedHeaders.contains($0) })
            },
            factory: { storage in CSVImporter(storage: storage) }
        )

        let markdownDescriptor = DeckImporterDescriptor(
            id: "markdown",
            displayName: "Markdown Blocks",
            supportedContentTypes: [UTType(filenameExtension: "md") ?? .plainText],
            supportedFileExtensions: ["md", "markdown"],
            priority: 90,
            matcher: { source in
                if let sample = String(data: source.data.prefix(4096), encoding: .utf8)?.lowercased() {
                    if sample.contains("deck:") || sample.contains("\n---") || sample.contains("---\n") {
                        return true
                    }
                }
                return false
            },
            factory: { storage in MarkdownImporter(storage: storage) }
        )

        return [jsonDescriptor, ankiDescriptor, csvDescriptor, markdownDescriptor]
    }
}

private extension Data {
    var firstNonWhitespaceCharacter: Character? {
        guard let string = String(data: self, encoding: .utf8) else { return nil }
        for char in string {
            if !char.isWhitespace { return char }
        }
        return nil
    }
}
