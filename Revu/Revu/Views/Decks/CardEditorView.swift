import SwiftUI

struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let storage: Storage
    @State private var card: Card
    @State private var availableTags: [String] = []
    @State private var deckName: String = "Unassigned Deck"
    
    // Animation states
    @State private var isAppearing = false
    @State private var activeSection: EditorSection? = nil
    @FocusState private var focusedField: FocusedField?
    
    private enum FocusedField: Hashable {
        case front, back, clozeSource, prompt, explanation
        case choice(Int)
    }
    
    private enum EditorSection: Hashable {
        case type, content, tags, media
    }

    init(card: Card, storage: Storage) {
        self._card = State(initialValue: card)
        self.storage = storage
    }

    init(card: Card) {
        self.init(card: card, storage: DataController.shared.storage)
    }

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Premium header with blur effect
                    headerSection
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.top, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.md)
                    
                    // Card type selector with pill design
                    cardTypeSelector
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.lg)
                        .offset(y: isAppearing ? 0 : 20)
                        .opacity(isAppearing ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: isAppearing)
                    
                    // Main content area with premium styling
                    contentSection
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.lg)
                        .offset(y: isAppearing ? 0 : 20)
                        .opacity(isAppearing ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: isAppearing)
                    
                    // Tags with inline editing
                    tagsSection
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.lg)
                        .offset(y: isAppearing ? 0 : 20)
                        .opacity(isAppearing ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: isAppearing)
                    
                    // Source reference (read-only, shown when present)
                    if card.sourceRef != nil {
                        sourceRefSection
                            .padding(.horizontal, DesignSystem.Spacing.xl)
                            .padding(.bottom, DesignSystem.Spacing.lg)
                            .offset(y: isAppearing ? 0 : 20)
                            .opacity(isAppearing ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: isAppearing)
                    }

                    // Media attachments
                    mediaSection
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.xxl)
                        .offset(y: isAppearing ? 0 : 20)
                        .opacity(isAppearing ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: isAppearing)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 520)
        .task { await loadMetadata() }
        .onChange(of: card.kind) { _, newValue in
            withAnimation(DesignSystem.Animation.smooth) {
                configureDefaults(for: newValue)
            }
        }
        .onAppear {
            configureDefaults(for: card.kind)
            withAnimation(.easeOut(duration: 0.4)) {
                isAppearing = true
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            DesignSystem.Colors.canvasBackground
            
            // Subtle radial gradient at top
            RadialGradient(
                colors: [
                    DesignSystem.Colors.subtleOverlay,
                    .clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .opacity(0.5)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.lg) {
            // Left side: Deck info with icon
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.subtleOverlay)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: cardKindIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(deckName)
                        .font(DesignSystem.Typography.heading)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    
                    Text("Editing \(card.kind.displayName.lowercased()) card")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
            }
            
            Spacer()
            
            // Right side: Action buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.hoverBackground)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                
                Button(action: { Task { await saveAndDismiss() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Save")
                            .font(DesignSystem.Typography.bodyMedium)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primaryText)
                    )
                }
                .buttonStyle(PremiumButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    private var cardKindIcon: String {
        switch card.kind {
        case .basic: return "rectangle.on.rectangle"
        case .cloze: return "highlighter"
        case .multipleChoice: return "list.bullet.rectangle"
        }
    }
    
    // MARK: - Card Type Selector
    
    private var cardTypeSelector: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(Card.Kind.allCases, id: \.self) { kind in
                CardTypeButton(
                    kind: kind,
                    isSelected: card.kind == kind,
                    action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            card.kind = kind
                        }
                    }
                )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        EditorSectionCard(
            title: "Content",
            icon: "doc.text",
            isActive: activeSection == .content
        ) {
            VStack(spacing: DesignSystem.Spacing.md) {
                switch card.kind {
                case .basic:
                    basicCardEditor
                case .cloze:
                    clozeCardEditor
                case .multipleChoice:
                    multipleChoiceCardEditor
                }
            }
        }
        .onTapGesture {
            withAnimation(DesignSystem.Animation.quick) {
                activeSection = .content
            }
        }
    }
    
    private var basicCardEditor: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            PremiumTextField(
                placeholder: "What's the question?",
                text: $card.front,
                axis: .vertical,
                lineLimit: 3...8
            )
            .focused($focusedField, equals: .front)
            
            // Flip indicator
            HStack {
                Rectangle()
                    .fill(DesignSystem.Colors.separator)
                    .frame(height: 1)
                
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                
                Rectangle()
                    .fill(DesignSystem.Colors.separator)
                    .frame(height: 1)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            
            PremiumTextField(
                placeholder: "What's the answer?",
                text: $card.back,
                axis: .vertical,
                lineLimit: 3...8
            )
            .focused($focusedField, equals: .back)
        }
    }
    
    private var clozeCardEditor: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Cloze input
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Label("Enter text with {{c1::hidden}} sections", systemImage: "info.circle")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                
                PremiumTextField(
                    placeholder: "The {{c1::mitochondria}} is the powerhouse of the cell",
                    text: Binding(
                        get: { card.clozeSource ?? "" },
                        set: { card.clozeSource = $0 }
                    ),
                    axis: .vertical,
                    lineLimit: 3...8
                )
                .focused($focusedField, equals: .clozeSource)
            }
            
            // Live preview
            if let source = card.clozeSource, !source.isEmpty {
                clozePreview(source: source)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Label("Extra (optional)", systemImage: "text.append")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)

                PremiumTextField(
                    placeholder: "Add notes, examples, or explanations shown after you reveal the answer",
                    text: Binding(
                        get: {
                            guard let source = card.clozeSource, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                return card.back
                            }
                            let stored = card.back.trimmingCharacters(in: .whitespacesAndNewlines)
                            let derived = ClozeRenderer.answer(from: source).trimmingCharacters(in: .whitespacesAndNewlines)
                            let matchesAnswer = ClozeRenderer.extractedAnswers(from: source).contains {
                                $0.compare(stored, options: .caseInsensitive) == .orderedSame
                            }
                            if !stored.isEmpty, stored == derived || matchesAnswer {
                                return ""
                            }
                            return card.back
                        },
                        set: { card.back = $0 }
                    ),
                    axis: .vertical,
                    lineLimit: 2...8
                )
                .focused($focusedField, equals: .back)
            }
        }
    }
    
    @ViewBuilder
    private func clozePreview(source: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("PREVIEW")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                .tracking(1)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Question preview
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    
                    MarkdownText(ClozeRenderer.prompt(from: source))
                        .font(DesignSystem.Typography.body)
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.hoverBackground)
                )
                
                // Answer preview
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.green.opacity(0.8))
                    
                    MarkdownText(ClozeRenderer.answer(from: source))
                        .font(DesignSystem.Typography.body)
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(Color.green.opacity(0.06))
                )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.subtleOverlay)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
    }
    
    private var multipleChoiceCardEditor: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Prompt
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("QUESTION")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .tracking(1)
                
                PremiumTextField(
                    placeholder: "What is being asked?",
                    text: $card.front,
                    axis: .vertical,
                    lineLimit: 2...4
                )
                .focused($focusedField, equals: .prompt)
            }
            
            // Choices
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("CHOICES")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .tracking(1)
                
                ForEach(Array(card.choices.enumerated()), id: \.offset) { index, _ in
                    ChoiceRow(
                        index: index,
                        text: Binding(
                            get: { card.choices[safe: index] ?? "" },
                            set: { newValue in
                                guard card.choices.indices.contains(index) else { return }
                                card.choices[index] = newValue
                            }
                        ),
                        isCorrect: card.correctChoiceIndex == index,
                        onSetCorrect: {
                            withAnimation(DesignSystem.Animation.quick) {
                                card.correctChoiceIndex = index
                            }
                        },
                        onDelete: card.choices.count > 2 ? {
                            withAnimation(DesignSystem.Animation.quick) {
                                card.choices.remove(at: index)
                                normalizeCorrectChoice()
                            }
                        } : nil
                    )
                }
                
                // Add choice button
                Button {
                    withAnimation(DesignSystem.Animation.quick) {
                        card.choices.append("")
                        normalizeCorrectChoice()
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add choice")
                            .font(DesignSystem.Typography.bodyMedium)
                    }
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
            
            // Explanation
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("EXPLANATION (OPTIONAL)")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .tracking(1)
                
                PremiumTextField(
                    placeholder: "Why is this the correct answer?",
                    text: $card.back,
                    axis: .vertical,
                    lineLimit: 2...4
                )
                .focused($focusedField, equals: .explanation)
            }
        }
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        EditorSectionCard(
            title: "Tags",
            icon: "tag",
            isActive: activeSection == .tags
        ) {
            TagEditor(tags: $card.tags, suggestions: availableTags)
        }
        .onTapGesture {
            withAnimation(DesignSystem.Animation.quick) {
                activeSection = .tags
            }
        }
    }
    
    // MARK: - Source Reference Section

    private var sourceRefSection: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.secondaryText)

            Text(card.sourceRef ?? "")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .lineLimit(2)

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.subtleOverlay)
        )
    }

    // MARK: - Media Section
    
    private var mediaSection: some View {
        EditorSectionCard(
            title: "Media",
            icon: "photo.on.rectangle",
            isActive: activeSection == .media,
            isOptional: true
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Add image or video URLs, one per line")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                
                TextEditor(text: Binding(
                    get: { card.media.map { $0.absoluteString }.joined(separator: "\n") },
                    set: { input in
                        let urls = input.split(separator: "\n").compactMap { URL(string: String($0)) }
                        card.media = urls
                    }
                ))
                .font(DesignSystem.Typography.body)
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.hoverBackground)
                )
            }
        }
        .onTapGesture {
            withAnimation(DesignSystem.Animation.quick) {
                activeSection = .media
            }
        }
    }

    // MARK: - Data Loading & Saving
    
    private func loadMetadata() async {
        let tags = await TagService(storage: storage).allTags()
        let name: String
        if let deckId = card.deckId, let deck = await DeckService(storage: storage).deck(withId: deckId) {
            name = deck.name
        } else {
            name = "Unassigned Deck"
        }
        await MainActor.run {
            availableTags = tags
            deckName = name
        }
    }

    @MainActor
    private func saveAndDismiss() async {
        await saveCard()
        dismiss()
    }

    @MainActor
    private func saveCard() async {
        var updated = card
        sanitizeChoices(for: &updated)
        updated.updatedAt = Date()
        if updated.kind == .cloze, let source = updated.clozeSource, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.front = ClozeRenderer.prompt(from: source)
            let derivedAnswer = ClozeRenderer.answer(from: source).trimmingCharacters(in: .whitespacesAndNewlines)
            let stored = updated.back.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesAnswer = ClozeRenderer.extractedAnswers(from: source).contains {
                $0.compare(stored, options: .caseInsensitive) == .orderedSame
            }
            if stored == derivedAnswer || matchesAnswer {
                updated.back = ""
            }
        }
        updated.srs.cardId = updated.id
        await CardService(storage: storage).upsert(card: updated)
        card = updated
    }

    private func configureDefaults(for kind: Card.Kind) {
        switch kind {
        case .basic:
            break
        case .cloze:
            if card.clozeSource == nil {
                card.clozeSource = ""
            }
        case .multipleChoice:
            if card.choices.isEmpty {
                card.choices = ["", "", ""]
            }
            if card.correctChoiceIndex == nil {
                card.correctChoiceIndex = 0
            }
            normalizeCorrectChoice()
        }
    }

    private func normalizeCorrectChoice() {
        guard card.kind == .multipleChoice else { return }
        guard !card.choices.isEmpty else {
            card.correctChoiceIndex = nil
            return
        }
        if let index = card.correctChoiceIndex, card.choices.indices.contains(index) {
            return
        }
        if let firstFilled = card.choices.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            card.correctChoiceIndex = firstFilled
        } else {
            card.correctChoiceIndex = 0
        }
    }

    private func sanitizeChoices(for card: inout Card) {
        guard card.kind == .multipleChoice else { return }
        card.choices = card.choices.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if card.choices.count < 2 {
            card.choices.append(contentsOf: Array(repeating: "", count: 2 - card.choices.count))
        }
        while card.choices.count > 2, card.choices.last?.isEmpty == true {
            card.choices.removeLast()
        }
        if card.choices.isEmpty {
            card.choices = ["", ""]
        }
        if let index = card.correctChoiceIndex, card.choices.indices.contains(index) {
            if card.choices[index].isEmpty {
                card.correctChoiceIndex = card.choices.firstIndex(where: { !$0.isEmpty }) ?? 0
            }
        } else {
            card.correctChoiceIndex = card.choices.firstIndex(where: { !$0.isEmpty }) ?? 0
        }
    }
}

// MARK: - Supporting Components

private struct CardTypeButton: View {
    let kind: Card.Kind
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                Text(kind.displayName)
                    .font(DesignSystem.Typography.bodyMedium)
            }
            .foregroundStyle(isSelected ? .primary : DesignSystem.Colors.tertiaryText)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? DesignSystem.Colors.subtleOverlay : (isHovered ? DesignSystem.Colors.hoverBackground : .clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(DesignSystem.Animation.quick, value: isSelected)
        .animation(DesignSystem.Animation.quick, value: isHovered)
    }
    
    private var iconName: String {
        switch kind {
        case .basic: return "rectangle.on.rectangle"
        case .cloze: return "highlighter"
        case .multipleChoice: return "list.bullet.rectangle"
        }
    }
}

private struct EditorSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let isActive: Bool
    var isOptional: Bool = false
    @ViewBuilder let content: Content
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isActive ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                
                Text(title.uppercased())
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(isActive ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                    .tracking(1)
                
                if isOptional {
                    Text("Optional")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.subtleOverlay)
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
                    isActive ? DesignSystem.Colors.primaryText.opacity(0.15) : DesignSystem.Colors.separator,
                    lineWidth: isActive ? 1.5 : 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(DesignSystem.Animation.quick, value: isHovered)
        .animation(DesignSystem.Animation.quick, value: isActive)
    }
}

private struct PremiumTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int> = 1...1
    
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    
    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .lineLimit(lineLimit)
            .textFieldStyle(.plain)
            .font(DesignSystem.Typography.body)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(isFocused ? DesignSystem.Colors.window : DesignSystem.Colors.hoverBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(
                        isFocused ? DesignSystem.Colors.primaryText.opacity(0.3) : (isHovered ? DesignSystem.Colors.separator : .clear),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .focused($isFocused)
            .onHover { isHovered = $0 }
            .animation(DesignSystem.Animation.quick, value: isFocused)
            .animation(DesignSystem.Animation.quick, value: isHovered)
    }
}

private struct ChoiceRow: View {
    let index: Int
    @Binding var text: String
    let isCorrect: Bool
    let onSetCorrect: () -> Void
    let onDelete: (() -> Void)?
    
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    
    private let letters = ["A", "B", "C", "D", "E", "F", "G", "H"]
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Letter indicator / correct toggle
            Button(action: onSetCorrect) {
                ZStack {
                    Circle()
                        .fill(isCorrect ? Color.green.opacity(0.15) : DesignSystem.Colors.hoverBackground)
                        .frame(width: 32, height: 32)
                    
                    if isCorrect {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.green)
                    } else {
                        Text(letters[safe: index] ?? "\(index + 1)")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(isCorrect ? "This is the correct answer" : "Set as correct answer")
            
            // Text field
            TextField("Choice \(letters[safe: index] ?? "\(index + 1)")", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(isFocused ? DesignSystem.Colors.window : DesignSystem.Colors.hoverBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .stroke(
                            isCorrect ? Color.green.opacity(0.3) : (isFocused ? DesignSystem.Colors.primaryText.opacity(0.2) : .clear),
                            lineWidth: 1
                        )
                )
                .focused($isFocused)
            
            // Delete button
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .opacity(isHovered ? 1 : 0.5)
                }
                .buttonStyle(.plain)
            }
        }
        .onHover { isHovered = $0 }
        .animation(DesignSystem.Animation.quick, value: isCorrect)
        .animation(DesignSystem.Animation.quick, value: isHovered)
    }
}

private struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private extension Array where Element == String {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

#if DEBUG
#Preview("CardEditorView") {
    RevuPreviewHost { controller in
        let deck = Deck(name: "Preview Deck")
        Task { try? await controller.storage.upsert(deck: deck.toDTO()) }
        let card = Card(
            deckId: deck.id,
            kind: .basic,
            front: "What is the definition of a matrix?",
            back: "A rectangular array of numbers."
        )
        return CardEditorView(card: card, storage: controller.storage)
            .frame(width: 900, height: 700)
    }
}
#endif
