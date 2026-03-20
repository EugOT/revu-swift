import SwiftUI
import UniformTypeIdentifiers

struct AnkiImportFlowView: View {
    @Environment(\.storage) private var storage
    @Environment(\.dismiss) private var dismiss

    let onImported: ((ImportResult) -> Void)?

    @StateObject private var viewModel: AnkiImportFlowViewModel
    @State private var mergeTargets: [DeckMergeTarget] = []
    @State private var mergePlan: DeckMergePlan = .empty
    @State private var showingSummary = false
    @State private var importResult: ImportResult?
    @State private var folderImporterPresented = false
    @State private var packageImporterPresented = false
    @State private var importOverlayState: ImportOperationOverlayState?

    init(storage: Storage = DataController.shared.storage, onImported: ((ImportResult) -> Void)? = nil) {
        self.onImported = onImported
        _viewModel = StateObject(wrappedValue: AnkiImportFlowViewModel(storage: storage))
    }

    var body: some View {
        ZStack {
            background
            content

            if let importOverlayState {
                ImportOperationOverlay(state: importOverlayState)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 780, minHeight: 620)
        .task { await loadMergeTargets() }
        .onAppear { viewModel.refreshProfiles() }
        .onChange(of: viewModel.progress) { _, progress in
            guard let progress else { return }
            guard case .importing = importOverlayState?.phase else { return }
            guard var overlay = importOverlayState else { return }
            overlay.subtitle = progress.totalDecks > 0
                ? "\(progress.processedDecks) of \(progress.totalDecks) decks"
                : "Preparing collection"
            overlay.phase = .importing(progress: progress.totalDecks > 0 ? progress.fraction : nil)
            importOverlayState = overlay
        }
        .onChange(of: viewModel.errorMessage) { _, message in
            guard let message, !message.isEmpty else { return }
            guard case .importing = importOverlayState?.phase else { return }
            withAnimation(DesignSystem.Animation.smooth) {
                importOverlayState = ImportOperationOverlayState(
                    title: "Import failed",
                    subtitle: message,
                    phase: .failure
                )
            }
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                await MainActor.run {
                    withAnimation(DesignSystem.Animation.smooth) {
                        importOverlayState = nil
                    }
                }
            }
        }
        .fileImporter(isPresented: $folderImporterPresented, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            handleProfileFolderResult(result)
        }
        .fileImporter(
            isPresented: $packageImporterPresented,
            allowedContentTypes: packageContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handlePackageFileResult(result)
        }
        .alert("Import Complete", isPresented: $showingSummary, presenting: importResult) { _ in
            Button("Done", role: .cancel) {
                dismiss()
            }
        } message: { result in
            Text(
                "Decks added: \(result.decksInserted) • Decks updated: \(result.decksUpdated)\n" +
                "Cards added: \(result.cardsInserted) • Cards updated: \(result.cardsUpdated) • Skipped: \(result.cardsSkipped)"
            )
        }
    }

    private var background: some View {
        ZStack {
            DesignSystem.Colors.canvasBackground
            Circle()
                .fill(
                    RadialGradient(
                        colors: [DesignSystem.Colors.subtleOverlay, .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
                .frame(width: 420, height: 420)
                .blur(radius: 70)
                .offset(x: -160, y: -80)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .source:
            sourcePicker
        case .preview(let preview):
            ImportPreviewView(
                preview: preview,
                existingDecks: mergeTargets,
                mergePlan: $mergePlan,
                onImport: startImport,
                onCancel: { viewModel.reset() },
                overlayState: nil
            )
        case .importing:
            importingView
        }
    }

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            header

            if let message = viewModel.errorMessage {
                Callout(message, style: .warning, title: "Import issue")
            }

            optionsCard

            profileCard

            packageCard

            Spacer()

            HStack {
                Button("Close") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                Spacer()

                Button {
                    folderImporterPresented = true
                } label: {
                    Label("Choose Profile Folder…", systemImage: "folder")
                        .font(DesignSystem.Typography.bodyMedium)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.hoverBackground)
                )

                Button(action: viewModel.loadPreview) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Preview Import")
                    }
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .fill(DesignSystem.Colors.primaryText)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canPreviewSelection)
                .opacity(canPreviewSelection ? 1.0 : 0.6)
            }
        }
        .padding(DesignSystem.Spacing.xxl)
        .frame(maxWidth: 980, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                        .fill(DesignSystem.Colors.subtleOverlay)
                        .frame(width: 56, height: 56)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Import from Anki")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    Text("Bring your decks, tags, cloze cards, and scheduling into Revu.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                Spacer()
            }
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Import options")
                .font(DesignSystem.Typography.heading)

            Toggle("Include scheduling (due dates, intervals, suspend state)", isOn: $viewModel.includeScheduling)
                .toggleStyle(.switch)
                .tint(DesignSystem.Colors.studyAccentBright)

            Toggle("Include media (images/audio referenced by cards)", isOn: $viewModel.includeMedia)
                .toggleStyle(.switch)
                .tint(DesignSystem.Colors.studyAccentBright)

            Text("You can always re-import later—Revu only updates cards when Anki's modified date is newer.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Anki profiles")
                    .font(DesignSystem.Typography.heading)
                Spacer()
                Button("Refresh") { viewModel.refreshProfiles() }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }

            if viewModel.profiles.isEmpty {
                Text("No profiles found in `~/Library/Application Support/Anki2`. Choose a profile folder or an exported Anki package to continue.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.profiles) { profile in
                        profileRow(profile)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    private func profileRow(_ profile: AnkiImportFlowViewModel.Profile) -> some View {
        let isSelected = viewModel.selectedProfile == profile
        return Button {
            viewModel.selectProfile(profile)
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DesignSystem.Colors.studyAccentBright : DesignSystem.Colors.separator)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    Text(profile.url.path)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.studyAccentBright.opacity(0.08) : DesignSystem.Colors.hoverBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(isSelected ? DesignSystem.Colors.studyAccentBright.opacity(0.35) : DesignSystem.Colors.separator.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var packageCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Anki package")
                    .font(DesignSystem.Typography.heading)
                Spacer()
                Button("Choose .apkg / .colpkg") { packageImporterPresented = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }

            if let package = viewModel.selectedPackage {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(package.filename)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                        Text(package.url.path)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.studyAccentBright.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .stroke(DesignSystem.Colors.studyAccentBright.opacity(0.35), lineWidth: 1)
                )
            } else {
                Text("Use this if you exported an Anki package from another device.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    private var canPreviewSelection: Bool {
        viewModel.selectedProfile != nil || viewModel.selectedPackage != nil
    }

    private var packageContentTypes: [UTType] {
        var types: [UTType] = []
        if let apkg = UTType(filenameExtension: "apkg") {
            types.append(apkg)
        }
        if let colpkg = UTType(filenameExtension: "colpkg") {
            types.append(colpkg)
        }
        return types.isEmpty ? [.data] : types
    }

    private var importingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView(value: viewModel.progress?.fraction ?? 0)
                .progressViewStyle(.linear)
                .tint(DesignSystem.Colors.studyAccentBright)
                .frame(maxWidth: 480)

            VStack(spacing: 6) {
                Text("Importing your Anki decks…")
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                if let progress = viewModel.progress, progress.totalDecks > 0 {
                    Text("\(progress.processedDecks) of \(progress.totalDecks) decks")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                } else {
                    Text("Preparing collection")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
            }

            Text("You can keep working—Revu imports in the background.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
        }
        .padding(DesignSystem.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startImport() {
        withAnimation(DesignSystem.Animation.smooth) {
            importOverlayState = ImportOperationOverlayState(
                title: "Importing from Anki…",
                subtitle: "Preparing collection",
                phase: .importing(progress: nil)
            )
        }
        viewModel.performImport(mergePlan: mergePlan) { result in
            withAnimation(DesignSystem.Animation.smooth) {
                importOverlayState = ImportOperationOverlayState(
                    title: "Import complete",
                    subtitle: "Added \(result.cardsInserted) cards • Updated \(result.cardsUpdated)",
                    phase: .success
                )
            }
            Task {
                try? await Task.sleep(nanoseconds: 650_000_000)
                await MainActor.run {
                    withAnimation(DesignSystem.Animation.smooth) {
                        importOverlayState = nil
                    }
                    importResult = result
                    showingSummary = true
                    onImported?(result)
                }
            }
        }
    }

    private func handleProfileFolderResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            viewModel.selectProfileFolder(url, securityScoped: hasAccess)
        case .failure(let error):
            if let cocoaError = error as? CocoaError, cocoaError.code == .userCancelled {
                return
            }
            // Non-cancellation errors are rare; keep the current selection and let the user retry.
            print("Anki folder selection failed: \(error.localizedDescription)")
        }
    }

    private func handlePackageFileResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            viewModel.selectPackageFile(url)
        case .failure(let error):
            if let cocoaError = error as? CocoaError, cocoaError.code == .userCancelled {
                return
            }
            print("Anki package selection failed: \(error.localizedDescription)")
        }
    }

    private func loadMergeTargets() async {
        let decks = await DeckService(storage: storage).allDecks(includeArchived: true)
        let hierarchy = DeckHierarchy(decks: decks)
        let sorted = decks.sorted { lhs, rhs in
            hierarchy.displayPath(of: lhs.id).localizedCaseInsensitiveCompare(hierarchy.displayPath(of: rhs.id)) == .orderedAscending
        }
        await MainActor.run {
            mergeTargets = sorted.map {
                DeckMergeTarget(
                    id: $0.id,
                    parentId: $0.parentId,
                    name: $0.name,
                    note: $0.note,
                    dueDate: $0.dueDate,
                    isArchived: $0.isArchived
                )
            }
        }
    }
}

#if DEBUG
#Preview("AnkiImportFlowView") {
    RevuPreviewHost { controller in
        AnkiImportFlowView(storage: controller.storage)
            .frame(width: 980, height: 720)
    }
}
#endif
