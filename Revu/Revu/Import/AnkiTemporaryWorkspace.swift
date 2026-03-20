import Foundation

struct AnkiTemporaryWorkspace: Sendable {
    let rootDirectory: URL
    let location: AnkiCollectionLocation

    init(rootDirectory: URL, location: AnkiCollectionLocation) {
        self.rootDirectory = rootDirectory
        self.location = location
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    static func fromPackageData(_ data: Data, filename: String?) throws -> AnkiTemporaryWorkspace {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("revu-anki-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let resolvedFilename = (filename?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "import.apkg"
        let packageURL = tempRoot.appendingPathComponent(resolvedFilename, isDirectory: false)
        try data.write(to: packageURL, options: [.atomic])

        return try fromPreparedPackage(at: packageURL, filename: filename, rootDirectory: tempRoot)
    }

    static func fromPackageFile(_ packageURL: URL, filename: String? = nil) throws -> AnkiTemporaryWorkspace {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("revu-anki-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let resolvedFilename = (filename?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? (packageURL.lastPathComponent.isEmpty ? "import.apkg" : packageURL.lastPathComponent)
        let localPackageURL = tempRoot.appendingPathComponent(resolvedFilename, isDirectory: false)
        try fm.copyItem(at: packageURL, to: localPackageURL)

        return try fromPreparedPackage(at: localPackageURL, filename: resolvedFilename, rootDirectory: tempRoot)
    }

    private static func fromPreparedPackage(at packageURL: URL, filename: String?, rootDirectory: URL) throws -> AnkiTemporaryWorkspace {
        let fm = FileManager.default
        let extractDirectory = rootDirectory.appendingPathComponent("unzipped", isDirectory: true)
        try fm.createDirectory(at: extractDirectory, withIntermediateDirectories: true)
        try extractZipArchive(at: packageURL, to: extractDirectory)

        guard let databaseURL = locateCollectionDatabase(in: extractDirectory) else {
            throw AnkiImportError.missingCollection
        }

        let mappingURL = extractDirectory.appendingPathComponent("media", isDirectory: false)
        let resolvedMapping = fm.fileExists(atPath: mappingURL.path) ? mappingURL : nil

        let display = ((filename?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Anki Import")
            .replacingOccurrences(of: ".apkg", with: "")
            .replacingOccurrences(of: ".colpkg", with: "")
        let location = AnkiCollectionLocation(
            databaseURL: databaseURL,
            mediaDirectoryURL: extractDirectory,
            mediaMappingURL: resolvedMapping,
            displayName: display
        )

        return AnkiTemporaryWorkspace(rootDirectory: rootDirectory, location: location)
    }

    static func fromProfileFolder(_ profileURL: URL) throws -> AnkiTemporaryWorkspace {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("revu-anki-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let sourceDatabase = profileURL.appendingPathComponent("collection.anki2", isDirectory: false)
        guard fm.fileExists(atPath: sourceDatabase.path) else {
            throw AnkiImportError.missingCollection
        }

        let databaseURL = tempRoot.appendingPathComponent("collection.anki2", isDirectory: false)
        try fm.copyItem(at: sourceDatabase, to: databaseURL)

        let wal = profileURL.appendingPathComponent("collection.anki2-wal", isDirectory: false)
        if fm.fileExists(atPath: wal.path) {
            try? fm.copyItem(at: wal, to: tempRoot.appendingPathComponent("collection.anki2-wal", isDirectory: false))
        }

        let shm = profileURL.appendingPathComponent("collection.anki2-shm", isDirectory: false)
        if fm.fileExists(atPath: shm.path) {
            try? fm.copyItem(at: shm, to: tempRoot.appendingPathComponent("collection.anki2-shm", isDirectory: false))
        }

        let mediaDir = profileURL.appendingPathComponent("collection.media", isDirectory: true)
        let resolvedMediaDir = fm.fileExists(atPath: mediaDir.path) ? mediaDir : nil

        let mappingFile = profileURL.appendingPathComponent("media", isDirectory: false)
        let resolvedMapping = fm.fileExists(atPath: mappingFile.path) ? mappingFile : nil

        let location = AnkiCollectionLocation(
            databaseURL: databaseURL,
            mediaDirectoryURL: resolvedMediaDir,
            mediaMappingURL: resolvedMapping,
            displayName: profileURL.lastPathComponent
        )

        return AnkiTemporaryWorkspace(rootDirectory: tempRoot, location: location)
    }

    private static func locateCollectionDatabase(in directory: URL) -> URL? {
        // Some exports include a legacy `collection.anki2` stub plus the real `collection.anki21` database.
        // Prefer the newest known database name to avoid importing only the stub deck.
        let candidates = [
            directory.appendingPathComponent("collection.anki21", isDirectory: false),
            directory.appendingPathComponent("collection.anki2", isDirectory: false),
            directory.appendingPathComponent("collection.anki2.db", isDirectory: false)
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        if let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            var found: [URL] = []
            for case let url as URL in enumerator {
                let name = url.lastPathComponent.lowercased()
                guard name.hasPrefix("collection.anki") else { continue }
                found.append(url)
            }

            if !found.isEmpty {
                found.sort { lhs, rhs in
                    let l = lhs.lastPathComponent.lowercased()
                    let r = rhs.lastPathComponent.lowercased()
                    if l.contains("anki21") != r.contains("anki21") {
                        return l.contains("anki21")
                    }
                    return l < r
                }
                return found.first
            }
        }

        return nil
    }

    private static func extractZipArchive(at sourceURL: URL, to destinationURL: URL) throws {
        let fm = FileManager.default
        if fm.isExecutableFile(atPath: "/usr/bin/ditto") {
            try runProcess(
                executablePath: "/usr/bin/ditto",
                arguments: ["-x", "-k", sourceURL.path, destinationURL.path]
            )
            return
        }

        if fm.isExecutableFile(atPath: "/usr/bin/unzip") {
            try runProcess(
                executablePath: "/usr/bin/unzip",
                arguments: ["-qq", "-o", sourceURL.path, "-d", destinationURL.path]
            )
            return
        }

        throw AnkiImportError.packageExtractionFailed("No unzip tool available.")
    }

    private static func runProcess(executablePath: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
        } catch {
            throw AnkiImportError.packageExtractionFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw AnkiImportError.packageExtractionFailed(output)
        }
    }
}
