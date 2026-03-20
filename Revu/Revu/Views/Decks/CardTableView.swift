import SwiftUI

struct CardTableView<Header: View>: View {
    @StateObject private var viewModel: CardBrowserViewModel
    @State private var selection: Set<Card.ID> = []
    @State private var editingCard: Card?
    @State private var isCreatingCard = false
    @State private var tickRefreshTask: Task<Void, Never>?
    @State private var lastTickRefreshTime: Date = Date.distantPast
    private let header: Header

    @Environment(\.storage) private var storage
    @EnvironmentObject private var storeEvents: StoreEvents
    @EnvironmentObject private var workspaceSelection: WorkspaceSelection
    @EnvironmentObject private var workspacePreferences: WorkspacePreferences
    
    let filter: CardBrowserFilter

    init(
        filter: CardBrowserFilter,
        storage: Storage? = nil,
        @ViewBuilder header: () -> Header
    ) {
        let resolvedStorage = storage ?? DataController.shared.storage
        _viewModel = StateObject(wrappedValue: CardBrowserViewModel(filter: filter, storage: resolvedStorage))
        self.filter = filter
        self.header = header()
    }

    init(filter: CardBrowserFilter, storage: Storage? = nil) where Header == EmptyView {
        self.init(filter: filter, storage: storage) { EmptyView() }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                header

                Divider()
                    .overlay(DesignSystem.Colors.separator)

                Section {
                    ZStack {
                        Group {
                            switch workspacePreferences.cardViewMode {
                            case .grid:
                                CardGridView(
                                    cards: viewModel.cards,
                                    isLoading: viewModel.isLoading,
                                    selection: $selection,
                                    stateProvider: viewModel.state(for:),
                                    cardSizeScale: workspacePreferences.cardSizeScale,
                                    onSelect: { card in
                                        selection = [card.id]
                                        workspaceSelection.focus(on: card)
                                    },
                                    onEdit: { card in
                                        selection = [card.id]
                                        editingCard = card
                                    },
                                    onDelete: { card in
                                        viewModel.removeCard(withId: card.id)
                                        Task { await CardService(storage: storage).delete(cardId: card.id) }
                                    },
                                    onToggleSuspend: { card in
                                        var updated = card
                                        updated.isSuspended.toggle()
                                        updated.suspendedByArchive = false
                                        viewModel.updateCard(updated)
                                        Task { await CardService(storage: storage).upsert(card: updated) }
                                    }
                                )
                            case .notebook:
                                CardNotebookView(
                                    cards: viewModel.cards,
                                    isLoading: viewModel.isLoading,
                                    selection: $selection,
                                    stateProvider: viewModel.state(for:),
                                    onEdit: { card in
                                        selection = [card.id]
                                        editingCard = card
                                    },
                                    onDelete: { card in
                                        viewModel.removeCard(withId: card.id)
                                        Task { await CardService(storage: storage).delete(cardId: card.id) }
                                    },
                                    onToggleSuspend: { card in
                                        var updated = card
                                        updated.isSuspended.toggle()
                                        updated.suspendedByArchive = false
                                        viewModel.updateCard(updated)
                                        Task { await CardService(storage: storage).upsert(card: updated) }
                                    }
                                )
                            }
                        }
                        .opacity(viewModel.isLoading ? 0.4 : 1)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 0) {
                        compactControlBar
                        Divider()
                            .overlay(DesignSystem.Colors.separator)
                    }
                    .background(DesignSystem.Colors.window)
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(DesignSystem.Colors.window)
        .sheet(item: $editingCard, onDismiss: {
            Task { await viewModel.load() }
        }) { card in
            CardEditorView(card: card, storage: storage)
                .frame(minWidth: 600, minHeight: 420)
        }
        .task(id: filter) {
            await viewModel.load(for: filter)
        }
        .onReceive(storeEvents.$tick) { _ in
            scheduleTickRefresh()
        }
        .onChange(of: selection) { previous, newSelection in
            syncSelection(to: newSelection)
        }
        .onReceive(viewModel.$cards) { cards in
            workspaceSelection.restoreCard(in: cards)
            if let focused = workspaceSelection.focusedCard {
                if selection != [focused.id] {
                    selection = [focused.id]
                }
            } else if !selection.isEmpty {
                selection.removeAll()
            }
        }
        .onReceive(viewModel.$isLoading) { isLoading in
            if isLoading, !isCreatingCard {
                // Clear selection to avoid stale highlights while loading new deck,
                // but preserve selection during card creation flow
                selection.removeAll()
                workspaceSelection.clearCard()
            }
        }
    }

    private func scheduleTickRefresh() {
        guard !viewModel.isLoading else { return }

        let now = Date()
        let minInterval: TimeInterval = 0.75

        tickRefreshTask?.cancel()

        if now.timeIntervalSince(lastTickRefreshTime) < minInterval {
            tickRefreshTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(minInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await viewModel.load()
                lastTickRefreshTime = Date()
            }
        } else {
            lastTickRefreshTime = now
            tickRefreshTask = Task { @MainActor in
                await viewModel.load()
            }
        }
    }
    
    // Compact control bar with better spacing
    private var compactControlBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Search field
            compactSearchField
                .frame(maxWidth: 320)

            Spacer(minLength: 0)

            // Size slider — grid mode only
            if workspacePreferences.cardViewMode == .grid {
                CardSizeSlider(value: $workspacePreferences.cardSizeScale)
                    .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .trailing)))
            }

            // View mode picker
            compactViewModePicker

            // New card button
            compactNewCardButton
        }
        .animation(DesignSystem.Animation.quick, value: workspacePreferences.cardViewMode)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.window)
    }
    
    private var compactSearchField: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            
            TextField("Search cards...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
            
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    private var compactViewModePicker: some View {
        HStack(spacing: 6) {
            ForEach(CardViewMode.allCases) { mode in
                Button {
                    workspacePreferences.cardViewMode = mode
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(workspacePreferences.cardViewMode == mode ? .primary : DesignSystem.Colors.tertiaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(workspacePreferences.cardViewMode == mode ? DesignSystem.Colors.subtleOverlay : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var compactNewCardButton: some View {
        Button {
            createCard()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                Text("New Card")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.primaryText.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Colors.separator.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // Legacy control bars kept for backward compatibility
    private var controlBarHorizontal: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            searchField
                .layoutPriority(1)

            Spacer(minLength: 0)

            viewModePicker

            optionsMenu

            newCardButton
        }
    }

    private var controlBarVertical: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            searchField
            HStack(spacing: DesignSystem.Spacing.md) {
                viewModePicker
                optionsMenu
                newCardButton
                Spacer(minLength: 0)
            }
        }
    }

    private var controlBarStacked: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            searchField
            viewModePicker
                .frame(maxWidth: .infinity, alignment: .leading)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    optionsMenu
                    newCardButton
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    optionsMenu
                    newCardButton
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(DesignSystem.Typography.caption)
            
            TextField("Search cards...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
            
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(DesignSystem.Typography.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .frame(minWidth: 200, maxWidth: 420, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    private var viewModePicker: some View {
        Picker("View", selection: $workspacePreferences.cardViewMode) {
            ForEach(CardViewMode.allCases) { mode in
                Label(mode.title, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(minWidth: 150, idealWidth: 200, maxWidth: 240)
        .labelsHidden()
    }

    private var optionsMenu: some View {
        Menu {
            Button("Refresh") { viewModel.refresh() }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.hoverBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help("View Options")
    }

    private var newCardButton: some View {
        Button {
            createCard()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "plus")
                    .font(DesignSystem.Typography.captionMedium)
                Text("New Card")
                    .font(DesignSystem.Typography.bodyMedium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(Color.accentColor)
            )
            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contextMenu(for card: Card) -> some View {
        Button("Edit") {
            selection = [card.id]
            editingCard = card
        }
        Button(card.isSuspended ? "Unsuspend" : "Suspend") {
            Task {
                var updated = card
                updated.isSuspended.toggle()
                updated.suspendedByArchive = false
                await CardService(storage: storage).upsert(card: updated)
                await viewModel.load()
            }
        }
        Button("Delete", role: .destructive) {
            Task {
                await CardService(storage: storage).delete(cardId: card.id)
                await viewModel.load()
            }
        }
    }

    private func syncSelection(to ids: Set<Card.ID>) {
        guard let id = ids.first, let card = viewModel.cards.first(where: { $0.id == id }) else {
            workspaceSelection.clearCard()
            return
        }
        workspaceSelection.focus(on: card)
    }

    private func color(for state: SRSState) -> Color {
        switch state.queue {
        case .new: return Color.accentColor
        case .learning, .relearn: return .orange
        case .review: return .secondary
        }
    }

    private func createCard() {
        switch viewModel.filter {
        case .deck(let deckId):
            Task {
                guard let deck = await viewModel.deck(for: deckId) else { return }
                var card = Card(deckId: deck.id, kind: .basic, front: "", back: "")
                card.srs.cardId = card.id
                await CardService(storage: storage).upsert(card: card)
                isCreatingCard = true
                await viewModel.load()
                await MainActor.run {
                    selection = [card.id]
                    workspaceSelection.focus(on: card)
                    editingCard = card
                    isCreatingCard = false
                }
            }
        default:
            break
        }
    }
}

// MARK: - Card Size Slider

private struct CardSizeSlider: View {
    @Binding var value: Double
    /// Local draft updated on every drag event — committed to `value` only on drag end
    /// so the expensive CardGridView re-layout happens once, not 60× per second.
    @State private var localValue: Double

    @State private var isDragging = false
    @State private var isHovering = false

    private static let trackWidth: CGFloat = 80
    private static let knobSize: CGFloat = 13
    private static let trackHeight: CGFloat = 3

    init(value: Binding<Double>) {
        self._value = value
        self._localValue = State(initialValue: value.wrappedValue)
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.tertiaryText.opacity(0.7))

            sliderTrack

            Image(systemName: "square.grid.2x2")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.tertiaryText.opacity(0.7))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .onChange(of: value) { _, newValue in
            if !isDragging { localValue = newValue }
        }
        .background(
            Capsule()
                .fill(DesignSystem.Colors.primaryText.opacity(0.05))
        )
        .overlay(
            Capsule()
                .stroke(DesignSystem.Colors.separator.opacity(0.25), lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovering = hovering
            }
        }
    }

    private var sliderTrack: some View {
        ZStack(alignment: .leading) {
            // Background track
            Capsule()
                .fill(DesignSystem.Colors.separator.opacity(0.35))
                .frame(width: Self.trackWidth, height: Self.trackHeight)

            // Emerald filled portion
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.studyAccentDeep.opacity(0.9),
                            DesignSystem.Colors.studyAccentBright
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width: max(Self.knobSize * 0.4, CGFloat(localValue) * Self.trackWidth),
                    height: Self.trackHeight
                )

            // Knob — uses localValue so only this view re-renders during drag
            knob
                .offset(x: CGFloat(localValue) * (Self.trackWidth - Self.knobSize))
        }
        .frame(width: Self.trackWidth, height: Self.knobSize)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    if !isDragging { isDragging = true }
                    let usable = Self.trackWidth - Self.knobSize
                    let raw = (gesture.location.x - Self.knobSize * 0.5) / usable
                    localValue = min(max(raw, 0), 1)
                }
                .onEnded { _ in
                    isDragging = false
                    value = localValue  // single write → single grid re-layout
                }
        )
    }

    private var knob: some View {
        ZStack {
            // Base with subtle top-to-bottom gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(white: 0.91)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Emerald ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.studyAccentBright
                                .opacity(isDragging ? 0.95 : (isHovering ? 0.80 : 0.60)),
                            DesignSystem.Colors.studyAccentDeep.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            // Grip knubs — two vertical capsules
            HStack(spacing: 2.5) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule()
                        .fill(
                            DesignSystem.Colors.studyAccentBright
                                .opacity(isDragging ? 0.75 : 0.45)
                        )
                        .frame(width: 1.5, height: 5)
                }
            }
        }
        .frame(width: Self.knobSize, height: Self.knobSize)
        .scaleEffect(isDragging ? 1.20 : (isHovering ? 1.09 : 1.0))
        .shadow(
            color: DesignSystem.Colors.studyAccentGlow
                .opacity(isDragging ? 0.55 : (isHovering ? 0.38 : 0.18)),
            radius: isDragging ? 9 : (isHovering ? 5 : 3),
            x: 0,
            y: isDragging ? 4 : 2
        )
        .animation(DesignSystem.Animation.quick, value: isDragging)
        .animation(DesignSystem.Animation.quick, value: isHovering)
    }
}

// MARK: -

enum CardBrowserFilter: Hashable {
    case deck(UUID)
    case tag(String)
    case smart(SmartFilter)
}

enum SmartFilter: String, CaseIterable, Identifiable {
    case dueToday
    case new
    case suspended

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dueToday: return "Due Today"
        case .new: return "New"
        case .suspended: return "Suspended"
        }
    }
}

// MARK: - Previews

#Preview("CardTableView – Smart: New") {
    let controller = DataController.previewController()
    return CardTableView(filter: .smart(.new), storage: controller.storage)
        .environment(\.storage, controller.storage)
        .environmentObject(StoreEvents())
        .environmentObject(WorkspaceSelection())
        .environmentObject(WorkspacePreferences())
        .frame(minWidth: 900, minHeight: 500)
        .padding()
}

#Preview("CardTableView – Tag Filter") {
    let controller = DataController.previewController()
    // Seed a tagged card for the preview
    Task {
        var card = Card(deckId: nil, kind: .basic, front: "Tagged Front", back: "Tagged Back")
        card.tags = ["demo"]
        card.srs.cardId = card.id
        await CardService(storage: controller.storage).upsert(card: card)
    }
    return CardTableView(filter: .tag("demo"), storage: controller.storage)
        .environment(\.storage, controller.storage)
        .environmentObject(StoreEvents())
        .environmentObject(WorkspaceSelection())
        .environmentObject(WorkspacePreferences())
        .frame(minWidth: 900, minHeight: 500)
        .padding()
}
