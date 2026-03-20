import SwiftUI

struct CardNotebookView: View {
    let cards: [Card]
    let isLoading: Bool
    @Binding var selection: Set<Card.ID>
    
    let stateProvider: (Card) -> SRSState
    let onEdit: (Card) -> Void
    let onDelete: (Card) -> Void
    let onToggleSuspend: (Card) -> Void
    
    init(
        cards: [Card],
        isLoading: Bool = false,
        selection: Binding<Set<Card.ID>>,
        stateProvider: @escaping (Card) -> SRSState,
        onEdit: @escaping (Card) -> Void = { _ in },
        onDelete: @escaping (Card) -> Void = { _ in },
        onToggleSuspend: @escaping (Card) -> Void = { _ in }
    ) {
        self.cards = cards
        self.isLoading = isLoading
        self._selection = selection
        self.stateProvider = stateProvider
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggleSuspend = onToggleSuspend
    }
    
    var body: some View {
        Group {
            if cards.isEmpty && !isLoading {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        CardNotebookItem(
                            card: card,
                            index: index + 1,
                            state: stateProvider(card),
                            isSelected: selection.contains(card.id),
                            onTap: {
                                if selection.contains(card.id) {
                                    selection.remove(card.id)
                                } else {
                                    selection = [card.id]
                                }
                            },
                            onEdit: { onEdit(card) },
                            onDelete: { onDelete(card) },
                            onToggleSuspend: { onToggleSuspend(card) }
                        )
                        
                        if index < cards.count - 1 {
                            Divider()
                                .background(DesignSystem.Colors.separator)
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.lg)
                .background(notebookBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .dynamicSystemFont(size: 44, weight: .regular, relativeTo: .largeTitle)
                .foregroundStyle(.tertiary)
            Text("No cards found")
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(.primary)
            Text("Try adjusting your filters or create a new card")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.window)
    }

    private var notebookBackground: some View {
        GeometryReader { geometry in
            ZStack {
                // Paper texture background
                DesignSystem.Colors.window
                
                // Notebook lines effect
                VStack(spacing: 28) {
                    ForEach(0..<100, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.03)))
                            .frame(height: 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 80)
                
                // Left margin line
                Rectangle()
                    .fill(Color(light: Color.red.opacity(0.2), dark: Color.red.opacity(0.15)))
                    .frame(width: 2)
                    .offset(x: -geometry.size.width / 2 + 60)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

private struct CardNotebookItem: View {
    let card: Card
    let index: Int
    let state: SRSState
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleSuspend: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 20) {
                // Index number in the margin
                Text("\(index)")
                    .dynamicSystemFont(size: 14, weight: .medium, design: .rounded, relativeTo: .body)
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, alignment: .trailing)
                
                VStack(alignment: .leading, spacing: 16) {
                    // Header with metadata
                    HStack(spacing: 10) {
                        Image(systemName: cardTypeIcon)
                            .dynamicSystemFont(size: 12, relativeTo: .caption)
                            .foregroundStyle(.secondary)
                        
                        if !card.tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(card.tags.prefix(3), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(DesignSystem.Typography.smallMedium)
                                        .foregroundStyle(.secondary)
                                        .dynamicPadding(.horizontal, base: 8, relativeTo: .caption)
                                        .dynamicPadding(.vertical, base: 3, relativeTo: .caption)
                                        .background(
                                            Capsule()
                                                .fill(Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.08)))
                                        )
                                }
                            }
                        }
                        
                        Spacer()
                        
                        if card.isSuspended {
                            Label("Suspended", systemImage: "pause.circle.fill")
                                .font(DesignSystem.Typography.smallMedium)
                                .foregroundStyle(.orange)
                                .labelStyle(.iconOnly)
                        }
                        
                        statusIndicator
                    }
                    
                    // Question section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Q:")
                            .dynamicSystemFont(size: 12, weight: .bold, relativeTo: .caption)
                            .foregroundStyle(.tertiary)
                        
                        Group {
                            if isSelected {
                                MarkdownText(card.displayPrompt)
                            } else {
                                Text(card.displayPrompt)
                                    .lineLimit(3)
                                    .truncationMode(.tail)
                            }
                        }
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    }
                    
                    // Answer section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A:")
                            .dynamicSystemFont(size: 12, weight: .bold, relativeTo: .caption)
                            .foregroundStyle(.tertiary)
                        
                        Group {
                            if isSelected {
                                MarkdownText(card.displayAnswer)
                            } else {
                                Text(card.displayAnswer)
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                            }
                        }
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    }
                    
                    // Footer with tags and actions
                    HStack(spacing: 12) {
                        if !card.tags.isEmpty {
                            ForEach(card.tags.prefix(2), id: \.self) { tag in
                                TagBadge(tag: tag)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            IconButton("pencil", size: 28, action: onEdit)
                            IconButton("trash", size: 28, action: onDelete)
                            IconButton(card.isSuspended ? "play.fill" : "pause.fill", size: 28, action: onToggleSuspend)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.subtleOverlay : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var cardTypeIcon: String {
        switch card.kind {
        case .basic:
            return "text.alignleft"
        case .cloze:
            return "square.dashed"
        case .multipleChoice:
            return "checklist"
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusLabel)
                .font(DesignSystem.Typography.small)
                .foregroundStyle(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch state.queue {
        case .new: return .blue
        case .learning: return .orange
        case .review: return .green
        case .relearn: return .purple
        }
    }
    
    private var statusLabel: String {
        switch state.queue {
        case .new: return "New"
        case .learning: return "Learning"
        case .review: return "Review"
        case .relearn: return "Relearn"
        }
    }
}

#if DEBUG
private struct CardNotebookViewPreview: View {
    @State private var selection: Set<Card.ID> = []

    private let cards: [Card] = [
        Card(kind: .basic, front: "Explain eigenvectors.", back: "…"),
        Card(kind: .basic, front: "What is a monoid?", back: "…"),
        Card(kind: .basic, front: "Hola → ?", back: "Hello"),
    ]

    var body: some View {
        CardNotebookView(
            cards: cards,
            selection: $selection,
            stateProvider: { $0.srs }
        )
        .frame(width: 980, height: 720)
        .background(DesignSystem.Colors.window)
    }
}

#Preview("CardNotebookView") {
    CardNotebookViewPreview()
}
#endif
