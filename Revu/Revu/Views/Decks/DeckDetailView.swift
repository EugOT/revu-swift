import SwiftUI

struct DeckDetailView: View {
    let deck: Deck
    let onImportDeck: (Deck) -> Void
    let onShowImportGuide: () -> Void

    @Environment(\.storage) private var storage
    @EnvironmentObject private var storeEvents: StoreEvents
    @State private var deckSnapshot: Deck
    @State private var activeStudyMode: DeckStudyMode?
    @State private var filter: CardBrowserFilter
    @State private var summary: DeckSummary = .empty
    @State private var selectedStudyMode: DeckStudyMode = .dueToday
    @State private var isDueDateEditorPresented: Bool = false
    @State private var dueDateDraft: Date = Calendar.current.startOfDay(for: Date())
    @State private var datePickerSessionId = UUID()
    @State private var loadTask: Task<Void, Never>?
    @State private var lastRefreshTime: Date = Date.distantPast
    @State private var activeGameMode: GameMode?
    @State private var gameCards: [Card] = []
    @State private var isLoadingGame: Bool = false
    @State private var deckDisplayPath: String = ""
    @State private var estimatedSecondsPerReview: TimeInterval = 18
    @State private var lastEstimateRefresh: Date = Date.distantPast
    @State private var lastPathRefreshTime: Date = Date.distantPast
    @State private var lastPathDeckName: String = ""
    @State private var lastPathParentId: UUID? = nil
    @State private var studyCTAIsHovered: Bool = false
    @FocusState private var studyCTAIsFocused: Bool
    @State private var studyCTASheenTraveling: Bool = false
    @State private var isStudyCTAAnimationActive: Bool = false

    enum GameMode: String, Identifiable {
        case match
        case speedQuiz
        var id: String { rawValue }
    }

    init(
        deck: Deck,
        onImportDeck: @escaping (Deck) -> Void = { _ in },
        onShowImportGuide: @escaping () -> Void = {}
    ) {
        self.deck = deck
        self.onImportDeck = onImportDeck
        self.onShowImportGuide = onShowImportGuide
        self._filter = State(initialValue: .deck(deck.id))
        self._deckSnapshot = State(initialValue: deck)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Group {
                if let mode = activeStudyMode {
                    StudySessionSurface {
                        StudySessionView(deck: deckSnapshot, mode: mode, onDismiss: endStudySession)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                } else if let gameMode = activeGameMode {
                    StudySessionSurface {
                        switch gameMode {
                        case .match:
                            MatchGameView(cards: gameCards, onDismiss: endGameSession)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        case .speedQuiz:
                            SpeedQuizView(cards: gameCards, onDismiss: endGameSession)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
	                } else {
	                    ZStack {
	                        DesignSystem.Colors.window
	                            .ignoresSafeArea()
	                        cardBrowserSurface
	                    }
	                }
	            }
            .animation(.easeInOut(duration: 0.2), value: activeStudyMode != nil)
            .animation(.easeInOut(duration: 0.2), value: activeGameMode != nil)
            .sheet(isPresented: $isDueDateEditorPresented) {
                dueDateEditor
                    .id(datePickerSessionId)
            }
	        .task(id: deck.id) {
	            activeStudyMode = nil
	            activeGameMode = nil
	            filter = .deck(deck.id)
	            deckSnapshot = deck
	            deckDisplayPath = ""
	            lastPathRefreshTime = .distantPast
	            lastPathDeckName = ""
	            lastPathParentId = nil
	            await scheduleSummaryLoad(reset: true).value
	        }
            .onChange(of: deck, initial: false) { oldDeck, newDeck in
                print("[DeckDetail] onChange(deck): old dueDate=\(String(describing: oldDeck.dueDate)), new dueDate=\(String(describing: newDeck.dueDate)), current snapshot dueDate=\(String(describing: deckSnapshot.dueDate))")
                deckSnapshot = newDeck
                // Only reload if deck properties changed significantly
                if newDeck.updatedAt != oldDeck.updatedAt || newDeck.dueDate != oldDeck.dueDate {
                    scheduleSummaryLoad()
                }
            }
            .onReceive(storeEvents.$tick) { _ in
                // Debounce: only refresh if more than 2 seconds since last refresh
                let now = Date()
                guard now.timeIntervalSince(lastRefreshTime) > 2.0 else { return }
                lastRefreshTime = now
                scheduleSummaryLoad()
            }
        }
    }

    private var deckHeaderBar: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs * 0.5) {
                    Text("Deck")
                        .font(DesignSystem.Typography.small)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text(deckDisplayPath.isEmpty ? deckSnapshot.name : deckDisplayPath)
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if deckSnapshot.isArchived {
                        archivedBadge
                    }
                }

                Spacer(minLength: DesignSystem.Spacing.sm)

                actionButtons
            }

            statsPillRow
            if let descriptor = deckDueDescriptor() {
                deadlineBanner(descriptor: descriptor)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
            if deckSnapshot.isArchived {
                archivedHeaderNotice
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.top, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.window)
    }

    private var statsPillRow: some View {
        return HStack(spacing: DesignSystem.Spacing.md) {
            statPill(
                title: "Due",
                value: "\(summary.dueToday)",
                icon: "circle.fill",
                tint: summary.dueToday > 0 ? DesignSystem.Colors.primaryText : DesignSystem.Colors.tertiaryText
            )
            statPill(
                title: "New",
                value: "\(summary.newToday)",
                icon: "circle.fill",
                tint: summary.newToday > 0 ? DesignSystem.Colors.primaryText : DesignSystem.Colors.tertiaryText
            )
            statPill(
                title: "Total",
                value: "\(summary.total)",
                icon: "circle.fill",
                tint: DesignSystem.Colors.tertiaryText
            )
            if deckSnapshot.dueDate == nil {
                addDeadlineButton
            }
        }
    }

    private func deadlineBanner(descriptor: DeckDueDescriptor) -> some View {
        Button(action: presentDueDateEditor) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: descriptor.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(descriptor.color)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(descriptor.color.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("Exam deadline")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Text(descriptor.countdown)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(descriptor.color)
                }

                Spacer(minLength: DesignSystem.Spacing.sm)

                Text(descriptor.absolute)
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .fill(descriptor.color.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.separator.opacity(0.7), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            quickDueDateButton(days: 3, label: "3 days")
            quickDueDateButton(days: 7, label: "1 week")
            quickDueDateButton(days: 14, label: "2 weeks")
            if deckSnapshot.dueDate != nil {
                Divider()
                Button(role: .destructive) {
                    Task { @MainActor in await applyDueDate(nil) }
                } label: {
                    Label("Clear Due Date", systemImage: "calendar.badge.minus")
                }
            }
        }
    }

    private func statPill(
        title: String,
        value: String,
        icon: String,
        tint: Color? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        let textColor = tint ?? DesignSystem.Colors.secondaryText

        let content = HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(textColor.opacity(0.5))
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.subtleOverlay.opacity(0.5))
        )

        return Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var addDeadlineButton: some View {
        Button(action: presentDueDateEditor) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                
                Text("Add Deadline")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.studyAccentDeep.opacity(0.12))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            quickDueDateButton(days: 3, label: "3 days")
            quickDueDateButton(days: 7, label: "1 week")
            quickDueDateButton(days: 14, label: "2 weeks")
        }
    }

    private func presentDueDateEditor() {
        let calendar = Calendar.current
        let base = deckSnapshot.dueDate ?? Date()
        dueDateDraft = calendar.startOfDay(for: base)
        datePickerSessionId = UUID()
        isDueDateEditorPresented = true
    }

    private var cardBrowserSurface: some View {
        GeometryReader { proxy in
            ZStack {
                CardTableView(filter: filter, storage: storage) {
                    deckHeaderBar
                }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                    .background(DesignSystem.Colors.window)
                    .allowsHitTesting(!deckSnapshot.isArchived)

                if deckSnapshot.isArchived {
                    Rectangle()
                        .fill(DesignSystem.Colors.window.opacity(0.92))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    archivedOverlay
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                }
            }
        }
    }
    
    private enum ActionPillStyle {
        case neutral
        case accent

        var fill: Color {
            switch self {
            case .neutral:
                return DesignSystem.Colors.primaryText.opacity(0.08)
            case .accent:
                return DesignSystem.Colors.studyAccentDeep.opacity(0.14)
            }
        }

        var stroke: Color {
            switch self {
            case .neutral:
                return DesignSystem.Colors.separator.opacity(0.3)
            case .accent:
                return DesignSystem.Colors.studyAccentBorder.opacity(0.85)
            }
        }

        var foreground: Color {
            switch self {
            case .neutral:
                return DesignSystem.Colors.primaryText
            case .accent:
                return DesignSystem.Colors.studyAccentBright
            }
        }

        var strokeWidth: CGFloat {
            switch self {
            case .neutral:
                return 0.5
            case .accent:
                return 0.8
            }
        }

        var textFont: Font {
            switch self {
            case .neutral:
                return DesignSystem.Typography.smallMedium
            case .accent:
                return DesignSystem.Typography.small.weight(.semibold)
            }
        }

        var iconFont: Font {
            DesignSystem.Typography.small.weight(.semibold)
        }
    }

    private enum ActionPillMetrics {
        static let height: CGFloat = DesignSystem.Spacing.lg + DesignSystem.Spacing.xxs // 28
        static let horizontalPadding: CGFloat = DesignSystem.Spacing.sm // 12
        static let contentSpacing: CGFloat = DesignSystem.Spacing.xxs + (DesignSystem.Spacing.xxs / 2) // 6
    }

    private func fullActionPillLabel(icon: String, title: String, style: ActionPillStyle) -> some View {
        HStack(spacing: ActionPillMetrics.contentSpacing) {
            Image(systemName: icon)
                .font(style.iconFont)
            Text(title)
                .font(style.textFont)
                .lineLimit(1)
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, ActionPillMetrics.horizontalPadding)
        .frame(height: ActionPillMetrics.height)
        .background(
            Capsule()
                .fill(style.fill)
        )
        .overlay(
            Capsule()
                .stroke(style.stroke, lineWidth: style.strokeWidth)
        )
        .contentShape(Capsule())
    }

    private func iconOnlyActionPillLabel(icon: String, style: ActionPillStyle) -> some View {
        Image(systemName: icon)
            .font(style.iconFont)
            .foregroundStyle(style.foreground)
            .frame(width: ActionPillMetrics.height, height: ActionPillMetrics.height)
            .background(
                Capsule()
                    .fill(style.fill)
            )
            .overlay(
                Capsule()
                    .stroke(style.stroke, lineWidth: style.strokeWidth)
            )
            .contentShape(Capsule())
    }

    private func compactableActionPillLabel(
        icon: String,
        title: String,
        style: ActionPillStyle,
        fixedTitle: String? = nil
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            fullActionPillLabel(icon: icon, title: fixedTitle ?? title, style: style)
                .fixedSize(horizontal: true, vertical: false)
            iconOnlyActionPillLabel(icon: icon, style: style)
        }
    }

    private func studyActionPillContent(icon: String, title: String, iconOnly: Bool = false) -> some View {
        Group {
            if iconOnly {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.small.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .frame(width: ActionPillMetrics.height, height: ActionPillMetrics.height)
            } else {
                HStack(spacing: ActionPillMetrics.contentSpacing) {
                    Image(systemName: icon)
                        .font(DesignSystem.Typography.small.weight(.semibold))
                    Text(title)
                        .font(DesignSystem.Typography.small.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.white.opacity(0.96))
                .padding(.horizontal, ActionPillMetrics.horizontalPadding)
                .frame(height: ActionPillMetrics.height)
            }
        }
    }

    private func studyActionPillChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
        .background(
            Capsule()
                .fill(DesignSystem.Gradients.studyAccentDiagonal)
        )
        .overlay(
            Capsule()
                .stroke(DesignSystem.Colors.studyAccentBorder.opacity(studyCTAIsHovered ? 0.95 : 0.78), lineWidth: 0.9)
        )
        .overlay {
            GeometryReader { geometry in
                let travel = geometry.size.width * 1.15
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.22),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: max(geometry.size.width * 0.34, 20))
                    .rotationEffect(.degrees(14))
                    .offset(x: studyCTASheenTraveling ? travel : -travel)
                    .mask(Capsule())
            }
            .allowsHitTesting(false)
            .opacity(isStudyCTAAnimationActive ? 1 : 0)
        }
        .shadow(
            color: DesignSystem.Colors.studyAccentGlow.opacity(studyCTAIsHovered ? 0.26 : (isStudyCTAAnimationActive ? 0.18 : 0.11)),
            radius: studyCTAIsHovered ? 10 : (isStudyCTAAnimationActive ? 8 : 5),
            x: 0,
            y: studyCTAIsHovered ? 6 : 3
        )
        .scaleEffect(studyCTAIsHovered ? 1.005 : 1.0)
        .animation(DesignSystem.Animation.quick, value: studyCTAIsHovered)
    }

    private func updateStudyCTAAnimationState() {
        let shouldAnimate = studyCTAIsHovered || studyCTAIsFocused
        guard shouldAnimate != isStudyCTAAnimationActive else { return }

        isStudyCTAAnimationActive = shouldAnimate
        studyCTASheenTraveling = false

        guard shouldAnimate else { return }
        withAnimation(DesignSystem.Animation.ambientSweep) {
            studyCTASheenTraveling = true
        }
    }

    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            importMenu
            gamesMenu
            studyCTA
        }
    }

    private var importMenu: some View {
        Menu {
            Button {
                onImportDeck(deckSnapshot)
            } label: {
                Label("Import or merge from file…", systemImage: "square.and.arrow.down")
            }

            Button {
                onShowImportGuide()
            } label: {
                Label("View import guide", systemImage: "book")
            }
        } label: {
            compactableActionPillLabel(
                icon: "tray.and.arrow.down",
                title: "Import",
                style: .neutral
            )
        }
        .buttonStyle(.plain)
        .disabled(deckSnapshot.isArchived)
        .opacity(deckSnapshot.isArchived ? 0.5 : 1)
        .accessibilityLabel("Import or merge cards")
        .help("Import")
    }

    private var gamesMenu: some View {
        Menu {
            Button {
                startGame(.match)
            } label: {
                Label("Match", systemImage: "square.grid.2x2")
            }
            
            Button {
                startGame(.speedQuiz)
            } label: {
                Label("Speed Quiz", systemImage: "timer")
            }
        } label: {
            compactableActionPillLabel(
                icon: "gamecontroller.fill",
                title: "Games",
                style: .neutral
            )
        }
        .buttonStyle(.plain)
        .disabled(deckSnapshot.isArchived || isLoadingGame)
        .opacity(deckSnapshot.isArchived ? 0.5 : 1)
        .help("Games")
    }

    private var studyCTA: some View {
        let due = summary.dueToday
        let estimate = formattedStudyEstimate(seconds: Double(due) * estimatedSecondsPerReview)
        let label = due > 0 ? "Study \(due) (~\(estimate))" : "Study"
        let compactLabel = due > 0 ? "Study \(due)" : "Study"
        let primaryMode: DeckStudyMode = due > 0 ? .dueToday : .all

        return HStack(spacing: 6) {
            Button {
                beginStudy(with: primaryMode)
            } label: {
                studyActionPillChrome {
                    ViewThatFits(in: .horizontal) {
                        studyActionPillContent(icon: "play.fill", title: label)
                            .fixedSize(horizontal: true, vertical: false)
                        studyActionPillContent(icon: "play.fill", title: compactLabel)
                            .fixedSize(horizontal: true, vertical: false)
                        studyActionPillContent(icon: "play.fill", title: "Study")
                            .fixedSize(horizontal: true, vertical: false)
                        studyActionPillContent(icon: "play.fill", title: "Study", iconOnly: true)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(deckSnapshot.isArchived)
            .opacity(deckSnapshot.isArchived ? 0.5 : 1)
            .onHover { hovering in
                withAnimation(DesignSystem.Animation.quick) {
                    studyCTAIsHovered = hovering
                }
                updateStudyCTAAnimationState()
            }
            .focusable(true)
            .focused($studyCTAIsFocused)
            .onChange(of: studyCTAIsFocused) { _, _ in
                updateStudyCTAAnimationState()
            }
            .accessibilityLabel("Study \(due) cards")
            .help(label)
            .onDisappear {
                isStudyCTAAnimationActive = false
                studyCTASheenTraveling = false
            }

            Menu {
                ForEach(DeckStudyMode.allCases) { mode in
                    Button {
                        beginStudy(with: mode)
                    } label: {
                        Label(mode.menuTitle, systemImage: mode.icon)
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.studyAccentDeep.opacity(0.22))
                    )
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.Colors.studyAccentBorder.opacity(0.75), lineWidth: 0.8)
                    )
                    .shadow(color: DesignSystem.Colors.studyAccentGlow.opacity(0.20), radius: 6, x: 0, y: 3)
            }
            .menuStyle(.borderlessButton)
            .disabled(deckSnapshot.isArchived)
            .opacity(deckSnapshot.isArchived ? 0.5 : 1)
            .help("Choose study mode")
        }
    }

    private var archivedBadge: some View {
        Label("Archived", systemImage: "archivebox")
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.studyAccentBright)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.studyAccentDeep.opacity(0.12))
            )
    }

    private var archivedHeaderNotice: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            Text("Restore this deck from the sidebar to resume studying.")
                .font(DesignSystem.Typography.small)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
        }
        .padding(.top, DesignSystem.Spacing.xs)
    }

    private var archivedOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "archivebox")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            Text("This deck is archived")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(DesignSystem.Colors.primaryText)
            Text("Cards are read-only while archived. Unarchive from the sidebar to continue editing or studying.")
                .font(DesignSystem.Typography.small)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 16)
    }

    private func quickDueDateButton(days: Int, label: String) -> some View {
        Button {
            let target = Calendar.current.date(byAdding: .day, value: days, to: Date())
            Task { @MainActor in await applyDueDate(target.map(normalizedDueDate) ?? Date()) }
        } label: {
            Label("Due in \(label)", systemImage: "calendar.badge.clock")
        }
    }

    private var dueDateEditor: some View {
        DesignSystemDatePickerSurface(
            title: "Deck Due Date",
            selectedDate: $dueDateDraft,
            allowClear: deckSnapshot.dueDate != nil,
            helpText: "We'll adapt scheduling so your final review lands right before this date.",
            onSave: { newDate in
                print("[DeckDetail] onSave closure received: \(String(describing: newDate)), ti1970=\(String(describing: newDate?.timeIntervalSince1970))")
                Task { @MainActor in
                    await applyDueDate(newDate)
                }
            },
            onDismiss: {
                isDueDateEditorPresented = false
            }
        )
    }

    @MainActor
    private func applyDueDate(_ newValue: Date?) async {
        print("[DeckDetail] applyDueDate called with: \(String(describing: newValue))")
        var updated = deckSnapshot
        updated.dueDate = newValue
        updated.updatedAt = Date()
        await DeckService(storage: storage).upsert(deck: updated)
        let plan = await StudyPlanService(storage: storage).rebuildDeckPlan(
            forDeckId: deck.id,
            dueDate: newValue
        )
        await refreshDeckSnapshot()
        summary = DeckSummary(
            total: plan.totalCards,
            dueToday: plan.dueToday,
            newToday: plan.days.first?.newCount ?? 0,
            remainingNew: plan.activeNewCards,
            suspended: plan.suspendedCards,
            lastStudied: plan.lastStudied
        )
        lastRefreshTime = Date()
        isDueDateEditorPresented = false
    }

    private func normalizedDueDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        if let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) {
            return endOfDay
        }
        return date
    }

    private func refreshDeckSnapshot() async {
        let service = DeckService(storage: storage)
        if let refreshed = await service.deck(withId: deck.id) {
            #if DEBUG
            print("[DeckDetail] refreshDeckSnapshot: storage returned dueDate=\(String(describing: refreshed.dueDate))")
            #endif
            await MainActor.run {
                deckSnapshot = refreshed
            }
        }

        let shouldRefreshPath = await MainActor.run {
            deckDisplayPath.isEmpty ||
                deckSnapshot.name != lastPathDeckName ||
                deckSnapshot.parentId != lastPathParentId
        }
        guard shouldRefreshPath else { return }

        let now = Date()
        let isPathEmpty = await MainActor.run { deckDisplayPath.isEmpty }
        guard now.timeIntervalSince(lastPathRefreshTime) > 5 || isPathEmpty else { return }

        let decks = await service.allDecks(includeArchived: true)
        let hierarchy = DeckHierarchy(decks: decks)
        await MainActor.run {
            deckDisplayPath = hierarchy.displayPath(of: deck.id)
            lastPathRefreshTime = now
            lastPathDeckName = deckSnapshot.name
            lastPathParentId = deckSnapshot.parentId
        }
    }

    // Legacy metric columns function kept for compatibility
    private func deckDueDescriptor() -> DeckDueDescriptor? {
        guard let dueDate = deckSnapshot.dueDate else { return nil }
        let now = Date()
        let calendar = Calendar.current
        let absolute = dueDate.formatted(date: .abbreviated, time: .omitted)
        if dueDate <= now {
            return DeckDueDescriptor(
                countdown: "Due now",
                absolute: absolute,
                icon: "calendar.badge.exclamationmark",
                color: .red,
                urgency: 0
            )
        }

        let hoursUntil = dueDate.timeIntervalSince(now) / 3600.0
        if hoursUntil < 24 {
            let hours = max(1, Int(ceil(hoursUntil)))
            return DeckDueDescriptor(
                countdown: "Due in \(hours)h",
                absolute: absolute,
                icon: "hourglass",
                color: .orange,
                urgency: 1
            )
        }

        let startOfNow = calendar.startOfDay(for: now)
        let startOfDue = calendar.startOfDay(for: dueDate)
        let daysBetween = calendar.dateComponents([.day], from: startOfNow, to: startOfDue).day ?? 0
        if daysBetween == 0 {
            return DeckDueDescriptor(
                countdown: "Due today",
                absolute: absolute,
                icon: "calendar",
                color: .orange,
                urgency: 1
            )
        }
        if daysBetween == 1 {
            return DeckDueDescriptor(
                countdown: "Due tomorrow",
                absolute: absolute,
                icon: "calendar.badge.clock",
                color: .orange,
                urgency: 1
            )
        }
        if daysBetween <= 7 {
            return DeckDueDescriptor(
                countdown: "Due in \(daysBetween) days",
                absolute: absolute,
                icon: "calendar.badge.clock",
                color: .blue,
                urgency: 2
            )
        }
        return DeckDueDescriptor(
            countdown: "Due in \(daysBetween) days",
            absolute: absolute,
            icon: "calendar",
            color: .green,
            urgency: 3
        )
    }

    private func loadSummary(reset: Bool = false) async {
        if reset {
            await MainActor.run {
                summary = .empty
            }
        }

        await refreshDeckSnapshot()
        guard !Task.isCancelled else { return }

        let dueDate = await MainActor.run { deckSnapshot.dueDate }
        let planner = StudyPlanService(storage: storage)
        let plan = await planner.forecastDeckPlan(forDeckId: deck.id, dueDate: dueDate)

        guard !Task.isCancelled else { return }

        let newToday = plan.days.first?.newCount ?? 0

        await MainActor.run {
            summary = DeckSummary(
                total: plan.totalCards,
                dueToday: plan.dueToday,
                newToday: newToday,
                remainingNew: plan.activeNewCards,
                suspended: plan.suspendedCards,
                lastStudied: plan.lastStudied
            )
            lastRefreshTime = Date()
        }

        await refreshTimeEstimateIfNeeded()
    }

    @discardableResult
    private func scheduleSummaryLoad(reset: Bool = false) -> Task<Void, Never> {
        loadTask?.cancel()
        let task = Task { await loadSummary(reset: reset) }
        loadTask = task
        return task
    }

    private func refreshTimeEstimateIfNeeded() async {
        let now = Date()
        guard now.timeIntervalSince(lastEstimateRefresh) > 120 else { return }

        let logs = await ReviewLogService(storage: storage).recentLogs(limit: 300)
        let seconds = estimateSecondsPerReview(logs: logs)
        await MainActor.run {
            estimatedSecondsPerReview = seconds
            lastEstimateRefresh = now
        }
    }

    private func estimateSecondsPerReview(logs: [ReviewLog]) -> TimeInterval {
        let samples = logs
            .map { TimeInterval($0.elapsedMs) / 1000.0 }
            .filter { $0 >= 1 && $0 <= 90 }
            .sorted()
        guard !samples.isEmpty else { return 18 }
        let trim = Int(Double(samples.count) * 0.1)
        let trimmed = samples.dropFirst(trim).dropLast(trim)
        let values = trimmed.isEmpty ? samples : Array(trimmed)
        let mean = values.reduce(0, +) / Double(values.count)
        return min(max(mean, 8), 45)
    }

    private func formattedStudyEstimate(seconds: TimeInterval) -> String {
        let minutes = Int(ceil(seconds / 60.0))
        if minutes <= 1 { return "1m" }
        return "\(minutes)m"
    }

    private func beginStudy(with mode: DeckStudyMode) {
        selectedStudyMode = mode
        withAnimation(.easeInOut(duration: 0.2)) {
            activeStudyMode = mode
        }
    }

    private func endStudySession() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeStudyMode = nil
        }
        scheduleSummaryLoad()
    }
    
    private func endGameSession() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeGameMode = nil
        }
    }
    
    private func startGame(_ mode: GameMode) {
        isLoadingGame = true
        Task {
            let cards = await CardService(storage: storage).cards(deckId: deck.id)
            await MainActor.run {
                self.gameCards = cards
                self.activeGameMode = mode
                self.isLoadingGame = false
            }
        }
    }
}

private struct DeckSummary: Equatable {
    let total: Int
    let dueToday: Int
    let newToday: Int
    let remainingNew: Int
    let suspended: Int
    let lastStudied: Date?

    static let empty = DeckSummary(total: 0, dueToday: 0, newToday: 0, remainingNew: 0, suspended: 0, lastStudied: nil)
}

private struct DeckDueDescriptor {
    let countdown: String
    let absolute: String
    let icon: String
    let color: Color
    let urgency: Int
}

#if DEBUG
#Preview("DeckDetailView") {
    RevuPreviewHost { controller in
        let deck = Deck(name: "Preview Deck", note: "A deck for previewing")
        Task {
            try? await controller.storage.upsert(deck: deck.toDTO())
            let cards = [
                Card(deckId: deck.id, kind: .basic, front: "Front 1", back: "Back 1"),
                Card(deckId: deck.id, kind: .basic, front: "Front 2", back: "Back 2"),
                Card(deckId: deck.id, kind: .cloze, front: "", back: "", clozeSource: "Cloze {{c1::deletion}}"),
            ]
            for card in cards {
                try? await controller.storage.upsert(card: card.toDTO())
            }
            controller.events.notify()
        }
        return DeckDetailView(deck: deck)
            .frame(width: 1100, height: 820)
    }
}
#endif
