import SwiftUI

struct CardColumnsView: View {
    @StateObject private var viewModel: CardBrowserViewModel
    @Binding var selection: Set<Card.ID>
    
    let onEdit: (Card) -> Void
    let onDelete: (Card) -> Void
    let onToggleSuspend: (Card) -> Void
    
    @Environment(\.storage) private var storage
    
    init(filter: CardBrowserFilter,
         selection: Binding<Set<Card.ID>>,
         onEdit: @escaping (Card) -> Void = { _ in },
         onDelete: @escaping (Card) -> Void = { _ in },
         onToggleSuspend: @escaping (Card) -> Void = { _ in },
         storage: Storage? = nil) {
        let resolvedStorage = storage ?? DataController.shared.storage
        _viewModel = StateObject(wrappedValue: CardBrowserViewModel(filter: filter, storage: resolvedStorage))
        self._selection = selection
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggleSuspend = onToggleSuspend
    }
    
    var body: some View {
        Group {
            if viewModel.cards.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    // Left column - Card list
                    cardList
                        .frame(maxWidth: 360)
                    
                    Divider()
                        .background(DesignSystem.Colors.separator)
                    
                    // Right column - Card detail
                    if let selectedCard = selectedCard {
                        cardDetail(for: selectedCard)
                    } else {
                        emptyDetail
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.canvasBackground)
        .onAppear { viewModel.refresh() }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.split.2x1.slash")
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
    }
    
    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.cards) { card in
                    CardColumnsListItem(
                        card: card,
                        state: viewModel.state(for: card),
                        isSelected: selection.contains(card.id),
                        onTap: {
                            selection = [card.id]
                        }
                    )
                    
                    Divider()
                        .background(DesignSystem.Colors.separator)
                }
            }
        }
        .background(DesignSystem.Colors.sidebarBackground)
    }
    
    private func cardDetail(for card: Card) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Image(systemName: cardTypeIcon(for: card))
                        .dynamicSystemFont(size: 16, relativeTo: .body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.08)))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cardTypeTitle(for: card))
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(.primary)
                        
                        Text("Updated \(card.updatedAt, style: .relative)")
                            .font(DesignSystem.Typography.small)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button("Edit") { onEdit(card) }
                        Button(card.isSuspended ? "Unsuspend" : "Suspend") { onToggleSuspend(card) }
                        Divider()
                        Button("Delete", role: .destructive) { onDelete(card) }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .dynamicSystemFont(size: 18, relativeTo: .title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.hoverBackground)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                // Tags
                if !card.tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(card.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundStyle(.secondary)
                                .dynamicPadding(.horizontal, base: 10, relativeTo: .caption)
                                .dynamicPadding(.vertical, base: 5, relativeTo: .caption)
                                .background(
                                    Capsule()
                                        .fill(Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.08)))
                                )
                        }
                    }
                }
                
                // Question
                VStack(alignment: .leading, spacing: 12) {
                    Text("Question")
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    MarkdownText(card.displayPrompt)
                        .font(DesignSystem.Typography.heading)
                        .foregroundStyle(.primary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DesignSystem.Colors.window)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                )
                
                // Answer
                if !card.displayAnswer.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Answer")
                            .font(DesignSystem.Typography.smallMedium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        MarkdownText(card.displayAnswer)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(.primary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignSystem.Colors.window)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                    )
                }
                
                // Multiple choice options
                if card.kind == .multipleChoice && !card.displayChoices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Answer Choices")
                            .font(DesignSystem.Typography.smallMedium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        VStack(spacing: 8) {
                            ForEach(Array(card.displayChoices.enumerated()), id: \.offset) { index, choice in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .dynamicSystemFont(size: 12, weight: .semibold, relativeTo: .caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.08)))
                                        )
                                    
                                    MarkdownText(choice, color: index == card.correctChoiceIndex ? .primary : .secondary)
                                        .font(DesignSystem.Typography.body)
                                    
                                    Spacer()
                                    
                                    if index == card.correctChoiceIndex {
                                        Image(systemName: "checkmark.circle.fill")
                                            .dynamicSystemFont(size: 16, relativeTo: .body)
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(index == card.correctChoiceIndex ? 
                                              Color.green.opacity(0.08) : 
                                              Color(light: Color.black.opacity(0.02), dark: Color.white.opacity(0.04)))
                                )
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignSystem.Colors.window)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                    )
                }
                
                // SRS Statistics
                srsStatistics(for: card)
            }
            .padding(24)
        }
        .background(DesignSystem.Colors.canvasBackground)
    }
    
    private func srsStatistics(for card: Card) -> some View {
        let state = viewModel.state(for: card)
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Learning Progress")
                .font(DesignSystem.Typography.smallMedium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ColumnStatCard(title: "Status", value: queueText(for: state), color: queueColor(for: state))
                ColumnStatCard(title: "Due", value: dueText(for: state), color: .secondary)
                ColumnStatCard(title: "Predicted", value: String(format: "%.0f%%", state.predictedRecallAtScheduled(retentionTarget: AppSettingsDefaults.retentionTarget) * 100), color: .secondary)
                ColumnStatCard(title: "Stability", value: String(format: "%.1f d", state.stability), color: .secondary)
                ColumnStatCard(title: "Difficulty", value: String(format: "%.1f", state.difficulty), color: .secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    private var emptyDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.on.square.dashed")
                .dynamicSystemFont(size: 44, weight: .regular, relativeTo: .largeTitle)
                .foregroundStyle(.tertiary)
            Text("Select a card")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(.secondary)
            Text("Choose a card from the list to view its details")
                .font(DesignSystem.Typography.small)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.canvasBackground)
    }
    
    private var selectedCard: Card? {
        guard let id = selection.first else { return nil }
        return viewModel.cards.first { $0.id == id }
    }
    
    private func cardTypeIcon(for card: Card) -> String {
        switch card.kind {
        case .basic: return "rectangle.on.rectangle"
        case .cloze: return "text.insert"
        case .multipleChoice: return "list.bullet.circle"
        }
    }
    
    private func cardTypeTitle(for card: Card) -> String {
        switch card.kind {
        case .basic: return "Basic Card"
        case .cloze: return "Cloze Deletion"
        case .multipleChoice: return "Multiple Choice"
        }
    }
    
    private func queueColor(for state: SRSState) -> Color {
        switch state.queue {
        case .new: return Color.accentColor
        case .learning, .relearn: return .orange
        case .review: return .green
        }
    }
    
    private func queueText(for state: SRSState) -> String {
        switch state.queue {
        case .new: return "New"
        case .learning: return "Learning"
        case .relearn: return "Relearning"
        case .review: return "Review"
        }
    }
    
    private func dueText(for state: SRSState) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: state.dueDate, relativeTo: Date())
    }
}

private struct CardColumnsListItem: View {
    let card: Card
    let state: SRSState
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(queueColor)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.displayPrompt)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        if !card.tags.isEmpty, let firstTag = card.tags.first {
                            Text("#\(firstTag)")
                                .font(DesignSystem.Typography.small)
                                .foregroundStyle(.secondary)
                        }
                        
                        if card.isSuspended {
                            Image(systemName: "pause.circle.fill")
                                .dynamicSystemFont(size: 10, relativeTo: .caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                
                Spacer(minLength: 8)
                
                Image(systemName: cardTypeIcon)
                    .dynamicSystemFont(size: 11, relativeTo: .caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var cardTypeIcon: String {
        switch card.kind {
        case .basic: return "rectangle.on.rectangle"
        case .cloze: return "text.insert"
        case .multipleChoice: return "list.bullet.circle"
        }
    }
    
    private var queueColor: Color {
        switch state.queue {
        case .new: return Color.accentColor
        case .learning, .relearn: return .orange
        case .review: return .green
        }
    }
}

private struct ColumnStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DesignSystem.Typography.small)
                .foregroundStyle(.secondary)
            Text(value)
                .dynamicSystemFont(size: 16, weight: .semibold, design: .rounded, relativeTo: .title3)
                .foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(light: Color.black.opacity(0.03), dark: Color.white.opacity(0.04)))
        )
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for size in sizes {
            if lineWidth + size.width > proposal.width ?? 0 {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            totalWidth = max(totalWidth, lineWidth)
        }
        totalHeight += lineHeight
        
        return CGSize(width: totalWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var lineX = bounds.minX
        var lineY = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineX + size.width > bounds.maxX && lineX > bounds.minX {
                lineY += lineHeight + spacing
                lineHeight = 0
                lineX = bounds.minX
            }
            subview.place(at: CGPoint(x: lineX, y: lineY), proposal: .unspecified)
            lineHeight = max(lineHeight, size.height)
            lineX += size.width + spacing
        }
    }
}

#if DEBUG
private struct CardColumnsViewPreview: View {
    let controller: DataController
    @State private var selection: Set<Card.ID> = []

    var body: some View {
        CardColumnsView(
            filter: .smart(.new),
            selection: $selection,
            storage: controller.storage
        )
        .frame(width: 980, height: 720)
    }
}

#Preview("CardColumnsView") {
    RevuPreviewHost { controller in
        CardColumnsViewPreview(controller: controller)
    }
}
#endif
