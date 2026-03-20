import SwiftUI

private struct SidebarMoveDeckRequest: Identifiable, Equatable {
    let id: UUID
    let isArchivedSection: Bool
}

private struct SidebarPendingMerge: Identifiable {
    let source: Deck
    let target: Deck
    var id: String { "\(source.id)-\(target.id)" }
}

struct SidebarView: View {
    enum DisplayMode: Sendable {
        case expanded
        case compact
    }

    @Binding var selection: SidebarItem?
    var displayMode: DisplayMode = .expanded
    var selectedDeck: Deck?
    var onNewDeck: () -> Void
    var onNewFolder: () -> Void
    var onNewExam: () -> Void
    var onNewStudyGuide: () -> Void
    var onNewCourse: () -> Void
    var onNewSubdeck: (Deck) -> Void
    var onMoveDeck: (Deck, UUID?) -> Void
    var onRenameDeck: (Deck) -> Void
    var onDeleteDeck: () -> Void
    var onArchiveDeck: (Deck) -> Void
    var onUnarchiveDeck: (Deck) -> Void
    var onExportDeck: (Deck) -> Void
    var onMergeDecks: (Deck, Deck) -> Void
    var onDeckOrderChange: ([UUID]) -> Void
    var onImport: () -> Void
    var onExport: () -> Void
    var onDeleteExam: ((Exam) -> Void)?
    var onDeleteStudyGuide: ((StudyGuide) -> Void)?
    var onDeleteCourse: ((Course) -> Void)?
    var onEditCourse: ((Course) -> Void)?

    @Environment(\.storage) private var storage
    @EnvironmentObject private var storeEvents: StoreEvents
    @State private var decks: [Deck] = []
    @State private var archivedDecks: [Deck] = []
    @State private var exams: [Exam] = []
    @State private var studyGuides: [StudyGuide] = []
    @State private var courses: [Course] = []
    @State private var tags: [String] = []
    @State private var deckSnapshots: [UUID: DeckSnapshot] = [:]
    @State private var sessionSnapshot: SessionCuratorSnapshot = .empty
    @State private var navigatorSnapshot: AdaptiveNavigatorSnapshot = .empty
    @State private var settings: UserSettings = UserSettings()
    @AppStorage("sidebar.coursesExpanded") private var coursesExpanded = true
    @AppStorage("sidebar.decksExpanded") private var decksExpanded = true
    @AppStorage("sidebar.learningExpanded") private var learningExpanded = true
    @AppStorage("sidebar.tagsExpanded") private var tagsExpanded = false
    @AppStorage("sidebar.archivedExpanded") private var archivedExpanded = false
    @AppStorage("sidebar.collapsedDeckIDs") private var collapsedDeckIDsRaw = ""
    @State private var rowHeights: [UUID: CGFloat] = [:]
    @State private var todayReviewCount: Int = 0
    @State private var moveDeckRequest: SidebarMoveDeckRequest?
    @State private var deckSortMode: DeckSortMode = .nameAscending
    @State private var isSortMenuHovered: Bool = false
    
    private var courseColorMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: courses.compactMap { course in
            guard let hex = course.colorHex else { return nil }
            return (course.id, hex)
        })
    }

    // Drag-drop visual feedback state
    @State private var dropTargetDeckId: UUID?
    @State private var isDropTargeted: Bool = false
    @State private var pendingMerge: SidebarPendingMerge?

    var body: some View {
        VStack(spacing: 0) {
            if displayMode == .expanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    learningIntelligenceSection
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.xs)
                .padding(.bottom, DesignSystem.Spacing.sm)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    switch displayMode {
                    case .expanded:
                        coursesSection
                        decksSection
                        if !archivedDecks.isEmpty {
                            archivedDecksSection
                        }
                        if !tags.isEmpty {
                            tagsSection
                        }

                        Divider()
                            .overlay(DesignSystem.Colors.separator.opacity(0.6))
                            .padding(.vertical, DesignSystem.Spacing.xs)

                        utilitiesSection
                    case .compact:
                        compactDecksSection
                    }
                }
                .padding(.horizontal, displayMode == .compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md)
                .padding(.vertical, displayMode == .compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md)
            }
            .scrollIndicators(.hidden)
        }
        .background(DesignSystem.Colors.sidebarBackground)
        .sheet(item: $moveDeckRequest) { request in
            if let deck = deck(for: request.id) {
                SidebarMoveDeckSheet(
                    deck: deck,
                    sectionDecks: request.isArchivedSection ? archivedDecks : decks,
                    onMove: { parentId in
                        onMoveDeck(deck, parentId)
                    }
                )
            } else {
                Text("That deck is no longer available.")
                    .padding()
            }
        }
        .task(id: storeEvents.tick) { await refreshData() }
        .animation(DesignSystem.Animation.layout, value: decksExpanded)
        .animation(DesignSystem.Animation.layout, value: learningExpanded)
        .animation(DesignSystem.Animation.layout, value: tagsExpanded)
        .confirmationDialog(
            "Merge Decks",
            isPresented: Binding(
                get: { pendingMerge != nil },
                set: { if !$0 { pendingMerge = nil } }
            ),
            presenting: pendingMerge
        ) { merge in
            Button("Merge \"\(merge.source.name)\" into \"\(merge.target.name)\"", role: .destructive) {
                onMergeDecks(merge.source, merge.target)
                pendingMerge = nil
            }
            Button("Cancel", role: .cancel) {
                pendingMerge = nil
            }
        } message: { merge in
            Text("All cards from \"\(merge.source.name)\" will be moved to \"\(merge.target.name)\". The source deck will be deleted. This cannot be undone.")
        }
    }
}

private extension SidebarView {
    var sortPicker: some View {
        Menu {
            ForEach(DeckSortMode.allCases.filter { $0 != .manual }, id: \.self) { mode in
                Button {
                    updateSortMode(mode)
                } label: {
                    HStack {
                        Text(mode.displayName)
                        if deckSortMode == mode || (deckSortMode == .manual && mode == .nameAscending) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: sortModeIcon)
                    .font(DesignSystem.Typography.smallMedium)
                    .frame(width: 20)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sort")
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    Text(sortModeLabel)
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: DesignSystem.Spacing.sm)

                Image(systemName: "chevron.down")
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(isSortMenuHovered ? DesignSystem.Colors.hoverBackground : DesignSystem.Colors.subtleOverlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.separator.opacity(0.65), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .help("Sort decks in the sidebar")
        .onHover { hovering in
            isSortMenuHovered = hovering
        }
    }

    var sortModeIcon: String {
        switch deckSortMode {
        case .manual:
            return "textformat.abc"
        case .nameAscending, .nameDescending:
            return "textformat.abc"
        case .dateModifiedNewest, .dateModifiedOldest:
            return "clock"
        case .dateCreatedNewest, .dateCreatedOldest:
            return "calendar"
        }
    }

    var sortModeLabel: String {
        switch deckSortMode {
        case .manual:
            return "Name (A-Z)"
        case .nameAscending:
            return "Name (A-Z)"
        case .nameDescending:
            return "Name (Z-A)"
        case .dateModifiedNewest:
            return "Modified (Newest)"
        case .dateModifiedOldest:
            return "Modified (Oldest)"
        case .dateCreatedNewest:
            return "Created (Newest)"
        case .dateCreatedOldest:
            return "Created (Oldest)"
        }
    }

    func updateSortMode(_ mode: DeckSortMode) {
        deckSortMode = mode == .manual ? .nameAscending : mode
        Task {
            let currentSettings = try? await storage.loadSettings()
            let updatedSettings = (currentSettings?.toDomain() ?? UserSettings())
            var newSettings = updatedSettings
            newSettings.deckSortMode = mode == .manual ? .nameAscending : mode
            try? await storage.save(settings: newSettings.toDTO())
            await refreshData()
        }
    }

    var learningIntelligenceSection: some View {
        CollapsibleSidebarSection(
            title: "Dashboard",
            icon: "brain.head.profile",
            isExpanded: $learningExpanded
        ) {
            VStack(spacing: DesignSystem.Spacing.md) {
                FocusDashboardView(
                    session: currentFocusSession,
                    onContinueLearning: {
                        withAnimation(DesignSystem.Animation.quick) {
                            selection = .learningIntelligence
                        }
                    },
                    onQuickImport: {
                        onImport()
                    }
                )
            }
        }
    }

    var coursesSection: some View {
        CollapsibleSidebarSection(
            title: "Courses",
            icon: "book.closed",
            isExpanded: $coursesExpanded,
            trailingButton: {
                Button {
                    onNewCourse()
                } label: {
                    Image(systemName: "plus")
                        .font(DesignSystem.Typography.captionMedium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Create new course")
            }
        ) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                if courses.isEmpty {
                    sidebarPlaceholder(message: "No courses yet. Create one to organize your study materials.")
                } else {
                    ForEach(courses) { course in
                        courseRow(course: course)
                    }
                }
            }
        }
    }

    func courseRow(course: Course) -> some View {
        let isSelected = selection == .course(course.id)
        let examCountdown: String? = {
            guard let examDate = course.examDate else { return nil }
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: examDate)).day ?? 0
            if days < 0 { return "Past due" }
            if days == 0 { return "Today" }
            return "\(days)d"
        }()

        return Button {
            withAnimation(DesignSystem.Animation.quick) {
                selection = .course(course.id)
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Circle()
                    .fill(Color(hex: course.colorHex ?? "#6366F1"))
                    .frame(width: 8, height: 8)

                Text(course.name)
                    .font(isSelected ? DesignSystem.Typography.bodyMedium : DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                Spacer(minLength: DesignSystem.Spacing.sm)

                if let countdown = examCountdown {
                    Text(countdown)
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.subtleOverlay)
                        )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(isSelected ? DesignSystem.Colors.selectedBackground.opacity(0.38) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(
                    isSelected ? DesignSystem.Colors.separator.opacity(0.6) : Color.clear,
                    lineWidth: isSelected ? 1 : 0
                )
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(DesignSystem.Colors.studyAccentMid.opacity(0.8))
                .frame(width: 2)
                .padding(.vertical, 7)
                .padding(.leading, 4)
                .opacity(isSelected ? 1 : 0)
        }
        .designSystemContextMenu {
            ContextMenuItem(icon: "pencil", label: "Edit Course") {
                withAnimation(DesignSystem.Animation.quick) {
                    selection = .course(course.id)
                }
                onEditCourse?(course)
            }

            ContextMenuDivider()

            ContextMenuItem(icon: "trash", label: "Delete Course", isDestructive: true) {
                onDeleteCourse?(course)
            }
        }
    }

    // MARK: - Data Mapping

    private var currentFocusSession: FocusSession? {
        let session = sessionSnapshot
        
        // Priority 1: Active Queue Preview
        if let preview = session.queuePreview.first {
            return FocusSession(
                deckName: "Smart Review", // Queue items are mixed, so we use a generic title
                dueCount: session.totalDue,
                nextConcept: preview.concept,
                color: emphasisColor(preview.emphasis)
            )
        }
        
        // Priority 2: Suggested Deck (High priority deck)
        if let candidate = suggestedDeck {
            return FocusSession(
                deckName: candidate.deck.name,
                dueCount: candidate.snapshot.dueTotal,
                nextConcept: "Ready to study",
                color: deckEnergy(for: candidate.deck).map(energyColor) ?? DesignSystem.Colors.accent
            )
        }
        
        // Priority 3: Show "All Caught Up" (nil session)
        return nil
    }

    private func calculateDailyProgress() -> Double {
        let target = settings.dailyReviewLimit
        guard target > 0 else {
            return 1.0
        }
        let progress = Double(todayReviewCount) / Double(target)
        return min(max(progress, 0.0), 1.0)
    }

    private var continueSessionPreview: SessionPreview? {
        if let preview = sessionSnapshot.queuePreview.first {
            return SessionPreview(
                deckName: "Smart Review",
                concept: preview.concept,
                dueString: dueDescription(for: preview.dueInHours)
            )
        }

        if let candidate = suggestedDeck {
            let dueLabel: String
            if candidate.snapshot.dueTotal > 0 {
                dueLabel = candidate.snapshot.dueTotal == 1 ? "1 card due" : "\(candidate.snapshot.dueTotal) due"
            } else {
                dueLabel = "On track"
            }

            let conceptLabel: String
            if candidate.snapshot.new > 0 {
                conceptLabel = "\(candidate.snapshot.new) new waiting"
            } else {
                conceptLabel = "Ready to study"
            }

            return SessionPreview(
                deckName: candidate.deck.name,
                concept: conceptLabel,
                dueString: dueLabel
            )
        }

        return nil
    }



    var suggestedDeck: (deck: Deck, snapshot: DeckSnapshot)? {
        decksWithSnapshots.max(by: { lhs, rhs in lhs.snapshot.dueTotal < rhs.snapshot.dueTotal })
            .flatMap { $0.snapshot.dueTotal > 0 ? $0 : nil }
    }

    func nextReviewPreview(_ preview: SessionCuratorSnapshot.QueuePreview) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text(preview.concept)
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.subtleOverlay)
                    )
                
                Spacer()
                
                if preview.dueInHours <= 0 {
                    Text("now")
                        .font(DesignSystem.Typography.small)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
            }

            Text(preview.prompt)
                .font(DesignSystem.Typography.small)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    func deckSuggestion(_ candidate: (deck: Deck, snapshot: DeckSnapshot)) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.deck.name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)
                Text("Ready to study")
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            
            Spacer()
            
            Image(systemName: "arrow.right")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
        }
    }

    func intelligentInsight(_ insight: SessionCuratorSnapshot.Insight) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: insight.symbol)
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            
            Text(insight.title)
                .font(DesignSystem.Typography.small)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .lineLimit(2)
        }
    }

    func learningNavigatorTitle(session: SessionCuratorSnapshot, navigator: AdaptiveNavigatorSnapshot) -> String {
        if session.totalDue == 0 && navigator.totalConcepts == 0 {
            return "Get started"
        }
        if session.totalDue == 0 {
            return "All clear"
        }
        if session.conceptCoverage > 0 {
            return "Continue learning"
        }
        return "Ready to study"
    }

    var decksWithSnapshots: [(deck: Deck, snapshot: DeckSnapshot)] {
        decks.compactMap { deck in
            guard let snapshot = deckSnapshots[deck.id] else { return nil }
            return (deck, snapshot)
        }
    }

    func conceptChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(DesignSystem.Typography.smallMedium)
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.subtleOverlay)
            )
    }

    func capsuleIcon(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(DesignSystem.Typography.captionMedium)
            .foregroundStyle(tint)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .fill(DesignSystem.Colors.subtleOverlay)
            )
    }

    @ViewBuilder
    func sidebarCardBackground(accent: SessionCuratorSnapshot.QueuePreview.Emphasis) -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
            .fill(DesignSystem.Colors.window)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.borderOverlay, lineWidth: 1)
            )
    }

    func emphasis(for energy: AdaptiveNavigatorSnapshot.Energy?) -> SessionCuratorSnapshot.QueuePreview.Emphasis {
        switch energy {
        case .focus?: return .focus
        case .calibrate?: return .contrast
        case .accelerate?: return .reinforce
        case .none: return .reinforce
        }
    }

    func accentGradient(for emphasis: SessionCuratorSnapshot.QueuePreview.Emphasis) -> LinearGradient {
        switch emphasis {
        case .focus:
            return LinearGradient(
                colors: [
                    DesignSystem.Colors.studyAccentDeep.opacity(0.58),
                    DesignSystem.Colors.studyAccentMid.opacity(0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .contrast:
            return LinearGradient(
                colors: [
                    DesignSystem.Colors.studyAccentMid.opacity(0.52),
                    DesignSystem.Colors.studyAccentBright.opacity(0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .reinforce:
            return LinearGradient(
                colors: [
                    DesignSystem.Colors.studyAccentMid.opacity(0.46),
                    DesignSystem.Colors.studyAccentBright.opacity(0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    func emphasisColor(_ emphasis: SessionCuratorSnapshot.QueuePreview.Emphasis) -> Color {
        switch emphasis {
        case .focus: return DesignSystem.Colors.studyAccentMid
        case .contrast: return DesignSystem.Colors.studyAccentBright
        case .reinforce: return DesignSystem.Colors.studyAccentDeep
        }
    }

    func energyColor(for energy: AdaptiveNavigatorSnapshot.Energy) -> Color {
        switch energy {
        case .focus: return DesignSystem.Colors.secondaryText
        case .calibrate: return DesignSystem.Colors.tertiaryText
        case .accelerate: return DesignSystem.Colors.primaryText.opacity(0.75)
        }
    }

    func percentString(_ value: Double) -> String {
        let clamped = min(max(value, 0), 1)
        return NumberFormatter.sidebarPercent.string(from: NSNumber(value: clamped)) ?? "—"
    }

    func urgencyPill(_ value: Int, tint: Color) -> some View {
        Text("\(value)")
            .font(DesignSystem.Typography.smallMedium)
            .foregroundStyle(tint)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.11))
            )
    }

    @ViewBuilder
    func deckUrgencyBadges(snapshot: DeckSnapshot, isArchived: Bool) -> some View {
        let showsSoon = snapshot.dueTotal == 0 && snapshot.dueSoon > 0
        if snapshot.overdue > 0 || snapshot.dueToday > 0 || showsSoon || snapshot.new > 0 {
            HStack(spacing: 6) {
                if snapshot.overdue > 0 {
                    urgencyPill(snapshot.overdue, tint: DesignSystem.Colors.feedbackWarning)
                }
                if snapshot.dueToday > 0 {
                    urgencyPill(snapshot.dueToday, tint: DesignSystem.Colors.secondaryText)
                } else if showsSoon {
                    urgencyPill(snapshot.dueSoon, tint: DesignSystem.Colors.tertiaryText)
                }
                if snapshot.new > 0 {
                    urgencyPill(snapshot.new, tint: DesignSystem.Colors.tertiaryText)
                }
            }
            .opacity(isArchived ? 0.4 : 1)
        }
    }

    func dueDescription(for hours: Double) -> String {
        if hours <= 0.25 { return "due now" }
        if hours < 24 { return "in \(Int(round(hours)))h" }
        let days = Int(round(hours / 24))
        return "in \(days)d"
    }

    var collapsedDeckIDs: Set<UUID> {
        get {
            Set(
                collapsedDeckIDsRaw
                    .split(separator: "\n")
                    .compactMap { UUID(uuidString: String($0)) }
            )
        }
        nonmutating set {
            let lines = newValue
                .map(\.uuidString)
                .sorted()
                .joined(separator: "\n")
            collapsedDeckIDsRaw = lines
        }
    }

    func isDeckExpanded(_ deckId: UUID) -> Bool {
        !collapsedDeckIDs.contains(deckId)
    }

    func toggleDeckExpanded(_ deckId: UUID) {
        var set = collapsedDeckIDs
        if set.contains(deckId) {
            set.remove(deckId)
        } else {
            set.insert(deckId)
        }
        collapsedDeckIDs = set
    }

    private enum DeckThreading {
        static let indentUnit: CGFloat = 14
        static let lineWidth: CGFloat = 1
        static let horizontalInset: CGFloat = 2
    }

    private struct DeckThreadInfo: Equatable {
        let depth: Int
        let ancestorHasNextSibling: [Bool]
        let hasNextSibling: Bool
    }

    private struct DeckThreadGutter: View {
        let info: DeckThreadInfo
        let color: Color

        var body: some View {
            if info.depth <= 0 {
                EmptyView()
            } else {
                HStack(spacing: 0) {
                    if info.depth > 1 {
                        ForEach(0..<(info.depth - 1), id: \.self) { index in
                            DeckThreadColumnShape(
                                mode: info.ancestorHasNextSibling[index] ? .continuation : .empty
                            )
                            .stroke(
                                color,
                                style: StrokeStyle(
                                    lineWidth: DeckThreading.lineWidth,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                            .frame(width: DeckThreading.indentUnit)
                        }
                    }

                    DeckThreadColumnShape(
                        mode: .connector(hasNextSibling: info.hasNextSibling)
                    )
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: DeckThreading.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: DeckThreading.indentUnit)
                }
                .accessibilityHidden(true)
            }
        }
    }

    private struct DeckThreadColumnShape: Shape {
        enum Mode: Equatable {
            case empty
            case continuation
            case connector(hasNextSibling: Bool)
        }

        let mode: Mode

        func path(in rect: CGRect) -> Path {
            var path = Path()

            switch mode {
            case .empty:
                return path
            case .continuation:
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                return path
            case .connector(let hasNextSibling):
                let midX = rect.midX
                let midY = rect.midY

                path.move(to: CGPoint(x: midX, y: rect.minY))
                path.addLine(to: CGPoint(x: midX, y: midY))

                if hasNextSibling {
                    path.move(to: CGPoint(x: midX, y: midY))
                    path.addLine(to: CGPoint(x: midX, y: rect.maxY))
                }

                path.move(to: CGPoint(x: midX, y: midY))
                path.addLine(to: CGPoint(x: rect.maxX - DeckThreading.horizontalInset, y: midY))
                return path
            }
        }
    }

    func deckTree(decks: [Deck], archived: Bool) -> some View {
        enum SidebarTreeEntry: Identifiable {
            case deck(Deck)
            case exam(Exam)
            case studyGuide(StudyGuide)

            var id: String {
                switch self {
                case .deck(let deck):
                    return "deck-\(deck.id.uuidString)"
                case .exam(let exam):
                    return "exam-\(exam.id.uuidString)"
                case .studyGuide(let guide):
                    return "study-guide-\(guide.id.uuidString)"
                }
            }

            var title: String {
                switch self {
                case .deck(let deck):
                    return deck.name
                case .exam(let exam):
                    return exam.title
                case .studyGuide(let guide):
                    return guide.title
                }
            }

            var createdAt: Date {
                switch self {
                case .deck(let deck):
                    return deck.createdAt
                case .exam(let exam):
                    return exam.createdAt
                case .studyGuide(let guide):
                    return guide.createdAt
                }
            }

            var updatedAt: Date {
                switch self {
                case .deck(let deck):
                    return deck.updatedAt
                case .exam(let exam):
                    return exam.updatedAt
                case .studyGuide(let guide):
                    return guide.updatedAt
                }
            }
        }

        let ids = Set(decks.map(\.id))
        let groupedDecks: [UUID?: [Deck]] = Dictionary(grouping: decks) { deck -> UUID? in
            guard let parentId = deck.parentId, ids.contains(parentId) else { return nil }
            return parentId
        }
        let groupedExams: [UUID?: [Exam]] = Dictionary(grouping: exams.filter { exam in
            if let parentId = exam.parentFolderId {
                return ids.contains(parentId)
            }
            return !archived
        }) { exam -> UUID? in
            guard let parentId = exam.parentFolderId, ids.contains(parentId) else { return nil }
            return parentId
        }
        let groupedGuides: [UUID?: [StudyGuide]] = Dictionary(grouping: studyGuides.filter { guide in
            if let parentId = guide.parentFolderId {
                return ids.contains(parentId)
            }
            return !archived
        }) { guide -> UUID? in
            guard let parentId = guide.parentFolderId, ids.contains(parentId) else { return nil }
            return parentId
        }

        func orderedChildren(parentId: UUID?) -> [SidebarTreeEntry] {
            let siblingEntries: [SidebarTreeEntry] =
                (groupedDecks[parentId] ?? []).map(SidebarTreeEntry.deck) +
                (groupedExams[parentId] ?? []).map(SidebarTreeEntry.exam) +
                (groupedGuides[parentId] ?? []).map(SidebarTreeEntry.studyGuide)
            let effectiveMode = deckSortMode == .manual ? DeckSortMode.nameAscending : deckSortMode

            return siblingEntries.sorted { lhs, rhs in
                switch effectiveMode {
                case .nameAscending:
                    let name = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                    if name != .orderedSame { return name == .orderedAscending }
                case .nameDescending:
                    let name = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                    if name != .orderedSame { return name == .orderedDescending }
                case .dateModifiedNewest:
                    if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                case .dateModifiedOldest:
                    if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
                case .dateCreatedNewest:
                    if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                case .dateCreatedOldest:
                    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                case .manual:
                    break
                }

                let name = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if name != .orderedSame { return name == .orderedAscending }
                return lhs.id < rhs.id
            }
        }

        func fileRow(
            title: String,
            item: SidebarItem,
            iconName: String,
            iconColor: Color,
            threadInfo: DeckThreadInfo,
            courseColorHex: String? = nil
        ) -> some View {
            let isSelected = selection == item

            return HStack(spacing: 0) {
                DeckThreadGutter(info: threadInfo, color: DesignSystem.Colors.separator.opacity(0.45))
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Color.clear
                        .frame(width: 16, height: 16)
                    Image(systemName: iconName)
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(iconColor)
                        .frame(width: 12, height: 12)
                    Text(title)
                        .font(isSelected ? DesignSystem.Typography.bodyMedium : DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .lineLimit(1)
                    if let hex = courseColorHex {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 6, height: 6)
                    }
                    Spacer(minLength: DesignSystem.Spacing.sm)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(isSelected ? DesignSystem.Colors.selectedBackground.opacity(0.42) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .stroke(isSelected ? DesignSystem.Colors.separator.opacity(0.66) : Color.clear, lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(DesignSystem.Colors.studyAccentMid.opacity(0.8))
                        .frame(width: 2)
                        .padding(.vertical, 6)
                        .padding(.leading, 4)
                        .opacity(isSelected ? 1 : 0)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(DesignSystem.Animation.quick) {
                        selection = item
                    }
                }
            }
        }

        func render(entry: SidebarTreeEntry, depth: Int, ancestorHasNextSibling: [Bool], hasNextSibling: Bool) -> AnyView {
            return AnyView(
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    switch entry {
                    case .deck(let deck):
                        let children = orderedChildren(parentId: deck.id)
                        let hasChildren = !children.isEmpty
                        let expanded = !hasChildren ? false : isDeckExpanded(deck.id)
                        deckRow(
                            deck: deck,
                            isArchived: archived,
                            threadInfo: DeckThreadInfo(
                                depth: depth,
                                ancestorHasNextSibling: ancestorHasNextSibling,
                                hasNextSibling: hasNextSibling
                            ),
                            hasChildren: hasChildren,
                            isExpanded: expanded
                        )
                        if hasChildren && expanded {
                            let nextAncestorHasNextSibling = ancestorHasNextSibling + [hasNextSibling]
                            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                                render(
                                    entry: child,
                                    depth: depth + 1,
                                    ancestorHasNextSibling: nextAncestorHasNextSibling,
                                    hasNextSibling: index < (children.count - 1)
                                )
                            }
                        }
                    case .exam(let exam):
                        fileRow(
                            title: exam.title,
                            item: .exam(exam.id),
                            iconName: "doc.questionmark",
                            iconColor: DesignSystem.Colors.secondaryText,
                            threadInfo: DeckThreadInfo(
                                depth: depth,
                                ancestorHasNextSibling: ancestorHasNextSibling,
                                hasNextSibling: hasNextSibling
                            ),
                            courseColorHex: exam.courseId.flatMap { courseColorMap[$0] }
                        )
                        .designSystemContextMenu {
                            ContextMenuItem(icon: "pencil", label: "Edit Exam") {
                                withAnimation(DesignSystem.Animation.quick) {
                                    selection = .exam(exam.id)
                                }
                            }

                            ContextMenuDivider()

                            ContextMenuItem(icon: "trash", label: "Delete Exam", isDestructive: true) {
                                onDeleteExam?(exam)
                            }
                        }
                    case .studyGuide(let guide):
                        fileRow(
                            title: guide.title,
                            item: .studyGuide(guide.id),
                            iconName: "doc.richtext",
                            iconColor: DesignSystem.Colors.secondaryText,
                            threadInfo: DeckThreadInfo(
                                depth: depth,
                                ancestorHasNextSibling: ancestorHasNextSibling,
                                hasNextSibling: hasNextSibling
                            ),
                            courseColorHex: guide.courseId.flatMap { courseColorMap[$0] }
                        )
                        .designSystemContextMenu {
                            ContextMenuItem(icon: "pencil", label: "Edit Study Guide") {
                                withAnimation(DesignSystem.Animation.quick) {
                                    selection = .studyGuide(guide.id)
                                }
                            }

                            ContextMenuDivider()

                            ContextMenuItem(icon: "trash", label: "Delete Study Guide", isDestructive: true) {
                                onDeleteStudyGuide?(guide)
                            }
                        }
                    }
                }
            )
        }

        return VStack(spacing: DesignSystem.Spacing.xs) {
            let roots = orderedChildren(parentId: nil)
            ForEach(Array(roots.enumerated()), id: \.element.id) { index, entry in
                render(
                    entry: entry,
                    depth: 0,
                    ancestorHasNextSibling: [],
                    hasNextSibling: index < (roots.count - 1)
                )
            }
        }
    }

    var decksSection: some View {
        CollapsibleSidebarSection(
            title: "Decks",
            icon: "rectangle.grid.2x2",
            isExpanded: $decksExpanded,
            trailingButton: {
                Menu {
                    Button {
                        onNewDeck()
                    } label: {
                        Label("New Deck", systemImage: "rectangle.stack.badge.plus")
                    }
                    
                    Button {
                        onNewFolder()
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    
                    Divider()
                    
                    Button {
                        onNewExam()
                    } label: {
                        Label("New Exam", systemImage: "doc.questionmark")
                    }
                    
                    Button {
                        onNewStudyGuide()
                    } label: {
                        Label("New Study Guide", systemImage: "doc.richtext")
                    }

                    Divider()

                    Button {
                        onImport()
                    } label: {
                        Label("Import Material...", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("i", modifiers: .command)
                } label: {
                    Image(systemName: "plus")
                        .font(DesignSystem.Typography.captionMedium)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Create new item")
            }
        ) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                sortPicker

                if decks.isEmpty {
                    sidebarPlaceholder(message: "No decks yet. Import or create one to get started.")
                } else {
                    deckTree(decks: decks, archived: false)
                }
            }
        }
        .dropDestination(for: DeckDragPayload.self) { items, _ in
            _ = handleDropIntoActiveSection(items: items)
            return true
        }
    }

    var compactDecksSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                sectionLabel("Decks")
                Spacer(minLength: DesignSystem.Spacing.sm)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)

            if decks.isEmpty {
                sidebarPlaceholder(message: "No decks yet.")
            } else {
                deckTree(decks: decks, archived: false)
            }

            Button(action: onNewDeck) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "plus")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .frame(width: 20)
                    Text("New Deck")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Create a new deck")
        }
        .dropDestination(for: DeckDragPayload.self) { items, _ in
            _ = handleDropIntoActiveSection(items: items)
            return true
        }
    }

    var archivedDecksSection: some View {
        CollapsibleSidebarSection(
            title: "Archived",
            icon: "archivebox",
            isExpanded: $archivedExpanded
        ) {
            deckTree(decks: archivedDecks, archived: true)
        }
        .dropDestination(for: DeckDragPayload.self) { items, _ in
            _ = handleDropIntoArchivedSection(items: items)
            return true
        }
    }

    var tagsSection: some View {
        CollapsibleSidebarSection(
            title: "Tags",
            icon: "tag",
            isExpanded: $tagsExpanded
        ) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    sidebarRow(
                        item: .tag(tag),
                        title: "#\(tag)",
                        subtitle: nil,
                        icon: "number",
                        badge: nil
                    )
                }
            }
        }
    }

    var utilitiesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                utilityButton(
                    icon: "square.and.arrow.down",
                    title: "Import Decks…",
                    action: onImport,
                    help: "Import from Revu JSON, spreadsheets (CSV/TSV), or Markdown blocks."
                )
                
                utilityButton(
                    icon: "square.and.arrow.up",
                    title: "Export Decks…",
                    action: onExport,
                    help: "Export your workspace decks as JSON, CSV, or Markdown."
                )
                
                sidebarRow(
                    item: .stats,
                    title: "Stats",
                    subtitle: nil,
                    icon: "chart.bar",
                    badge: nil
                )
                sidebarRow(
                    item: .settings,
                    title: "Settings",
                    subtitle: nil,
                    icon: "gearshape",
                    badge: nil
                )
            }
        }
    }
    
    func utilityButton(icon: String, title: String, action: @escaping () -> Void, help: String) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.captionMedium)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(Color.clear)
        )
    }

    @ViewBuilder
    private func deckRow(deck: Deck, isArchived: Bool, threadInfo: DeckThreadInfo, hasChildren: Bool, isExpanded: Bool) -> some View {
        let snapshot = deckSnapshots[deck.id] ?? DeckSnapshot()
        let mastery = deckMastery(for: deck)
        let sidebarItem: SidebarItem = deck.isFolder ? .folder(deck.id) : .deck(deck.id)
        let isSelected = selection == sidebarItem
        let energy = deckEnergy(for: deck)
        let nameColor = isArchived ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.primaryText
        let badgeOpacity = isArchived ? 0.4 : 1.0
        let threadColor = DesignSystem.Colors.separator.opacity(isArchived ? 0.25 : 0.45)

        Group {
            switch displayMode {
            case .expanded:
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: 0) {
                        DeckThreadGutter(info: threadInfo, color: threadColor)

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            if hasChildren {
                                Button {
                                    withAnimation(DesignSystem.Animation.quick) {
                                        toggleDeckExpanded(deck.id)
                                    }
                                } label: {
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .font(DesignSystem.Typography.smallMedium)
                                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                        .frame(width: 16, height: 16)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear
                                    .frame(width: 16, height: 16)
                            }

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    if deck.isFolder {
                                        Image(systemName: "folder.fill")
                                            .font(DesignSystem.Typography.captionMedium)
                                            .foregroundStyle(DesignSystem.Colors.secondaryText.opacity(isArchived ? 0.55 : 0.9))
                                            .frame(width: 12, height: 12)
                                    } else if let energy {
                                        Circle()
                                            .fill(energyColor(for: energy).opacity(isArchived ? 0.45 : 0.9))
                                            .frame(width: 8, height: 8)
                                    } else {
                                        Circle()
                                            .fill(DesignSystem.Colors.subtleOverlay.opacity(badgeOpacity))
                                            .frame(width: 8, height: 8)
                                    }

                                    Text(deck.name)
                                        .font(isSelected ? DesignSystem.Typography.bodyMedium : DesignSystem.Typography.body)
                                        .foregroundStyle(nameColor)
                                        .lineLimit(1)

                                    if let cid = deck.courseId, let hex = courseColorMap[cid] {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 6, height: 6)
                                    }

                                    Spacer(minLength: DesignSystem.Spacing.sm)

                                    deckUrgencyBadges(snapshot: snapshot, isArchived: isArchived)
                                }

                                if let note = deck.note, !note.isEmpty {
                                    Text(note)
                                        .font(DesignSystem.Typography.small)
                                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                        .lineLimit(1)
                                }

                                if isArchived {
                                    Text("Archived")
                                        .font(DesignSystem.Typography.small)
                                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                }

                                GeometryReader { geo in
                                    let width = geo.size.width
                                    let masteryWidth = width * mastery
                                    let dueFraction = snapshot.total > 0 ? Double(snapshot.dueTotal) / Double(snapshot.total) : 0
                                    let dueWidth = width * min(max(dueFraction, 0), 1)

                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(DesignSystem.Colors.subtleOverlay)
                                            .frame(height: 4)

                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(DesignSystem.Colors.studyAccentDeep.opacity(0.3))
                                            .frame(width: masteryWidth, height: 4)

                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(DesignSystem.Colors.studyAccentMid.opacity(0.36))
                                            .frame(width: dueWidth, height: 4)
                                    }
                                    .opacity(isArchived ? 0.4 : 1)
                                }
                                .frame(height: 6)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .fill(isSelected ? DesignSystem.Colors.selectedBackground.opacity(0.42) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .stroke(isSelected ? DesignSystem.Colors.separator.opacity(0.66) : Color.clear, lineWidth: 1)
                    )
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(DesignSystem.Colors.studyAccentMid.opacity(0.8))
                            .frame(width: 2)
                            .padding(.vertical, 8)
                            .padding(.leading, 4)
                            .opacity(isSelected ? 1 : 0)
                    }
                    .opacity(isArchived ? 0.7 : 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(DesignSystem.Animation.quick) {
                            selection = sidebarItem
                        }
                    }
                }
            case .compact:
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if hasChildren {
                            Button {
                                withAnimation(DesignSystem.Animation.quick) {
                                    toggleDeckExpanded(deck.id)
                                }
                            } label: {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(DesignSystem.Typography.captionMedium)
                                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                                .frame(width: 16, height: 16)
                        }

                        Image(systemName: deck.isFolder ? "folder.fill" : (hasChildren ? "folder.fill" : "square.fill"))
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText.opacity(isArchived ? 0.55 : 0.9))
                            .frame(width: 16, height: 16)

                        Text(deck.name)
                            .font(isSelected ? DesignSystem.Typography.bodyMedium : DesignSystem.Typography.body)
                            .foregroundStyle(nameColor.opacity(isArchived ? 0.65 : 1))
                            .lineLimit(1)

                        Spacer(minLength: DesignSystem.Spacing.sm)

                        let dueValue = snapshot.dueTotal > 0 ? snapshot.dueTotal : snapshot.dueSoon
                        if dueValue > 0 {
                            let dueTint: Color = snapshot.overdue > 0 ? DesignSystem.Colors.feedbackWarning : DesignSystem.Colors.secondaryText
                            Text("\(dueValue)")
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundStyle(dueTint.opacity(isArchived ? 0.45 : 0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.subtleOverlay.opacity(isArchived ? 0.35 : 0.8))
                                )
                        }
                    }
                    .padding(.leading, CGFloat(threadInfo.depth) * DeckThreading.indentUnit)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .fill(isSelected ? DesignSystem.Colors.selectedBackground.opacity(0.38) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .stroke(isSelected ? DesignSystem.Colors.separator.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(DesignSystem.Colors.studyAccentMid.opacity(0.78))
                            .frame(width: 2)
                            .padding(.vertical, 7)
                            .padding(.leading, 4)
                            .opacity(isSelected ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(DesignSystem.Animation.quick) {
                            selection = sidebarItem
                        }
                    }

                    if isSelected, snapshot.total == 0, !deck.isFolder {
                        Text("This deck is empty")
                            .font(DesignSystem.Typography.small)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .padding(.leading, CGFloat(threadInfo.depth) * DeckThreading.indentUnit + 44)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                    }
                }
            }
        }
        .contextMenu {
            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    selection = sidebarItem
                }
                onExportDeck(deck)
            } label: {
                Label("Export Deck…", systemImage: "square.and.arrow.up")
            }

            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    selection = sidebarItem
                }
                onNewSubdeck(deck)
            } label: {
                Label("New Subdeck…", systemImage: "plus.rectangle.on.folder")
            }

            Button(action: {
                withAnimation(DesignSystem.Animation.quick) {
                    selection = sidebarItem
                }
                onRenameDeck(deck)
            }) {
                Label("Rename Deck", systemImage: "pencil")
            }

            Button {
                moveDeckRequest = SidebarMoveDeckRequest(id: deck.id, isArchivedSection: isArchived)
            } label: {
                Label("Move to…", systemImage: "folder")
            }

            if isArchived {
                Button {
                    onUnarchiveDeck(deck)
                } label: {
                    Label("Restore Deck", systemImage: "archivebox.fill")
                }
            } else {
                Button {
                    onArchiveDeck(deck)
                } label: {
                    Label("Archive Deck", systemImage: "archivebox")
                }
            }

            Button(role: .destructive, action: {
                if selectedDeck?.id == deck.id {
                    onDeleteDeck()
                }
            }) {
                Label("Delete Deck", systemImage: "trash")
            }
            .disabled(selectedDeck?.id != deck.id)

            if let selectedDeck, selectedDeck.id != deck.id {
                Button {
                    onMergeDecks(deck, selectedDeck)
                } label: {
                    Label("Merge Into “\(selectedDeck.name)”", systemImage: "arrow.triangle.merge")
                }
            }
        }
        .designSystemContextMenu {
            ContextMenuItem(icon: "pencil", label: "Rename") {
                withAnimation(DesignSystem.Animation.quick) {
                    selection = sidebarItem
                }
                onRenameDeck(deck)
            }
            
            ContextMenuItem(icon: "plus.rectangle.on.folder", label: "New Subdeck…") {
                withAnimation(DesignSystem.Animation.quick) {
                    selection = sidebarItem
                }
                onNewSubdeck(deck)
            }
            
            ContextMenuItem(icon: "folder", label: "Move to…") {
                moveDeckRequest = SidebarMoveDeckRequest(id: deck.id, isArchivedSection: isArchived)
            }
            
            ContextMenuDivider()
            
            ContextMenuItem(icon: "square.and.arrow.up", label: "Export…") {
                withAnimation(DesignSystem.Animation.quick) {
                    selection = sidebarItem
                }
                onExportDeck(deck)
            }
            
            ContextMenuDivider()
            
            if isArchived {
                ContextMenuItem(icon: "archivebox.fill", label: "Restore") {
                    onUnarchiveDeck(deck)
                }
            } else {
                ContextMenuItem(icon: "archivebox", label: "Archive") {
                    onArchiveDeck(deck)
                }
            }
            
            ContextMenuItem(
                icon: "trash",
                label: "Delete",
                isDestructive: true,
                isDisabled: selectedDeck?.id != deck.id
            ) {
                if selectedDeck?.id == deck.id {
                    onDeleteDeck()
                }
            }
            
            if let selectedDeck, selectedDeck.id != deck.id {
                ContextMenuDivider()
                ContextMenuItem(icon: "arrow.triangle.merge", label: "Merge Into \"\(selectedDeck.name)\"") {
                    onMergeDecks(deck, selectedDeck)
                }
            }
        }
        .draggable(DeckDragPayload(id: deck.id))
        .dropDestination(for: DeckDragPayload.self) { items, location in
            handleDeckDrop(items: items, targetDeck: deck, isArchivedTarget: isArchived, location: location)
        } isTargeted: { isTargeted in
            if isTargeted {
                dropTargetDeckId = deck.id
            } else if dropTargetDeckId == deck.id {
                dropTargetDeckId = nil
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(DesignSystem.Colors.studyAccentBorder, lineWidth: 2)
                .opacity(dropTargetDeckId == deck.id ? 1 : 0)
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        rowHeights[deck.id] = proxy.size.height
                    }
            }
        )
    }

    func deckMastery(for deck: Deck) -> Double {
        if let node = navigatorSnapshot.deckNodes.first(where: { $0.deckId == deck.id }) {
            return min(max(node.mastery, 0), 1)
        }
        return 0
    }

    func deckEnergy(for deck: Deck) -> AdaptiveNavigatorSnapshot.Energy? {
        navigatorSnapshot.deckNodes.first(where: { $0.deckId == deck.id })?.energy
    }

    func handleDeckDrop(
        items: [DeckDragPayload],
        targetDeck: Deck,
        isArchivedTarget: Bool,
        location: CGPoint
    ) -> Bool {
        // Clear drop target state
        dropTargetDeckId = nil
        
        guard let payload = items.first,
              let sourceDeck = deck(for: payload.id),
              sourceDeck.id != targetDeck.id else { return false }

        let rowHeight = rowHeights[targetDeck.id] ?? 48
        let region = dropRegion(for: location.y, rowHeight: rowHeight)

        switch region {
        case .nest:
            guard sourceDeck.isArchived == isArchivedTarget else { return false }
            let sectionDecks = isArchivedTarget ? archivedDecks : decks
            let hierarchy = DeckHierarchy(decks: sectionDecks)
            guard hierarchy.canReparent(deckId: sourceDeck.id, toParentId: targetDeck.id) else { 
                // Can't nest - offer merge instead
                pendingMerge = SidebarPendingMerge(source: sourceDeck, target: targetDeck)
                return true
            }
            // Can nest - just move the deck as subdeck
            onMoveDeck(sourceDeck, targetDeck.id)
            return true
        case .before:
            // Manual reordering is disabled for now (may return in a future update).
            return false
        case .after:
            // Manual reordering is disabled for now (may return in a future update).
            return false
        }
    }

    func handleDropIntoActiveSection(items: [DeckDragPayload]) -> Bool {
        guard let payload = items.first,
              let archivedDeck = archivedDecks.first(where: { $0.id == payload.id }) else {
            return false
        }
        onUnarchiveDeck(archivedDeck)
        return true
    }

    func handleDropIntoArchivedSection(items: [DeckDragPayload]) -> Bool {
        guard let payload = items.first,
              let activeDeck = decks.first(where: { $0.id == payload.id }) else {
            return false
        }
        onArchiveDeck(activeDeck)
        return true
    }

    func deck(for id: UUID) -> Deck? {
        decks.first(where: { $0.id == id }) ?? archivedDecks.first(where: { $0.id == id })
    }

    enum DeckDropRegion {
        case before
        case nest
        case after
    }

    func dropRegion(for locationY: CGFloat, rowHeight: CGFloat) -> DeckDropRegion {
        let height = max(rowHeight, 1)
        let threshold = min(18, max(height * 0.25, 8))
        if locationY <= threshold {
            return .before
        }
        if locationY >= height - threshold {
            return .after
        }
        return .nest
    }

    /*
     Manual deck ordering (drag-to-reorder + persisted sort order) is intentionally disabled for now.
     It was flaky/unused, and it also masked bugs where sort mode changes didn’t affect the sidebar.

     We can revisit bringing this back later with a dedicated, well-tested reorder model.
     */

    func sidebarRow(
        item: SidebarItem,
        title: String,
        subtitle: String?,
        icon: String,
        badge: String?
    ) -> some View {
        let isSelected = selection == item
        return Button {
            withAnimation(DesignSystem.Animation.quick) {
                selection = item
            }
        } label: {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.captionMedium)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.studyAccentMid : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(isSelected ? DesignSystem.Typography.bodyMedium : DesignSystem.Typography.body)
                        .foregroundStyle(isSelected ? DesignSystem.Colors.primaryText : DesignSystem.Colors.primaryText)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.small)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: DesignSystem.Spacing.xxs)
                
                if let badge {
                    Text(badge)
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(isSelected ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.subtleOverlay)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected ? DesignSystem.Colors.studyAccentBorder.opacity(0.55) : Color.clear,
                                    lineWidth: 0.8
                                )
                        )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(isSelected ? DesignSystem.Colors.selectedBackground.opacity(0.38) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? DesignSystem.Colors.separator.opacity(0.6)
                        : Color.clear,
                    lineWidth: isSelected ? 1 : 0
                )
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(DesignSystem.Colors.studyAccentMid.opacity(0.8))
                .frame(width: 2)
                .padding(.vertical, 7)
                .padding(.leading, 4)
                .opacity(isSelected ? 1 : 0)
        }
    }

    func sidebarPlaceholder(message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "tray")
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            
            Text(message)
                .font(DesignSystem.Typography.small)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
                )
        )
    }

    func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(DesignSystem.Typography.smallMedium)
            .foregroundStyle(DesignSystem.Colors.tertiaryText)
            .tracking(0.8)
    }

    func refreshData() async {
#if DEBUG
        let refreshStartedAt = Date()
#endif
        try? Task.checkCancellation()

        async let decksTask = storage.allDecks()
        async let cardsTask = storage.allCards()
        async let examsTask = storage.allExams()
        async let studyGuidesTask = storage.allStudyGuides()
        async let coursesTask = storage.allCourses()
        async let settingsTask = storage.loadSettings()
        async let logsTask = ReviewLogService(storage: storage).recentLogs(limit: 500)

        let fetchedDeckDTOs = (try? await decksTask) ?? []
        let fetchedCardDTOs = (try? await cardsTask) ?? []
        let fetchedExamDTOs = (try? await examsTask) ?? []
        let fetchedStudyGuideDTOs = (try? await studyGuidesTask) ?? []
        let fetchedCourseDTOs = (try? await coursesTask) ?? []
        let logs = await logsTask
        let settingsDTO = try? await settingsTask
        let loadedSettings = settingsDTO?.toDomain() ?? UserSettings()
        try? Task.checkCancellation()

        let fetchedDecks = fetchedDeckDTOs.map { $0.toDomain() }
        let fetchedExams = fetchedExamDTOs.map { $0.toDomain() }
        let fetchedGuides = fetchedStudyGuideDTOs.map { $0.toDomain() }
        let fetchedCourses = fetchedCourseDTOs.map { $0.toDomain() }
        let hierarchy = DeckHierarchy(decks: fetchedDecks)

        let effectiveSortMode: DeckSortMode = (loadedSettings.deckSortMode == .manual) ? .nameAscending : loadedSettings.deckSortMode
        if loadedSettings.deckSortMode == .manual {
            var migrated = loadedSettings
            migrated.deckSortMode = effectiveSortMode
            try? await storage.save(settings: migrated.toDTO())
        }

        let sortedDecks = fetchedDecks.filter { !$0.isArchived }
        let sortedArchived = fetchedDecks.filter { $0.isArchived }
        let sortedTags: [String]
        if let appStorage = storage as? LocalStore {
            sortedTags = await appStorage.tagsSnapshot()
        } else {
            sortedTags = Array(Set(fetchedCardDTOs.flatMap(\.tags))).sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let soon = calendar.date(byAdding: .day, value: 3, to: startOfDay) ?? tomorrow

        var deckSnapshotAccumulator: [UUID: DeckSnapshot] = [:]

        for card in fetchedCardDTOs {
            guard let deckId = card.deckId else { continue }
            var snapshot = deckSnapshotAccumulator[deckId] ?? DeckSnapshot()
            snapshot.total += 1
            if !card.isSuspended {
                if card.srs.queue == .new {
                    snapshot.new += 1
                } else if card.srs.dueDate < startOfDay {
                    snapshot.overdue += 1
                } else if card.srs.dueDate < tomorrow {
                    snapshot.dueToday += 1
                } else if card.srs.dueDate < soon {
                    snapshot.dueSoon += 1
                }
            }
            deckSnapshotAccumulator[deckId] = snapshot
        }

        var aggregatedSnapshots = deckSnapshotAccumulator
        for (deckId, snapshot) in deckSnapshotAccumulator {
            for ancestor in hierarchy.ancestors(of: deckId) {
                var rolled = aggregatedSnapshots[ancestor.id] ?? DeckSnapshot()
                rolled.total += snapshot.total
                rolled.overdue += snapshot.overdue
                rolled.dueToday += snapshot.dueToday
                rolled.dueSoon += snapshot.dueSoon
                rolled.new += snapshot.new
                aggregatedSnapshots[ancestor.id] = rolled
            }
        }

        let activeDeckIDs = Set(sortedDecks.map(\.id))
        let activeCards = fetchedCardDTOs
            .filter { dto in dto.deckId.map(activeDeckIDs.contains) ?? false }
            .map { $0.toDomain() }

        let learningService = LearningIntelligenceService(storage: storage)
        let (session, navigator) = await learningService.snapshots(
            decks: sortedDecks,
            cards: activeCards,
            settings: loadedSettings,
            date: Date()
        )

        let todayCount = logs.filter { log in
            log.timestamp >= startOfDay && log.timestamp < tomorrow
        }.count

        await MainActor.run {
            guard !Task.isCancelled else { return }
            decks = sortedDecks
            archivedDecks = sortedArchived
            exams = fetchedExams
            studyGuides = fetchedGuides
            courses = fetchedCourses
            tags = sortedTags
            deckSnapshots = aggregatedSnapshots
            sessionSnapshot = session
            navigatorSnapshot = navigator
            settings = loadedSettings
            deckSortMode = effectiveSortMode
            todayReviewCount = todayCount
        }

#if DEBUG
        let refreshMs = Int(Date().timeIntervalSince(refreshStartedAt) * 1000)
        if refreshMs > 250 {
            print("SidebarView.refreshData took \(refreshMs)ms (decks=\(fetchedDeckDTOs.count), cards=\(fetchedCardDTOs.count), exams=\(fetchedExamDTOs.count), guides=\(fetchedStudyGuideDTOs.count))")
        }
#endif
    }


}

private struct DeckSnapshot: Equatable {
    var overdue: Int = 0
    var dueToday: Int = 0
    var dueSoon: Int = 0
    var new: Int = 0
    var total: Int = 0

    var dueTotal: Int { overdue + dueToday }
}


private struct CollapsibleSidebarSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    let content: Content
    let trailingButton: AnyView?

    init(
        title: String,
        icon: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
        self.trailingButton = nil
        self.content = content()
    }
    
    init<TrailingButton: View>(
        title: String,
        icon: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder trailingButton: () -> TrailingButton,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
        self.trailingButton = AnyView(trailingButton())
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Button {
                    withAnimation(DesignSystem.Animation.quick) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(DesignSystem.Typography.smallMedium)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .frame(width: 12)
                        
                        Image(systemName: icon)
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        
                        Text(title)
                            .font(DesignSystem.Typography.smallMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .textCase(.uppercase)
                            .tracking(0.8)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if let trailingButton {
                    trailingButton
                        .padding(.trailing, DesignSystem.Spacing.xxs)
                }
            }

            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct SidebarMoveDeckSheet: View {
    let deck: Deck
    let sectionDecks: [Deck]
    let onMove: (UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    var body: some View {
        let hierarchy = DeckHierarchy(decks: sectionDecks)
        let destinations = sectionDecks.filter { candidate in
            candidate.id != deck.id && hierarchy.canReparent(deckId: deck.id, toParentId: candidate.id)
        }
        let filteredDestinations = destinations.filter { candidate in
            guard !searchText.isEmpty else { return true }
            return hierarchy.displayPath(of: candidate.id).localizedCaseInsensitiveContains(searchText)
        }

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Move “\(deck.name)”")
                .font(DesignSystem.Typography.heading)

            TextField("Search destinations", text: $searchText)
                .textFieldStyle(.roundedBorder)

            List {
                Button("Move to Root") {
                    onMove(nil)
                    dismiss()
                }

                if filteredDestinations.isEmpty {
                    Text(searchText.isEmpty ? "No available destinations." : "No matches.")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Destinations") {
                        ForEach(filteredDestinations) { candidate in
                            Button(hierarchy.displayPath(of: candidate.id)) {
                                onMove(candidate.id)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 520, minHeight: 520)
        }
        .padding(DesignSystem.Spacing.lg)
    }
}

extension NumberFormatter {
    static let compactFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let sidebarPercent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

enum SidebarItem: Hashable, Identifiable {
    case learningIntelligence
    case deckOrganizer
    case folder(UUID)
    case deck(UUID)
    case exam(UUID)
    case studyGuide(UUID)
    case course(UUID)
    case tag(String)
    case smart(SmartFilter)
    case stats
    case settings

    var id: String {
        switch self {
        case .learningIntelligence: return "learning-intelligence"
        case .deckOrganizer: return "deck-organizer"
        case .folder(let id): return "folder-\(id.uuidString)"
        case .deck(let id): return "deck-\(id.uuidString)"
        case .exam(let id): return "exam-\(id.uuidString)"
        case .studyGuide(let id): return "study-guide-\(id.uuidString)"
        case .course(let id): return "course-\(id.uuidString)"
        case .tag(let tag): return "tag-\(tag)"
        case .smart(let filter): return "smart-\(filter.rawValue)"
        case .stats: return "stats"
        case .settings: return "settings"
        }
    }
}

#if DEBUG

private enum SidebarPreviewData {
    static func seed(storage: Storage) async {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let math = Deck(name: "Math", note: "Linear algebra")
        let algebra = Deck(parentId: math.id, name: "Algebra", note: "Groups • Rings • Fields")
        let languages = Deck(name: "Languages", note: "Daily review")
        let archived = Deck(name: "Old Notes", note: "Archived deck", isArchived: true)

        do {
            try await storage.upsert(deck: math.toDTO())
            try await storage.upsert(deck: algebra.toDTO())
            try await storage.upsert(deck: languages.toDTO())
            try await storage.upsert(deck: archived.toDTO())

            var overdue = Card(deckId: math.id, kind: .basic, front: "Define a vector space", back: "...")
            overdue.srs.queue = .review
            overdue.srs.dueDate = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
            overdue.tags = ["math", "linear-algebra"]

            var dueToday = Card(deckId: algebra.id, kind: .basic, front: "What is a group?", back: "...")
            dueToday.srs.queue = .review
            dueToday.srs.dueDate = calendar.date(byAdding: .hour, value: 2, to: startOfDay) ?? now
            dueToday.tags = ["math", "algebra"]

            var dueSoon = Card(deckId: languages.id, kind: .basic, front: "Hola → ?", back: "Hello")
            dueSoon.srs.queue = .review
            dueSoon.srs.dueDate = calendar.date(byAdding: .day, value: 2, to: startOfDay) ?? now
            dueSoon.tags = ["language", "spanish"]

            var newCard = Card(deckId: languages.id, kind: .basic, front: "Merci → ?", back: "Thank you")
            newCard.srs.queue = .new
            newCard.tags = ["language", "french"]

            var archivedCard = Card(deckId: archived.id, kind: .basic, front: "Archived front", back: "Archived back")
            archivedCard.srs.queue = .review
            archivedCard.srs.dueDate = calendar.date(byAdding: .day, value: -3, to: startOfDay) ?? startOfDay
            archivedCard.tags = ["archive"]

            try await storage.upsert(card: overdue.toDTO())
            try await storage.upsert(card: dueToday.toDTO())
            try await storage.upsert(card: dueSoon.toDTO())
            try await storage.upsert(card: newCard.toDTO())
            try await storage.upsert(card: archivedCard.toDTO())
        } catch {
        }
    }
}

private struct SidebarPreviewContainer: View {
    let displayMode: SidebarView.DisplayMode
    let controller: DataController

    @State private var selection: SidebarItem? = .learningIntelligence
    @State private var selectedDeck: Deck?

    init(displayMode: SidebarView.DisplayMode, controller: DataController) {
        self.displayMode = displayMode
        self.controller = controller
    }

    var body: some View {
        SidebarView(
            selection: $selection,
            displayMode: displayMode,
            selectedDeck: selectedDeck,
            onNewDeck: {},
            onNewFolder: {},
            onNewExam: {},
            onNewStudyGuide: {},
            onNewCourse: {},
            onNewSubdeck: { _ in },
            onMoveDeck: { _, _ in },
            onRenameDeck: { _ in },
            onDeleteDeck: {},
            onArchiveDeck: { _ in },
            onUnarchiveDeck: { _ in },
            onExportDeck: { _ in },
            onMergeDecks: { _, _ in },
            onDeckOrderChange: { _ in },
            onImport: {},
            onExport: {}
        )
        .environment(\.storage, controller.storage)
        .environmentObject(controller.events)
        .task(id: selection) { await syncSelectedDeck() }
    }

    private func syncSelectedDeck() async {
        guard case .deck(let id) = selection else {
            await MainActor.run { selectedDeck = nil }
            return
        }
        let deck = await DeckService(storage: controller.storage).deck(withId: id)
        await MainActor.run { selectedDeck = deck }
    }
}

#Preview("SidebarView – Expanded") {
    let controller = DataController.previewController()
    SidebarPreviewContainer(displayMode: .expanded, controller: controller)
        .task { await SidebarPreviewData.seed(storage: controller.storage) }
        .frame(width: 320, height: 820)
        .padding()
        .background(DesignSystem.Colors.window)
}

#Preview("SidebarView – Compact") {
    let controller = DataController.previewController()
    SidebarPreviewContainer(displayMode: .compact, controller: controller)
        .task { await SidebarPreviewData.seed(storage: controller.storage) }
        .frame(width: 320, height: 820)
        .padding()
        .background(DesignSystem.Colors.window)
}

#endif
