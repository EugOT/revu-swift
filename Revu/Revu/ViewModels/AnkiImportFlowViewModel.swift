import Foundation
import Combine

@MainActor
final class AnkiImportFlowViewModel: ObservableObject {
    struct Profile: Identifiable, Hashable, Sendable {
        var id: URL { url }
        var name: String
        var url: URL
    }

    struct Package: Identifiable, Hashable, Sendable {
        var id: URL { url }
        var url: URL
        var filename: String
    }

    enum Phase {
        case source
        case preview(ImportPreview)
        case importing
    }

    @Published private(set) var phase: Phase = .source
    @Published private(set) var profiles: [Profile] = []
    @Published var selectedProfile: Profile?
    @Published var selectedPackage: Package?
    @Published var includeScheduling = true
    @Published var includeMedia = true
    @Published private(set) var progress: AnkiImportProgress?
    @Published private(set) var errorMessage: String?

    private let storage: Storage
    private var workspace: AnkiTemporaryWorkspace?
    private var securityScopedURL: URL?
    private var hasSecurityScopedAccess = false

    init(storage: Storage) {
        self.storage = storage
    }

    deinit {
        if hasSecurityScopedAccess, let securityScopedURL {
            securityScopedURL.stopAccessingSecurityScopedResource()
        }
        Task {
            await workspace?.cleanup()
        }
    }

    func refreshProfiles() {
        errorMessage = nil
        profiles = discoverProfiles()
    }

    func selectProfile(_ profile: Profile) {
        errorMessage = nil
        selectedPackage = nil

        if hasSecurityScopedAccess, let securityScopedURL {
            securityScopedURL.stopAccessingSecurityScopedResource()
        }
        securityScopedURL = nil
        hasSecurityScopedAccess = false

        selectedProfile = profile
    }

    func selectProfileFolder(_ url: URL, securityScoped: Bool) {
        errorMessage = nil
        selectedPackage = nil

        if hasSecurityScopedAccess, let securityScopedURL {
            securityScopedURL.stopAccessingSecurityScopedResource()
        }

        securityScopedURL = url
        hasSecurityScopedAccess = securityScoped

        selectedProfile = Profile(name: url.lastPathComponent, url: url)
    }

    func selectPackageFile(_ url: URL) {
        errorMessage = nil
        selectedProfile = nil

        if hasSecurityScopedAccess, let securityScopedURL {
            securityScopedURL.stopAccessingSecurityScopedResource()
        }
        securityScopedURL = nil
        hasSecurityScopedAccess = false

        selectedPackage = Package(url: url, filename: url.lastPathComponent)
    }

    func loadPreview() {
        errorMessage = nil
        progress = nil

        guard selectedProfile != nil || selectedPackage != nil else {
            errorMessage = "Choose an Anki profile or package first."
            return
        }

        workspace?.cleanup()
        workspace = nil

        let selectedProfileURL = selectedProfile?.url
        let selectedPackageURL = selectedPackage?.url
        let selectedPackageFilename = selectedPackage?.filename

        Task {
            do {
                let prepared: AnkiTemporaryWorkspace
                if let selectedPackageURL {
                    let hasAccess = selectedPackageURL.startAccessingSecurityScopedResource()
                    defer {
                        if hasAccess {
                            selectedPackageURL.stopAccessingSecurityScopedResource()
                        }
                    }
                    prepared = try AnkiTemporaryWorkspace.fromPackageFile(selectedPackageURL, filename: selectedPackageFilename)
                } else if let selectedProfileURL {
                    prepared = try AnkiTemporaryWorkspace.fromProfileFolder(selectedProfileURL)
                } else {
                    throw AnkiImportError.noSourceSelected
                }

                let details = try AnkiImportEngine.loadPreviewDetails(from: prepared.location)
                let preview = ImportPreview(
                    formatIdentifier: "anki",
                    formatName: "Anki",
                    deckCount: details.deckCount,
                    cardCount: details.cardCount,
                    decks: details.decks,
                    errors: details.errors
                )

                await MainActor.run {
                    workspace = prepared
                    phase = .preview(preview)
                }
            } catch {
                await MainActor.run {
                    workspace?.cleanup()
                    workspace = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func reset() {
        errorMessage = nil
        progress = nil
        phase = .source
        workspace?.cleanup()
        workspace = nil
    }

    func performImport(
        mergePlan: DeckMergePlan,
        onResult: @escaping @MainActor (ImportResult) -> Void
    ) {
        errorMessage = nil
        progress = nil

        guard let workspace else {
            errorMessage = "Select an Anki source before importing."
            return
        }

        let options = AnkiImportOptions(includeScheduling: includeScheduling, includeMedia: includeMedia)
        let location = workspace.location

        phase = .importing
        progress = AnkiImportProgress(phase: .importing, totalDecks: 0, processedDecks: 0)

        Task {
            do {
                let result = try await AnkiImportEngine.performImport(
                    from: location,
                    storage: storage,
                    mergePlan: mergePlan,
                    options: options,
                    progress: { update in
                        Task { @MainActor in
                            self.progress = update
                        }
                    }
                )
                await MainActor.run {
                    onResult(result)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    if case .preview(let preview) = self.phase {
                        self.phase = .preview(preview)
                    } else {
                        self.phase = .source
                    }
                }
            }
        }
    }

    private func discoverProfiles() -> [Profile] {
        let fm = FileManager.default
        let base = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Anki2", isDirectory: true)

        guard let contents = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var results: [Profile] = []
        for url in contents {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let db = url.appendingPathComponent("collection.anki2", isDirectory: false)
            guard fm.fileExists(atPath: db.path) else { continue }
            results.append(Profile(name: url.lastPathComponent, url: url))
        }

        return results.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
