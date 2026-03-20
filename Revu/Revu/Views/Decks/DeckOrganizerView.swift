import SwiftUI
import UniformTypeIdentifiers

struct DeckOrganizerView: View {
    @EnvironmentObject private var storeEvents: StoreEvents
    @StateObject private var viewModel: DeckOrganizerViewModel
    
    // Drag state - simplified for reliability
    @State private var draggedDeckId: UUID?
    @State private var dropTargetId: UUID?
    @State private var dropRegion: DeckOrganizerViewModel.DropRegion?
    
    // Merge confirmation
    @State private var pendingMerge: PendingMerge?

    let onOpenDeck: (Deck) -> Void
    let onNewDeck: () -> Void
    let onNewSubdeck: (Deck) -> Void
    let onRenameDeck: (Deck) -> Void
    let onArchiveDeck: (Deck) -> Void
    let onUnarchiveDeck: (Deck) -> Void
    let onDeleteDeck: (Deck) -> Void
    let onMergeDecks: (Deck, Deck) -> Void

    init(
        storage: Storage? = nil,
        onOpenDeck: @escaping (Deck) -> Void,
        onNewDeck: @escaping () -> Void,
        onNewSubdeck: @escaping (Deck) -> Void,
        onRenameDeck: @escaping (Deck) -> Void,
        onArchiveDeck: @escaping (Deck) -> Void,
        onUnarchiveDeck: @escaping (Deck) -> Void,
        onDeleteDeck: @escaping (Deck) -> Void,
        onMergeDecks: @escaping (Deck, Deck) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: DeckOrganizerViewModel(storage: storage ?? DataController.shared.storage))
        self.onOpenDeck = onOpenDeck
        self.onNewDeck = onNewDeck
        self.onNewSubdeck = onNewSubdeck
        self.onRenameDeck = onRenameDeck
        self.onArchiveDeck = onArchiveDeck
        self.onUnarchiveDeck = onUnarchiveDeck
        self.onDeleteDeck = onDeleteDeck
        self.onMergeDecks = onMergeDecks
    }

    var body: some View {
        WorkspaceCanvas { width in
            headerSection
            deckListSection
        }
        .background(DesignSystem.Colors.canvasBackground)
        .task { viewModel.refresh() }
        .onReceive(storeEvents.$tick) { _ in viewModel.refresh() }
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

// MARK: - Pending Merge

private struct PendingMerge: Identifiable {
    let source: Deck
    let target: Deck
    var id: String { "\(source.id)-\(target.id)" }
}

// MARK: - Header Section

private extension DeckOrganizerView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Title row
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs * 0.75) {
                    HStack(spacing: DesignSystem.Spacing.xs * 0.5) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        Text("Deck organizer")
                            .font(DesignSystem.Typography.smallMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .textCase(.uppercase)
                            .tracking(0.9)
                    }
                    Text("Your Library")
                        .font(DesignSystem.Typography.hero)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }

                Spacer(minLength: DesignSystem.Spacing.md)

                Button(action: onNewDeck) {
                    Label("New Deck", systemImage: "plus")
                        .font(DesignSystem.Typography.bodyMedium)
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Controls row
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Search
                searchField
                
                Spacer()
                
                // Mode picker
                Picker("Mode", selection: $viewModel.dragMode) {
                    ForEach(DeckOrganizerViewModel.DragMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                // Archived toggle
                Toggle(isOn: $viewModel.includeArchived) {
                    Label("Archived", systemImage: "archivebox")
                        .labelStyle(.titleAndIcon)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    var searchField: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            TextField("Search decks...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, 10)
        .frame(maxWidth: 300)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.hoverBackground)
        )
    }
}

// MARK: - Deck List Section

private extension DeckOrganizerView {
    var deckListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading && viewModel.rows.isEmpty {
                emptyState(icon: "arrow.clockwise", message: "Loading decks...")
            } else if viewModel.rows.isEmpty {
                emptyState(
                    icon: viewModel.searchText.isEmpty ? "rectangle.3.group" : "magnifyingglass",
                    message: viewModel.searchText.isEmpty
                        ? "Create your first deck to get started"
                        : "No decks match your search"
                )
            } else {
                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ForEach(viewModel.rows) { row in
                        deckRow(for: row)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.canvasBackground)
        )
        .animation(DesignSystem.Animation.layout, value: viewModel.rows.map(\.id))
    }
    
    func deckRow(for row: DeckOrganizerViewModel.DeckRow) -> some View {
        let isBeingDragged = draggedDeckId == row.deck.id
        let isDropTarget = dropTargetId == row.deck.id
        let isNestTarget = isDropTarget && dropRegion == .nest
        let showInsertBefore = isDropTarget && dropRegion == .before
        let showInsertAfter = isDropTarget && dropRegion == .after
        
        return VStack(spacing: 0) {
            // Insertion indicator before
            if showInsertBefore {
                insertionIndicator(depth: row.depth)
            }
            
            DeckOrganizerRowView(
                row: row,
                snapshot: viewModel.snapshots[row.deck.id] ?? DeckOrganizerViewModel.DeckActivitySnapshot(),
                isBeingDragged: isBeingDragged,
                isNestTarget: isNestTarget,
                onToggleExpanded: { viewModel.toggleExpanded(row.deck.id) },
                onOpen: { onOpenDeck(row.deck) },
                onNewSubdeck: { onNewSubdeck(row.deck) },
                onRename: { onRenameDeck(row.deck) },
                onArchiveToggle: {
                    row.deck.isArchived ? onUnarchiveDeck(row.deck) : onArchiveDeck(row.deck)
                },
                onDelete: { onDeleteDeck(row.deck) }
            )
            .draggable(DeckDragPayload(id: row.deck.id)) {
                DeckDragPreview(name: row.deck.name, hasChildren: row.hasChildren)
                    .onAppear { draggedDeckId = row.deck.id }
            }
            .dropDestination(for: DeckDragPayload.self) { items, location in
                handleDrop(items: items, targetRow: row, location: location)
            } isTargeted: { isTargeted in
                handleDropTargeting(isTargeted: isTargeted, targetRow: row)
            }
            
            // Insertion indicator after
            if showInsertAfter {
                insertionIndicator(depth: row.depth)
            }
        }
    }
    
    func insertionIndicator(depth: Int) -> some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 3)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
        }
        .padding(.leading, CGFloat(depth) * 20 + DesignSystem.Spacing.md)
        .padding(.trailing, DesignSystem.Spacing.md)
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            
            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

// MARK: - Drop Handling

private extension DeckOrganizerView {
    func handleDropTargeting(isTargeted: Bool, targetRow: DeckOrganizerViewModel.DeckRow) {
        if isTargeted {
            dropTargetId = targetRow.deck.id
            // Default to nest when first targeted; actual region determined on drop
            dropRegion = viewModel.dragMode == .merge ? .nest : .nest
        } else if dropTargetId == targetRow.deck.id {
            dropTargetId = nil
            dropRegion = nil
        }
    }
    
    func handleDrop(items: [DeckDragPayload], targetRow: DeckOrganizerViewModel.DeckRow, location: CGPoint) -> Bool {
        defer {
            // Always clean up drag state
            draggedDeckId = nil
            dropTargetId = nil
            dropRegion = nil
        }
        
        guard let payload = items.first,
              let sourceDeck = viewModel.deck(id: payload.id),
              sourceDeck.id != targetRow.deck.id else {
            return false
        }
        
        // Merge mode - show confirmation
        if viewModel.dragMode == .merge {
            pendingMerge = PendingMerge(source: sourceDeck, target: targetRow.deck)
            return true
        }
        
        // Organize mode
        let rowHeight: CGFloat = 52
        _ = DeckOrganizerViewModel.dropRegion(locationY: location.y, rowHeight: rowHeight)

        return viewModel.handleDrop(
            payloads: items,
            targetDeckId: targetRow.deck.id,
            locationY: location.y,
            rowHeight: rowHeight,
            onMergeDecks: { source, target in
                pendingMerge = PendingMerge(source: source, target: target)
            }
        )
    }
}

// MARK: - Deck Row View

private struct DeckOrganizerRowView: View {
    private enum Constants {
        static let rowHeight: CGFloat = 52
        static let indentUnit: CGFloat = 20
    }

    let row: DeckOrganizerViewModel.DeckRow
    let snapshot: DeckOrganizerViewModel.DeckActivitySnapshot
    let isBeingDragged: Bool
    let isNestTarget: Bool
    let onToggleExpanded: () -> Void
    let onOpen: () -> Void
    let onNewSubdeck: () -> Void
    let onRename: () -> Void
    let onArchiveToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            disclosureButton
            deckIcon
            deckInfo
            Spacer(minLength: DesignSystem.Spacing.sm)
            activityBadges
        }
        .frame(height: Constants.rowHeight)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.leading, CGFloat(row.depth) * Constants.indentUnit)
        .contentShape(Rectangle())
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .overlay(rowBorder)
        .opacity(isBeingDragged ? 0.4 : 1)
        .scaleEffect(isBeingDragged ? 0.98 : 1)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onOpen)
        .contextMenu { contextMenuItems }
        .animation(.snappy(duration: 0.2), value: isBeingDragged)
        .animation(.snappy(duration: 0.2), value: isNestTarget)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    @ViewBuilder
    private var disclosureButton: some View {
        if row.hasChildren {
            Button(action: onToggleExpanded) {
                Image(systemName: row.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 20, height: 20)
        }
    }

    private var deckIcon: some View {
        Image(systemName: row.hasChildren ? "folder.fill" : "rectangle.stack.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isNestTarget ? Color.accentColor : (row.deck.isArchived ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.secondaryText))
            .frame(width: 24, height: 24)
    }
    
    private var deckInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(row.deck.name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(row.deck.isArchived ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.primaryText)
                    .lineLimit(1)
                
                if row.deck.isArchived {
                    Text("Archived")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(DesignSystem.Colors.subtleOverlay))
                }
            }

            if row.depth > 0 {
                Text(row.displayPath)
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var activityBadges: some View {
        HStack(spacing: 6) {
            if snapshot.dueTotal > 0 {
                ActivityBadge(
                    label: "DUE",
                    value: snapshot.dueTotal,
                    tint: snapshot.overdue > 0 ? .red : .orange
                )
            }
            if snapshot.new > 0 {
                ActivityBadge(
                    label: "NEW",
                    value: snapshot.new,
                    tint: .blue
                )
            }
            if snapshot.total > 0 {
                Text("\(snapshot.total)")
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
        }
        .opacity(row.deck.isArchived ? 0.5 : 1)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isNestTarget {
            return Color.accentColor.opacity(0.12)
        }
        if isHovered {
            return DesignSystem.Colors.hoverBackground
        }
        return DesignSystem.Colors.window.opacity(0.6)
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
            .strokeBorder(isNestTarget ? Color.accentColor.opacity(0.5) : DesignSystem.Colors.separator.opacity(0.4), lineWidth: isNestTarget ? 2 : 1)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: onOpen) {
            Label("Open Deck", systemImage: "arrow.forward")
        }

        Divider()

        Button(action: onNewSubdeck) {
            Label("New Subdeck...", systemImage: "plus.rectangle.on.folder")
        }

        Button(action: onRename) {
            Label("Rename...", systemImage: "pencil")
        }

        Divider()

        Button(action: onArchiveToggle) {
            Label(
                row.deck.isArchived ? "Restore from Archive" : "Archive Deck",
                systemImage: row.deck.isArchived ? "tray.and.arrow.up" : "archivebox"
            )
        }

        Button(role: .destructive, action: onDelete) {
            Label("Delete Deck...", systemImage: "trash")
        }
    }
}

// MARK: - Activity Badge

private struct ActivityBadge: View {
    let label: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tint.opacity(0.1))
        )
    }
}

// MARK: - Drag Preview

private struct DeckDragPreview: View {
    let name: String
    let hasChildren: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: hasChildren ? "folder.fill" : "rectangle.stack.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(name)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Previews

#Preview("DeckOrganizerView - Dark") {
    let controller = DataController.previewController()
    return DeckOrganizerView(
        storage: controller.storage,
        onOpenDeck: { _ in },
        onNewDeck: {},
        onNewSubdeck: { _ in },
        onRenameDeck: { _ in },
        onArchiveDeck: { _ in },
        onUnarchiveDeck: { _ in },
        onDeleteDeck: { _ in },
        onMergeDecks: { _, _ in }
    )
    .environmentObject(controller.events)
    .frame(minWidth: 900, minHeight: 600)
    .preferredColorScheme(.dark)
}

#Preview("DeckOrganizerView - Light") {
    let controller = DataController.previewController()
    return DeckOrganizerView(
        storage: controller.storage,
        onOpenDeck: { _ in },
        onNewDeck: {},
        onNewSubdeck: { _ in },
        onRenameDeck: { _ in },
        onArchiveDeck: { _ in },
        onUnarchiveDeck: { _ in },
        onDeleteDeck: { _ in },
        onMergeDecks: { _, _ in }
    )
    .environmentObject(controller.events)
    .frame(minWidth: 900, minHeight: 600)
    .preferredColorScheme(.light)
}

#Preview("DeckOrganizerView - Compact") {
    let controller = DataController.previewController()
    return DeckOrganizerView(
        storage: controller.storage,
        onOpenDeck: { _ in },
        onNewDeck: {},
        onNewSubdeck: { _ in },
        onRenameDeck: { _ in },
        onArchiveDeck: { _ in },
        onUnarchiveDeck: { _ in },
        onDeleteDeck: { _ in },
        onMergeDecks: { _, _ in }
    )
    .environmentObject(controller.events)
    .frame(minWidth: 600, minHeight: 400)
    .preferredColorScheme(.dark)
}

#Preview("ActivityBadge - States") {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
        HStack(spacing: DesignSystem.Spacing.md) {
            ActivityBadge(label: "DUE", value: 12, tint: .orange)
            ActivityBadge(label: "DUE", value: 5, tint: .red)
            ActivityBadge(label: "NEW", value: 24, tint: .blue)
        }
        
        HStack(spacing: DesignSystem.Spacing.md) {
            ActivityBadge(label: "DUE", value: 0, tint: .orange)
            ActivityBadge(label: "NEW", value: 0, tint: .blue)
        }
        
        Text("1234")
            .font(DesignSystem.Typography.small)
            .foregroundStyle(DesignSystem.Colors.tertiaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DesignSystem.Colors.subtleOverlay, in: Capsule())
    }
    .padding(DesignSystem.Spacing.xl)
    .background(DesignSystem.Colors.canvasBackground)
    .preferredColorScheme(.dark)
}

#Preview("DeckDragPreview") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        DeckDragPreview(name: "JavaScript Fundamentals", hasChildren: true)
        DeckDragPreview(name: "React Hooks Deep Dive", hasChildren: false)
        DeckDragPreview(name: "Advanced TypeScript Patterns", hasChildren: true)
    }
    .padding(DesignSystem.Spacing.xl)
    .background(DesignSystem.Colors.canvasBackground)
    .preferredColorScheme(.dark)
}
