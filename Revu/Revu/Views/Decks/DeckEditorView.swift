import SwiftUI

struct DeckEditorView: View {
    enum Mode {
        case create
        case edit

        func title(for kind: Deck.Kind) -> String {
            switch self {
            case .create:
                return kind == .folder ? "New Folder" : "New Deck"
            case .edit:
                return kind == .folder ? "Edit Folder" : "Edit Deck"
            }
        }

        var actionTitle: String {
            switch self {
            case .create:
                return "Create"
            case .edit:
                return "Save"
            }
        }
        
        func icon(for kind: Deck.Kind) -> String {
            switch self {
            case .create:
                return kind == .folder ? "folder.badge.plus" : "plus.rectangle.on.folder"
            case .edit:
                return "folder"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.storage) private var storage

    private let mode: Mode
    private let originalDeck: Deck?
    private let defaultParentId: UUID?
    private let defaultKind: Deck.Kind
    private let onSave: (Deck) -> Void

    @State private var name: String
    @State private var note: String
    @State private var dueDate: Date
    @State private var isDueDateEnabled: Bool
    @State private var selectedParentId: UUID?
    @State private var availableParents: [Deck] = []
    @State private var allDecks: [Deck] = []
    @State private var hierarchy: DeckHierarchy = DeckHierarchy(decks: [])
    @State private var validationMessage: String?
    @State private var isAppearing = false
    @State private var activeSection: DeckSection? = nil
    @State private var isDueDatePickerPresented = false
    @State private var datePickerSessionId = UUID()
    @FocusState private var isNameFocused: Bool
    
    private enum DeckSection: Hashable {
        case name, location, schedule, notes
    }

    init(deck: Deck? = nil, defaultParentId: UUID? = nil, defaultKind: Deck.Kind = .deck, onSave: @escaping (Deck) -> Void) {
        self.originalDeck = deck
        self.mode = deck == nil ? .create : .edit
        self.defaultParentId = defaultParentId
        self.defaultKind = deck?.kind ?? defaultKind
        self.onSave = onSave
        let calendar = Calendar.current
        let defaultDue = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: Date())) ?? Date()
        _name = State(initialValue: deck?.name ?? "")
        _note = State(initialValue: deck?.note ?? "")
        _dueDate = State(initialValue: deck?.dueDate.map { calendar.startOfDay(for: $0) } ?? defaultDue)
        _isDueDateEnabled = State(initialValue: deck?.dueDate != nil)
        _selectedParentId = State(initialValue: deck?.parentId ?? defaultParentId)
    }

    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    headerSection
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.top, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.lg)
                    
                    // Name Section
                    nameSection
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.md)
                        .offset(y: isAppearing ? 0 : 15)
                        .opacity(isAppearing ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05), value: isAppearing)

                    // Location Section
                    locationSection
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.md)
                        .offset(y: isAppearing ? 0 : 15)
                        .opacity(isAppearing ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.08), value: isAppearing)
                    
                    // Schedule Section (only for decks, not folders)
                    if defaultKind != .folder {
                        scheduleSection
                            .padding(.horizontal, DesignSystem.Spacing.xl)
                            .padding(.bottom, DesignSystem.Spacing.md)
                            .offset(y: isAppearing ? 0 : 15)
                            .opacity(isAppearing ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1), value: isAppearing)
                    }
                    
                    // Notes Section
                    notesSection
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.xxl)
                        .offset(y: isAppearing ? 0 : 15)
                        .opacity(isAppearing ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.15), value: isAppearing)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 440)
        .onAppear {
            isNameFocused = true
            withAnimation(.easeOut(duration: 0.4)) {
                isAppearing = true
            }
            Task { await loadParents() }
        }
        .onChange(of: name, initial: false) { _, _ in
            validateName()
        }
        .onChange(of: selectedParentId, initial: false) { _, _ in
            validateName()
        }
        .sheet(isPresented: $isDueDatePickerPresented) {
            DesignSystemDatePickerSurface(
                title: defaultKind == .folder ? "Folder Due Date" : "Deck Due Date",
                selectedDate: $dueDate,
                allowClear: true,
                helpText: "FSRS will adapt your review schedule to help you master all cards before this date.",
                onSave: { newDate in
                    if let newDate {
                        dueDate = newDate
                        isDueDateEnabled = true
                    } else {
                        isDueDateEnabled = false
                    }
                },
                onDismiss: {
                    isDueDatePickerPresented = false
                }
            )
            .id(datePickerSessionId)
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            DesignSystem.Colors.canvasBackground
            
            // Subtle gradient
            RadialGradient(
                colors: [
                    DesignSystem.Colors.subtleOverlay,
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 350
            )
            .opacity(0.6)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.lg) {
            // Left side: Icon and title
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.subtleOverlay)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: mode.icon(for: defaultKind))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title(for: defaultKind))
                        .font(DesignSystem.Typography.heading)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    
                    if mode == .edit, let deck = originalDeck {
                        Text("Created \(deck.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    } else {
                        Text(defaultKind == .folder ? "Organize your decks" : "Organize your flashcards")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    }
                }
            }
            
            Spacer()
            
            // Right side: Action buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.hoverBackground)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                
                Button(action: { Task { await saveDeck() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode == .create ? "plus" : "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text(mode.actionTitle)
                            .font(DesignSystem.Typography.bodyMedium)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(canSave ? DesignSystem.Colors.primaryText : DesignSystem.Colors.tertiaryText)
                    )
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(PremiumDeckButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
    }
    
    // MARK: - Name Section
    
    private var nameSection: some View {
        DeckSectionCard(
            title: "Name",
            icon: "textformat",
            isActive: activeSection == .name
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                DesignSystemTextField(
                    placeholder: "Enter deck name...",
                    text: $name
                )
                .focused($isNameFocused)
                
                if name.isEmpty {
                    Text("Give your deck a memorable name")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .padding(.leading, DesignSystem.Spacing.xs)
                } else if let validationMessage {
                    Text(validationMessage)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.orange)
                        .padding(.leading, DesignSystem.Spacing.xs)
                }
            }
        }
        .onTapGesture {
            withAnimation(DesignSystem.Animation.quick) {
                activeSection = .name
                isNameFocused = true
            }
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        DeckSectionCard(
            title: "Location",
            icon: "folder",
            isActive: activeSection == .location
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)

                    Picker("Parent deck", selection: $selectedParentId) {
                        Text("Root").tag(UUID?.none)
                        ForEach(availableParents) { parent in
                            Text(hierarchy.displayPath(of: parent.id))
                                .tag(Optional(parent.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()
                }

                Text(locationPreview)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .lineLimit(2)
            }
        }
        .onTapGesture {
            withAnimation(DesignSystem.Animation.quick) {
                activeSection = .location
            }
        }
    }

    private var locationPreview: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let verb = mode == .create ? "Creates" : "Saves"
        guard let parentId = selectedParentId else {
            return trimmed.isEmpty ? "\(verb) at the root level." : "\(verb) a root deck named “\(trimmed)”."
        }
        let parentPath = hierarchy.displayPath(of: parentId)
        guard !parentPath.isEmpty else { return trimmed.isEmpty ? "\(verb) as a subdeck." : "\(verb) a subdeck named “\(trimmed)”." }
        return trimmed.isEmpty ? "\(verb) a subdeck under \(parentPath)." : "\(verb) \(parentPath) / \(trimmed)."
    }
    
    // MARK: - Schedule Section
    
    private var scheduleSection: some View {
        DeckSectionCard(
            title: "Schedule",
            icon: "calendar",
            isActive: activeSection == .schedule,
            badge: isDueDateEnabled ? dueDateBadge : nil
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Toggle with custom styling
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Track due date")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                        Text("Set a target completion date")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    }
                    
                    Spacer()
                    
                    DesignSystemToggle(isOn: $isDueDateEnabled.animation(.spring(response: 0.35, dampingFraction: 0.8)))
                }
                
                // Due date picker with animation
                if isDueDateEnabled {
                    dueDateContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onTapGesture {
            withAnimation(DesignSystem.Animation.quick) {
                activeSection = .schedule
            }
        }
    }
    
    private var dueDateBadge: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "\(days) days"
    }
    
    private var dueDateContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Date display row with edit button
            Button {
                datePickerSessionId = UUID()
                isDueDatePickerPresented = true
            } label: {
                HStack {
                    Label("Due date", systemImage: "calendar")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    
                    Spacer()
                    
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.hoverBackground)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Countdown display
            DueDateCountdown(target: dueDate)
            
            // Info callout
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                
                Text("FSRS will adapt your review schedule to help you master all cards before this date.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(DesignSystem.Colors.subtleOverlay)
            )
            
            // Clear button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isDueDateEnabled = false
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14))
                    Text("Clear due date")
                        .font(DesignSystem.Typography.body)
                }
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        DeckSectionCard(
            title: "Notes",
            icon: "text.alignleft",
            isActive: activeSection == .notes,
            isOptional: true
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                DesignSystemTextField(
                    placeholder: "Add notes about this deck...",
                    text: $note,
                    axis: .vertical,
                    lineLimit: 3...6
                )
                
                Text("Notes are only visible to you")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .padding(.leading, DesignSystem.Spacing.xs)
            }
        }
        .onTapGesture {
            withAnimation(DesignSystem.Animation.quick) {
                activeSection = .notes
            }
        }
    }
    
    // MARK: - Helpers
    
    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !trimmed.contains("::") else { return false }
        return validationMessage == nil
    }

    private func normalizedDueDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        if let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) {
            return endOfDay
        }
        return date
    }

    private func saveDeck() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        var deck = originalDeck ?? Deck(kind: defaultKind, name: trimmedName)
        deck.name = trimmedName
        deck.parentId = selectedParentId
        deck.note = trimmedNote.isEmpty ? nil : trimmedNote
        deck.dueDate = isDueDateEnabled ? normalizedDueDate(dueDate) : nil
        deck.updatedAt = Date()

        await DeckService(storage: storage).upsert(deck: deck)
        await MainActor.run {
            onSave(deck)
            dismiss()
        }
    }

    private func loadParents() async {
        let allDecks = await DeckService(storage: storage).allDecks(includeArchived: true)
        let resolvedHierarchy = DeckHierarchy(decks: allDecks)
        let currentIsArchived = originalDeck?.isArchived ?? false

        let excluded: Set<UUID> = {
            guard let deck = originalDeck else { return [] }
            let descendantIds = Set(resolvedHierarchy.descendants(of: deck.id).map(\.id))
            return descendantIds.union([deck.id])
        }()

        let candidates = allDecks
            .filter { $0.isArchived == currentIsArchived }
            .filter { !excluded.contains($0.id) }
            .sorted { resolvedHierarchy.displayPath(of: $0.id).localizedCaseInsensitiveCompare(resolvedHierarchy.displayPath(of: $1.id)) == .orderedAscending }

        await MainActor.run {
            hierarchy = resolvedHierarchy
            self.allDecks = allDecks.filter { $0.isArchived == currentIsArchived }
            availableParents = candidates
            if let selectedParentId, !candidates.contains(where: { $0.id == selectedParentId }) {
                self.selectedParentId = nil
            }
            validateName()
        }
    }

    private func validateName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("::") {
            validationMessage = "Deck names can’t contain “::”."
            return
        }
        let siblingCandidates = allDecks.filter { deck in
            deck.parentId == selectedParentId && deck.id != originalDeck?.id
        }
        if siblingCandidates.contains(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            validationMessage = "A deck with this name already exists here."
            return
        }
        validationMessage = nil
    }
}

// MARK: - Supporting Components

private struct DeckSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let isActive: Bool
    var badge: String? = nil
    var isOptional: Bool = false
    @ViewBuilder let content: Content
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isActive ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                
                Text(title.uppercased())
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(isActive ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                    .tracking(0.8)
                
                if isOptional {
                    Text("Optional")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.subtleOverlay)
                        )
                }
                
                Spacer()
                
                if let badge {
                    Text(badge)
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.hoverBackground)
                        )
                }
            }
            
            content
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.08 : 0.04),
                    radius: isHovered ? 16 : 8,
                    x: 0,
                    y: isHovered ? 6 : 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .stroke(
                    isActive ? DesignSystem.Colors.primaryText.opacity(0.12) : DesignSystem.Colors.separator,
                    lineWidth: isActive ? 1.5 : 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(DesignSystem.Animation.quick, value: isHovered)
        .animation(DesignSystem.Animation.quick, value: isActive)
    }
}

private struct DueDateCountdown: View {
    let target: Date
    
    private var daysRemaining: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: target)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
    
    private var countdownColor: Color {
        if daysRemaining <= 0 { return .red }
        if daysRemaining <= 3 { return .orange }
        return .green
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.separator, lineWidth: 4)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .trim(from: 0, to: min(1, Double(max(0, daysRemaining)) / 30.0))
                    .stroke(countdownColor.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                
                Text("\(max(0, daysRemaining))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(countdownText)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                Text(target.formatted(date: .complete, time: .omitted))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(countdownColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(countdownColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var countdownText: String {
        if daysRemaining <= 0 { return "Due today" }
        if daysRemaining == 1 { return "Due tomorrow" }
        return "\(daysRemaining) days remaining"
    }
}

private struct PremiumDeckButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview("DeckEditorView – Create") {
    RevuPreviewHost { _ in
        DeckEditorView(onSave: { _ in })
            .frame(width: 720, height: 680)
    }
}

#Preview("DeckEditorView – Edit") {
    RevuPreviewHost { controller in
        let deck = Deck(name: "Biology", note: "Cellular respiration")
        Task {
            try? await controller.storage.upsert(deck: deck.toDTO())
            controller.events.notify()
        }
        return DeckEditorView(deck: deck, onSave: { _ in })
            .frame(width: 720, height: 680)
    }
}
#endif
