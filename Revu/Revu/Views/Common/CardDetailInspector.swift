import SwiftUI

struct CardDetailInspector: View {
    @Environment(\.storage) private var storage
    @EnvironmentObject private var storeEvents: StoreEvents
    
    let card: Card
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleSuspend: () -> Void
    
    @State private var srsState: SRSState
    @State private var recentLogs: [ReviewLog] = []
    
    init(card: Card, 
         onEdit: @escaping () -> Void = {},
         onDelete: @escaping () -> Void = {},
         onToggleSuspend: @escaping () -> Void = {}) {
        self.card = card
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggleSuspend = onToggleSuspend
        self._srsState = State(initialValue: card.srs)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection
                
                // Question
                questionSection
                
                // Answer
                if !card.displayAnswer.isEmpty {
                    answerSection
                }
                
                // Multiple choice options
                if card.kind == .multipleChoice && !card.displayChoices.isEmpty {
                    choicesSection
                }
                
                // Tags
                if !card.tags.isEmpty {
                    tagsSection
                }
                
                // SRS Statistics
                srsStatisticsSection
                
                // Recent Activity
                recentActivitySection
                
                // Actions
                actionsSection
            }
            .padding(20)
        }
        .background(DesignSystem.Colors.inspectorBackground)
        .onAppear {
            srsState = card.srs
            loadRecentLogs()
        }
        .onReceive(storeEvents.$tick) { _ in
            srsState = card.srs
            loadRecentLogs()
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: cardTypeIcon)
                .dynamicSystemFont(size: 16, relativeTo: .body)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.08)))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(cardTypeTitle)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                
                Text("Updated \(card.updatedAt, style: .relative)")
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(.secondary)
                
                if card.isSuspended {
                    Label("Suspended", systemImage: "pause.circle.fill")
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
    }
    
    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUESTION")
                .dynamicSystemFont(size: 10, weight: .semibold, relativeTo: .caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            MarkdownText(card.displayPrompt)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ANSWER")
                .dynamicSystemFont(size: 10, weight: .semibold, relativeTo: .caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            MarkdownText(card.displayAnswer)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    private var choicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ANSWER CHOICES")
                .dynamicSystemFont(size: 10, weight: .semibold, relativeTo: .caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            VStack(spacing: 6) {
                ForEach(Array(card.displayChoices.enumerated()), id: \.offset) { index, choice in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .dynamicSystemFont(size: 11, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.08)))
                            )
                        
                        MarkdownText(choice, color: index == card.correctChoiceIndex ? .primary : .secondary)
                            .font(DesignSystem.Typography.small)
                        
                        Spacer()
                        
                        if index == card.correctChoiceIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .dynamicSystemFont(size: 14, relativeTo: .body)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index == card.correctChoiceIndex ? 
                                  Color.green.opacity(0.08) : 
                                  Color(light: Color.black.opacity(0.02), dark: Color.white.opacity(0.04)))
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TAGS")
                .dynamicSystemFont(size: 10, weight: .semibold, relativeTo: .caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            FlowLayout(spacing: 6) {
                ForEach(card.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(.secondary)
                        .dynamicPadding(.horizontal, base: 8, relativeTo: .caption)
                        .dynamicPadding(.vertical, base: 4, relativeTo: .caption)
                        .background(
                            Capsule()
                                .fill(Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.08)))
                        )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    private var srsStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEARNING PROGRESS")
                .dynamicSystemFont(size: 10, weight: .semibold, relativeTo: .caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                InspectorStatCard(title: "Status", value: queueText, color: queueColor)
                InspectorStatCard(title: "Due", value: dueText, color: .secondary)
                InspectorStatCard(title: "Predicted", value: String(format: "%.0f%%", srsState.predictedRecallAtScheduled(retentionTarget: AppSettingsDefaults.retentionTarget) * 100), color: .secondary)
                InspectorStatCard(title: "Stability", value: String(format: "%.1f d", srsState.stability), color: .secondary)
                InspectorStatCard(title: "Difficulty", value: String(format: "%.1f", srsState.difficulty), color: .secondary)
                InspectorStatCard(title: "FSRS Reps", value: "\(srsState.fsrsReps)", color: .secondary)
                InspectorStatCard(title: "Lapses", value: "\(srsState.lapses)", color: .secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT ACTIVITY")
                .dynamicSystemFont(size: 10, weight: .semibold, relativeTo: .caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            if recentLogs.isEmpty {
                Text("No reviews yet")
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentLogs.prefix(5)) { log in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.timestamp, style: .date)
                                    .font(DesignSystem.Typography.small)
                                    .foregroundStyle(.secondary)
                                Text(log.timestamp, style: .time)
                                    .dynamicSystemFont(size: 10, relativeTo: .caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                            
                            Text("Grade \(log.grade)")
                                .font(DesignSystem.Typography.smallMedium)
                                .foregroundStyle(.primary)
                            
                            Image(systemName: "arrow.right")
                                .dynamicSystemFont(size: 9, relativeTo: .caption2)
                                .foregroundStyle(.tertiary)
                            
                            Text("\(log.nextInterval)d")
                                .dynamicSystemFont(size: 11, design: .monospaced, relativeTo: .caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(light: Color.black.opacity(0.02), dark: Color.white.opacity(0.04)))
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    private var actionsSection: some View {
        VStack(spacing: 8) {
            Button {
                onEdit()
            } label: {
                Label("Edit Card", systemImage: "pencil")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignSystem.Colors.hoverBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Button {
                onToggleSuspend()
            } label: {
                Label(card.isSuspended ? "Resume Card" : "Suspend Card", 
                      systemImage: card.isSuspended ? "play.circle" : "pause.circle")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignSystem.Colors.hoverBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Card", systemImage: "trash")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helpers
    
    private var cardTypeIcon: String {
        switch card.kind {
        case .basic: return "rectangle.on.rectangle"
        case .cloze: return "text.insert"
        case .multipleChoice: return "list.bullet.circle"
        }
    }
    
    private var cardTypeTitle: String {
        switch card.kind {
        case .basic: return "Basic Card"
        case .cloze: return "Cloze Deletion"
        case .multipleChoice: return "Multiple Choice"
        }
    }
    
    private var queueColor: Color {
        switch srsState.queue {
        case .new: return Color.accentColor
        case .learning, .relearn: return .orange
        case .review: return .green
        }
    }
    
    private var queueText: String {
        switch srsState.queue {
        case .new: return "New"
        case .learning: return "Learning"
        case .relearn: return "Relearning"
        case .review: return "Review"
        }
    }
    
    private var dueText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: srsState.dueDate, relativeTo: Date())
    }
    
    private func loadRecentLogs() {
        Task {
            let allLogs = await ReviewLogService(storage: storage).recentLogs(limit: 50)
            let filtered = allLogs
                .filter { $0.cardId == card.id }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(5)
            await MainActor.run {
                recentLogs = Array(filtered)
            }
        }
    }
}

private struct InspectorStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DesignSystem.Typography.small)
                .foregroundStyle(.secondary)
            Text(value)
                .dynamicSystemFont(size: 14, weight: .semibold, design: .rounded, relativeTo: .title3)
                .foregroundStyle(color)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
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
#Preview("CardDetailInspector") {
    RevuPreviewHost { controller in
        let deck = Deck(name: "Preview Deck")
        Task {
            try? await controller.storage.upsert(deck: deck.toDTO())
        }

        var card = Card(
            deckId: deck.id,
            kind: .basic,
            front: "What is $\\nabla\\cdot \\vec{F}$?",
            back: "The divergence of $\\vec{F}$."
        )
        card.tags = ["math", "vector-calculus"]
        return CardDetailInspector(card: card)
            .frame(width: 360, height: 720)
    }
}
#endif
