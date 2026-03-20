import SwiftUI

/// A bento-grid canvas view for browsing the contents of a folder.
/// Shows subfolders, decks, exams, and study guides inside the current folder, with navigation via sidebar selection update.
struct FolderCanvasView: View {
    let folder: Deck
    @Binding var selection: SidebarItem?

    @Environment(\.storage) private var storage
    @EnvironmentObject private var storeEvents: StoreEvents
    @State private var decks: [Deck] = []
    @State private var subfolders: [Deck] = []
    @State private var childDecks: [Deck] = []
    @State private var exams: [Exam] = []
    @State private var studyGuides: [StudyGuide] = []
    @State private var isLoading: Bool = true
    @State private var cardCountsByDeck: [UUID: Int] = [:]
    @State private var isCreatingFolder: Bool = false
    @State private var isCreatingDeck: Bool = false
    @State private var editingDeck: Deck?
    @State private var editingExam: Exam?
    @State private var editingStudyGuide: StudyGuide?
    @State private var deletingItem: (id: UUID, type: String)?
    @State private var folderDirective: StudyDirective?

    @DesignSystemScaledMetric(relativeTo: .title3) private var minTileWidth: CGFloat = 180
    @DesignSystemScaledMetric(relativeTo: .title3) private var maxTileWidth: CGFloat = 280
    @DesignSystemScaledMetric private var gridSpacing: CGFloat = DesignSystem.Spacing.md

    var body: some View {
        ZStack {
            DesignSystem.Colors.window
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                    .overlay(DesignSystem.Colors.separator)

                if isLoading {
                    loadingState
                } else if subfolders.isEmpty && childDecks.isEmpty && exams.isEmpty && studyGuides.isEmpty {
                    emptyState
                } else {
                    gridContent
                }
            }
        }
        .task(id: folder.id) {
            await loadContents()
            folderDirective = await StudyDirectiveEngine().folderDirective(folderId: folder.id)
        }
        .task(id: storeEvents.tick) {
            await loadContents()
        }
        .sheet(isPresented: $isCreatingFolder) {
            DeckEditorView(defaultParentId: folder.id, defaultKind: .folder) { newFolder in
                Task { await handleItemCreated(newFolder) }
            }
        }
        .sheet(isPresented: $isCreatingDeck) {
            DeckEditorView(defaultParentId: folder.id, defaultKind: .deck) { newDeck in
                Task { await handleItemCreated(newDeck) }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "folder.fill")
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(DesignSystem.Colors.accent)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(folder.name)
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text(summaryText)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            // Create actions
            createMenu
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    private var createMenu: some View {
        Menu {
            Button {
                isCreatingDeck = true
            } label: {
                Label("New Deck", systemImage: "rectangle.stack.badge.plus")
            }

            Button {
                isCreatingFolder = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }

            Divider()

            Button {
                Task { await createNewExam() }
            } label: {
                Label("New Exam", systemImage: "doc.questionmark")
            }

            Button {
                Task { await createNewStudyGuide() }
            } label: {
                Label("New Study Guide", systemImage: "doc.richtext")
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "plus")
                    .font(DesignSystem.Typography.captionMedium)
                Text("New")
                    .font(DesignSystem.Typography.bodyMedium)
            }
            .foregroundStyle(DesignSystem.Colors.primaryText)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(DesignSystem.Colors.subtleOverlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.separator.opacity(0.65), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
    }

    private var summaryText: String {
        let folderCount = subfolders.count
        let deckCount = childDecks.count
        let examCount = exams.count
        let guideCount = studyGuides.count

        var parts: [String] = []
        if folderCount > 0 {
            parts.append("\(folderCount) folder\(folderCount == 1 ? "" : "s")")
        }
        if deckCount > 0 {
            parts.append("\(deckCount) deck\(deckCount == 1 ? "" : "s")")
        }
        if examCount > 0 {
            parts.append("\(examCount) exam\(examCount == 1 ? "" : "s")")
        }
        if guideCount > 0 {
            parts.append("\(guideCount) guide\(guideCount == 1 ? "" : "s")")
        }

        return parts.isEmpty ? "Empty folder" : parts.joined(separator: ", ")
    }

    // MARK: - Grid Content

    private var gridContent: some View {
        ScrollView {
            if let folderDirective = folderDirective {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "chart.bar.fill")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)

                    Text(folderDirective.body)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                }
                .padding(DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                        .fill(DesignSystem.Colors.canvasBackground)
                )
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.sm)
            }

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
                // Subfolders first
                ForEach(subfolders) { subfolder in
                    LibraryGridTileView(
                        item: .folder(subfolder),
                        cardCount: nil,
                        onTap: {
                            selection = .folder(subfolder.id)
                        },
                        onRename: {
                            editingDeck = subfolder
                        },
                        onDelete: {
                            deletingItem = (id: subfolder.id, type: "folder")
                        }
                    )
                }

                // Then decks
                ForEach(childDecks) { deck in
                    LibraryGridTileView(
                        item: .deck(deck),
                        cardCount: cardCountsByDeck[deck.id],
                        onTap: {
                            selection = .deck(deck.id)
                        },
                        onRename: {
                            editingDeck = deck
                        },
                        onDelete: {
                            deletingItem = (id: deck.id, type: "deck")
                        }
                    )
                }

                // Exams
                ForEach(exams) { exam in
                    LibraryGridTileView(
                        item: .exam(exam),
                        cardCount: nil,
                        onTap: {
                            selection = .exam(exam.id)
                        },
                        onRename: {
                            editingExam = exam
                        },
                        onDelete: {
                            deletingItem = (id: exam.id, type: "exam")
                        }
                    )
                }

                // Study Guides
                ForEach(studyGuides) { guide in
                    LibraryGridTileView(
                        item: .studyGuide(guide),
                        cardCount: nil,
                        onTap: {
                            selection = .studyGuide(guide.id)
                        },
                        onRename: {
                            editingStudyGuide = guide
                        },
                        onDelete: {
                            deletingItem = (id: guide.id, type: "studyGuide")
                        }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: minTileWidth, maximum: maxTileWidth), spacing: gridSpacing, alignment: .top)]
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "folder.badge.plus")
                .dynamicSystemFont(size: 48, weight: .regular, relativeTo: .largeTitle)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("This folder is empty")
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text("Create a new deck or folder to get started")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Item Creation Handler

    @MainActor
    private func handleItemCreated(_ item: Deck) async {
        // Select the newly created item in the sidebar
        if item.isFolder {
            selection = .folder(item.id)
        } else {
            selection = .deck(item.id)
        }
    }

    @MainActor
    private func createNewExam() async {
        let newExam = Exam(
            parentFolderId: folder.id,
            title: "Untitled Exam",
            config: Exam.Config(),
            questions: []
        )
        do {
            try await storage.upsert(exam: newExam.toDTO())
            selection = .exam(newExam.id)
        } catch {
            // Error creating exam - could show toast in future
        }
    }

    @MainActor
    private func createNewStudyGuide() async {
        let newGuide = StudyGuide(
            parentFolderId: folder.id,
            title: "Untitled Study Guide",
            markdownContent: ""
        )
        do {
            try await storage.upsert(studyGuide: newGuide.toDTO())
            selection = .studyGuide(newGuide.id)
        } catch {
            // Error creating study guide - could show toast in future
        }
    }

    // MARK: - Data Loading

    private func loadContents() async {
        do {
            let allDeckDTOs = try await storage.allDecks()
            let allDecks = allDeckDTOs.map { $0.toDomain() }

            // Filter to children of current folder
            let children = allDecks.filter { $0.parentId == folder.id && !$0.isArchived }

            // Separate folders and decks
            let folders = children.filter { $0.isFolder }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let decks = children.filter { !$0.isFolder }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            // Load card counts for decks
            var counts: [UUID: Int] = [:]
            for deck in decks {
                let cards = try await storage.cards(deckId: deck.id)
                counts[deck.id] = cards.count
            }

            // Load exams for this folder
            let allExamDTOs = try await storage.allExams()
            let folderExams = allExamDTOs
                .map { $0.toDomain() }
                .filter { $0.parentFolderId == folder.id }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            // Load study guides for this folder
            let allGuideDTOs = try await storage.allStudyGuides()
            let folderGuides = allGuideDTOs
                .map { $0.toDomain() }
                .filter { $0.parentFolderId == folder.id }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            await MainActor.run {
                self.decks = allDecks
                self.subfolders = folders
                self.childDecks = decks
                self.cardCountsByDeck = counts
                self.exams = folderExams
                self.studyGuides = folderGuides
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
