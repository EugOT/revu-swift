import Foundation

final class AnkiMediaResolver {
    private let fileManager: FileManager
    private let sourceDirectory: URL
    private let destinationDirectory: URL
    private let filenameToKey: [String: String]
    private var cache: [String: URL] = [:]

    init(
        sourceDirectory: URL,
        destinationRoot: URL,
        mappingFile: URL?,
        importNamespace: String,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        self.sourceDirectory = sourceDirectory

        let destination = destinationRoot
            .appendingPathComponent("anki", isDirectory: true)
            .appendingPathComponent(importNamespace, isDirectory: true)
        self.destinationDirectory = destination

        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        self.filenameToKey = try Self.loadMediaKeyLookup(from: mappingFile, fileManager: fileManager)
    }

    func resolveMediaURLs(from html: String) -> [URL] {
        let references = AnkiImportUtilities.mediaReferences(in: html)
        guard !references.isEmpty else { return [] }
        return references.compactMap { resolveMediaURL(named: $0) }
    }

    func resolveMediaURLs(names: [String]) -> [URL] {
        names.compactMap { resolveMediaURL(named: $0) }
    }

    private func resolveMediaURL(named raw: String) -> URL? {
        let name = AnkiImportUtilities.normalizeMediaReference(raw)
        guard !name.isEmpty else { return nil }

        if let cached = cache[name] {
            return cached
        }

        let source = resolveSourceFile(named: name)
        guard let source, fileManager.fileExists(atPath: source.path) else {
            return nil
        }

        let destinationFilename = sanitizedFilename(name, key: filenameToKey[name])
        let destination = destinationDirectory.appendingPathComponent(destinationFilename, isDirectory: false)

        if !fileManager.fileExists(atPath: destination.path) {
            do {
                try fileManager.copyItem(at: source, to: destination)
            } catch {
                return nil
            }
        }

        cache[name] = destination
        return destination
    }

    private func resolveSourceFile(named name: String) -> URL? {
        if let key = filenameToKey[name] {
            let candidate = sourceDirectory.appendingPathComponent(key, isDirectory: false)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        let direct = sourceDirectory.appendingPathComponent(name, isDirectory: false)
        if fileManager.fileExists(atPath: direct.path) {
            return direct
        }

        return nil
    }

    private func sanitizedFilename(_ original: String, key: String?) -> String {
        let base = original
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let key, !key.isEmpty else {
            return base
        }

        return "\(key)-\(base)"
    }

    private static func loadMediaKeyLookup(from mappingFile: URL?, fileManager: FileManager) throws -> [String: String] {
        guard let mappingFile else { return [:] }
        guard fileManager.fileExists(atPath: mappingFile.path) else { return [:] }

        do {
            let data = try Data(contentsOf: mappingFile)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let mapping = json as? [String: String] else { return [:] }
            var lookup: [String: String] = [:]
            lookup.reserveCapacity(mapping.count)
            for (key, filename) in mapping {
                let normalized = filename.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty else { continue }
                lookup[normalized] = key
            }
            return lookup
        } catch {
            throw AnkiImportError.unreadableMediaMapping
        }
    }
}

