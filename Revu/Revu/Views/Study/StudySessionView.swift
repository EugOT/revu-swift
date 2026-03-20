import SwiftUI

  struct StudySessionView: View {
    @StateObject private var viewModel: StudySessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var revealPulse = false
    @State private var selectedChoiceIndex: Int?
    @State private var pendingOutcome: RecallOutcome?
    @State private var pressedGrade: ReviewGrade?
    @State private var clozeRevealTrigger: Int = 0
    @State private var clozeHiddenRemaining: Int = 0
    @State private var postSessionDirective: StudyDirective?
    private let onClose: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let intervalFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    init(deck: Deck? = nil, mode: DeckStudyMode = .dueToday, onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: StudySessionViewModel(deck: deck, mode: mode))
        self.onClose = onDismiss
    }

    init(courseIds: [UUID], onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: StudySessionViewModel(courseIds: courseIds))
        self.onClose = onDismiss
    }

    var body: some View {
        GeometryReader { geometry in
            let mainLayoutWidth: CGFloat = geometry.size.width

            ZStack(alignment: .top) {
                // Warm background (not solid black)
                DesignSystem.Colors.window
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Ultra-thin progress bar at very top
                    progressIndicator

                    HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                        ScrollView {
                            VStack(spacing: responsiveSpacing(for: mainLayoutWidth)) {
                                sessionHeader

                                if viewModel.isFinished {
                                    completionView
                                    finishedControls
                                } else if let item = viewModel.currentItem {
                                    switch item {
                                    case .flashcard(let card):
                                        cardView(card)
                                        controls
                                    default:
                                        SessionItemView(
                                            item: item,
                                            onComplete: { wasSuccessful in
                                                viewModel.recordItemOutcome(for: item, wasSuccessful: wasSuccessful)
                                            },
                                            onRequestExplanation: { card in
                                                viewModel.requestExplanation(for: card)
                                            }
                                        )
                                        .dynamicPadding(.horizontal, base: 36, relativeTo: .title2)
                                        .dynamicPadding(.vertical, base: 32, relativeTo: .title2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .sessionItemCardStyle()
                                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                    }
                                } else {
                                    emptyQueueView
                                    finishedControls
                                }
                            }
                            .frame(maxWidth: responsiveMaxWidth(for: mainLayoutWidth), maxHeight: .infinity)
                            .padding(.leading, responsivePadding(for: mainLayoutWidth))
                            .padding(.trailing, responsivePadding(for: mainLayoutWidth))
                            .padding(.vertical, responsiveVerticalPadding(for: mainLayoutWidth))
                        }
                        .scrollIndicators(.hidden)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            viewModel.reloadSettings()
            updateRevealPulse()
        }
        .onChange(of: viewModel.isRevealed) {
            updateRevealPulse()
        }
        .onChange(of: viewModel.currentCard?.id) {
            selectedChoiceIndex = nil
            pendingOutcome = nil
            pressedGrade = nil
            clozeRevealTrigger = 0
            clozeHiddenRemaining = 0
            updateRevealPulse()
        }
    }
    
    // MARK: - Responsive Layout Helpers
    
    private func responsiveMaxWidth(for width: CGFloat) -> CGFloat {
        let base: CGFloat
        switch width {
        case ..<500:
            base = width - 32 // Very narrow
        case 500..<700:
            base = 560 // Compact
        case 700..<900:
            base = 680 // Medium
        default:
            base = 820 // Wide
        }

        let adjusted = base + (dynamicTypeSize.isAccessibilityCategory ? 96 : 0)
        let candidate = min(width - 24, adjusted)
        let baselineLimit = min(width - 24, base)
        return max(candidate, baselineLimit)
    }
    
    private func responsivePadding(for width: CGFloat) -> CGFloat {
        let base: CGFloat
        switch width {
        case ..<500:
            base = DesignSystem.Spacing.md // 16
        case 500..<700:
            base = DesignSystem.Spacing.lg // 24
        default:
            base = DesignSystem.Spacing.xl // 32
        }
        return base * dynamicTypeSize.designSystemSpacingMultiplier
    }
    
    private func responsiveVerticalPadding(for width: CGFloat) -> CGFloat {
        let base: CGFloat
        switch width {
        case ..<500:
            base = DesignSystem.Spacing.lg // 24
        default:
            base = DesignSystem.Spacing.xl // 32
        }
        return base * dynamicTypeSize.designSystemSpacingMultiplier
    }
    
    private func responsiveSpacing(for width: CGFloat) -> CGFloat {
        let base: CGFloat
        switch width {
        case ..<500:
            base = DesignSystem.Spacing.md // 16
        case 500..<700:
            base = DesignSystem.Spacing.lg // 24
        default:
            base = DesignSystem.Spacing.xl // 32
        }
        return base * dynamicTypeSize.designSystemSpacingMultiplier
    }

    // MARK: - Sections
    
    /// Fancier progress indicator at top of screen with gradient
    private var progressIndicator: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(DesignSystem.Colors.separator.opacity(0.2))
                
                // Progress bar with gradient
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primaryText.opacity(0.4),
                                DesignSystem.Colors.primaryText.opacity(0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * sessionProgress)
                    .shadow(color: DesignSystem.Colors.primaryText.opacity(0.3), radius: 4, x: 0, y: 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessionProgress)
            }
        }
        .frame(height: 3)
    }
    
    /// Minimal, calm session header with centered context
    private var sessionHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Top control row
            HStack(alignment: .center) {
                // Back button
                Button {
                    handleDismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.lightOverlay)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                // Centered session context
                VStack(spacing: DesignSystem.Spacing.xxs) {
                    if !viewModel.isFinished {
                        Text(contextSubtitle.isEmpty ? "Session" : contextSubtitle)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("\(viewModel.completed + 1) of \(viewModel.totalItemCount)")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                                .contentTransition(.numericText())

                            // Streak indicator: appears after 3+ consecutive correct answers
                            let streak = viewModel.currentStreak
                            if streak >= 3 {
                                HStack(spacing: 2) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(.caption2, design: .default).weight(.semibold))
                                    Text("\(streak)")
                                        .font(DesignSystem.Typography.captionMedium)
                                }
                                .foregroundStyle(DesignSystem.Colors.feedbackSuccess)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.feedbackSuccess.opacity(0.12))
                                )
                                .transition(.scale(scale: 0.7).combined(with: .opacity))
                                .animation(DesignSystem.Animation.snappy, value: streak)
                            }
                        }
                    }
                }

                Spacer()

                // Right controls (timer, shuffle, refresh)
                HStack(spacing: DesignSystem.Spacing.xs) {
                    if !viewModel.isFinished {
                        // Timer badge (subtle)
                        Text(formattedTime)
                            .font(DesignSystem.Typography.mono)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.lightOverlay)
                            )
                    }
                    
                    // Utility menu (shuffle + refresh combined)
                    if !viewModel.isFinished {
                        Menu {
                            if viewModel.canShuffleEntireSession {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.shufflePending(includeCurrentCard: true)
                                    }
                                } label: {
                                    Label("Shuffle Queue", systemImage: "shuffle")
                                }
                            }
                            
                            Button {
                                viewModel.loadQueue()
                            } label: {
                                Label("Reload Queue", systemImage: "arrow.clockwise")
                            }
                            
                            Divider()
                            
                            if viewModel.queueMode == .ahead {
                                Button {
                                    viewModel.restartScheduledQueue()
                                } label: {
                                    Label("Back to Schedule", systemImage: "calendar")
                                }
                            } else {
                                Button {
                                    viewModel.loadAheadQueue()
                                } label: {
                                    Label("Study Ahead", systemImage: "forward.end")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(DesignSystem.Colors.lightOverlay)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
                                )
                        }
                        .menuIndicator(.hidden)
                        .buttonStyle(.plain)
                    } else {
                        // Placeholder for layout balance
                        Color.clear.frame(width: 36, height: 36)
                    }
                }
            }
            
            // Ahead mode badge
            if viewModel.queueMode == .ahead && !viewModel.isFinished {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(.caption2, design: .default).weight(.medium))
                    Text("Studying ahead")
                        .font(DesignSystem.Typography.captionMedium)
                }
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    Capsule()
                        .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
                )
            }
        }
    }

    // Legacy header for compatibility (redirects to new)
    private var header: some View {
        sessionHeader
    }

    @ViewBuilder
    private func cardView(_ card: Card) -> some View {
        let contentSpacing = 20 * dynamicTypeSize.designSystemSpacingMultiplier

        VStack(alignment: .leading, spacing: contentSpacing) {
            // Header row with deck name and tags
            HStack(spacing: DesignSystem.Spacing.sm) {
                let deckName = viewModel.deckName(for: card)
                if !deckName.isEmpty {
                    Label(deckName, systemImage: "rectangle.stack")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xxs + 1)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.subtleOverlay)
                        )
                }
                
                if !card.tags.isEmpty {
                    tagList(for: card.tags)
                }
                
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm + 2) {
                Text(stageLabel(for: card))
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xxs + 1)
                    .background(
                        DesignSystem.Colors.subtleOverlay,
                        in: Capsule()
                    )

                // Render prompt: Cloze uses native spoiler chips; others use Markdown
                if card.kind == .cloze {
                    ClozePromptView(
                        source: card.clozeSource ?? card.front,
                        revealTrigger: clozeRevealTrigger
                    ) { remaining, _ in
                        clozeHiddenRemaining = remaining
                    }
                        .transition(.opacity.combined(with: .scale))
                        .id("cloze-\(card.id)-\(viewModel.isRevealed ? "revealed" : "hidden")")
                } else {
                    MarkdownText(card.displayPrompt)
                        .font(DesignSystem.Typography.heading)
                        .foregroundStyle(.primary)
                        .transition(.opacity.combined(with: .scale))
                        .id("prompt-\(card.id)-\(viewModel.isRevealed ? "revealed" : "hidden")")
                }
            }

            if !card.media.isEmpty {
                CardMediaStripView(urls: card.media)
                    .transition(.opacity)
                    .id("media-\(card.id)")
            }

            if card.kind == .multipleChoice {
                choiceList(for: card)

                if viewModel.isRevealed, !card.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider()
                        .background(DesignSystem.Colors.separator)
                    MarkdownText(card.back)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                        .id("mc-back-\(card.id)")
                }
            } else if viewModel.isRevealed {
                Divider()
                    .background(DesignSystem.Colors.separator)
                MarkdownText(card.displayAnswer)
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(.primary)
                    .transition(.opacity.combined(with: .scale))
                    .id("answer-\(card.id)")

                if card.kind == .cloze {
                    let extra = card.back.trimmingCharacters(in: .whitespacesAndNewlines)
                    let source = card.clozeSource ?? ""
                    let derived = ClozeRenderer.answer(from: source).trimmingCharacters(in: .whitespacesAndNewlines)
                    let answers = ClozeRenderer.extractedAnswers(from: source)
                    let matchesAnswer = answers.contains { $0.compare(extra, options: .caseInsensitive) == .orderedSame }
                    if !extra.isEmpty, extra != derived, !matchesAnswer {
                    Divider()
                        .background(DesignSystem.Colors.separator)
                    MarkdownText(card.back)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                        .id("cloze-extra-\(card.id)")
                    }
                }
            }
        }
        .dynamicPadding(.horizontal, base: 36, relativeTo: .title2)
        .dynamicPadding(.vertical, base: 32, relativeTo: .title2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sessionItemCardStyle()
        .id(card.id)
    }

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Keep revealButton in hierarchy to handle Space shortcut for both Reveal and Next
            revealButton
                .opacity(shouldShowRevealButton ? 1 : 0)
                .frame(height: shouldShowRevealButton ? nil : 0)
                .clipped()
                .accessibilityHidden(!shouldShowRevealButton)

            outcomeControls

            secondaryControls
        }
        .animation(DesignSystem.Animation.smooth, value: viewModel.isRevealed)
        .transition(.opacity)
    }

    private var finishedControls: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if viewModel.queueMode == .ahead {
                Button {
                    viewModel.loadAheadQueue()
                } label: {
                    Label("Load More Ahead", systemImage: "forward.end.circle.fill")
                }
                .buttonStyle(.plain)
                .primaryButtonStyle()

                Button {
                    viewModel.restartScheduledQueue()
                } label: {
                    Label("Back to Schedule", systemImage: "calendar.badge.clock")
                }
                .buttonStyle(.plain)
                .secondaryButtonStyle()
            } else {
                Button {
                    viewModel.restartScheduledQueue()
                } label: {
                    Label("Review Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .primaryButtonStyle()

                Button {
                    viewModel.loadAheadQueue()
                } label: {
                    Label("Study Ahead", systemImage: "forward.end.fill")
                }
                .buttonStyle(.plain)
                .secondaryButtonStyle()
            }

            Button(role: .cancel) {
                handleDismiss()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .buttonStyle(.plain)
            .secondaryButtonStyle()
        }
    }

    private var emptyQueueView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "tray")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(.tertiary)
            Text("No cards queued")
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(.primary)
            Text("Refresh the session or adjust filters to pull in new material.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .dynamicPadding(.horizontal, base: 32, relativeTo: .title3)
        .sessionItemCardStyle()
    }

    /// Monochrome reveal button with keyboard hint
    /// Smart behavior: reveals answer if hidden, advances to next card if revealed
    private var revealButton: some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                handlePrimaryAction()
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("Show Answer")
                    .font(DesignSystem.Typography.bodyMedium)

                Text("Space")
                    .keyboardHintStyle()
            }
            .foregroundStyle(DesignSystem.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md + 2)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(DesignSystem.Colors.lightOverlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .strokeBorder(
                        revealPulse ? DesignSystem.Colors.primaryText.opacity(0.3) : DesignSystem.Colors.separator,
                        lineWidth: 1
                    )
                    .animation(DesignSystem.Animation.ambientPulse, value: revealPulse)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .keyboardShortcut(.space, modifiers: [])
        .disabled(viewModel.currentCard == nil)
    }

    @ViewBuilder
    private var outcomeControls: some View {
        if viewModel.isFinished {
            EmptyView()
        } else if let card = viewModel.currentCard {
            switch card.kind {
            case .multipleChoice:
                multipleChoiceOutcomeControls()
            case .basic, .cloze:
                recallOutcomeButtons()
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func recallOutcomeButtons() -> some View {
        if viewModel.isRevealed {
            // 4-grade system: Again / Hard / Good / Easy
            VStack(spacing: 0) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    gradeButton(for: .again).frame(maxWidth: .infinity)
                    gradeButton(for: .hard).frame(maxWidth: .infinity)
                    gradeButton(for: .good).frame(maxWidth: .infinity)
                    gradeButton(for: .easy).frame(maxWidth: .infinity)
                }

                // Hidden letter shortcut buttons (a/h/g/e)
                // These capture key presses without occupying layout space
                ZStack {
                    Button("") { viewModel.recordGrade(.again) }
                        .keyboardShortcut("a", modifiers: [])
                        .hidden()
                    Button("") { viewModel.recordGrade(.hard) }
                        .keyboardShortcut("h", modifiers: [])
                        .hidden()
                    Button("") { viewModel.recordGrade(.good) }
                        .keyboardShortcut("g", modifiers: [])
                        .hidden()
                    Button("") { viewModel.recordGrade(.easy) }
                        .keyboardShortcut("e", modifiers: [])
                        .hidden()
                }
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func multipleChoiceOutcomeControls() -> some View {
        if let outcome = pendingOutcome, viewModel.isRevealed {
            VStack(spacing: DesignSystem.Spacing.sm) {
                outcomeSummary(for: outcome)
                Button {
                    submitOutcome(outcome)
                } label: {
                    Label("Next Card", systemImage: "arrow.right")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .dynamicPadding(.horizontal, base: 20, relativeTo: .body)
                        .dynamicPadding(.vertical, base: 12, relativeTo: .body)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                                .fill(outcomeDescriptor(for: outcome).tint)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else {
            Text("Select an answer choice to reveal feedback.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .dynamicPadding(.horizontal, base: 18, relativeTo: .body)
                .dynamicPadding(.vertical, base: 14, relativeTo: .body)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                        .fill(DesignSystem.Colors.lightOverlay)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    @State private var pressedOutcome: RecallOutcome?

    // MARK: - Grade Button (4-grade system)

    /// Descriptor for a 4-grade ReviewGrade button.
    private func gradeDescriptor(for grade: ReviewGrade) -> (label: String, keyLabel: String, tint: Color) {
        switch grade {
        case .again:
            return ("Again", "1", DesignSystem.Colors.feedbackError)
        case .hard:
            return ("Hard", "2", Color.orange)
        case .good:
            return ("Good", "3", DesignSystem.Colors.accent)
        case .easy:
            return ("Easy", "4", DesignSystem.Colors.feedbackSuccess)
        }
    }

    /// 4-grade button showing grade label and keyboard hint.
    private func gradeButton(for grade: ReviewGrade) -> some View {
        let descriptor = gradeDescriptor(for: grade)
        let isPressed = pressedGrade == grade

        let keyShortcut: KeyEquivalent
        switch grade {
        case .again: keyShortcut = "1"
        case .hard:  keyShortcut = "2"
        case .good:  keyShortcut = "3"
        case .easy:  keyShortcut = "4"
        }

        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                pressedGrade = grade
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.recordGrade(grade)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation { pressedGrade = nil }
                }
            }
        } label: {
            VStack(alignment: .center, spacing: DesignSystem.Spacing.xxs) {
                Text(descriptor.label)
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(isPressed ? descriptor.tint : DesignSystem.Colors.primaryText)

                if viewModel.showKeyboardHints {
                    Text(descriptor.keyLabel)
                        .keyboardHintStyle()
                        .foregroundStyle(isPressed ? descriptor.tint.opacity(0.7) : DesignSystem.Colors.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(isPressed ? descriptor.tint.opacity(0.15) : DesignSystem.Colors.lightOverlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .strokeBorder(
                        isPressed ? descriptor.tint : DesignSystem.Colors.separator,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(ScaleButtonStyle())
        .keyboardShortcut(keyShortcut, modifiers: [])
    }

    // MARK: - Legacy 2-button (RecallOutcome) — kept for MC flow

    /// Monochrome outcome button with keyboard hint - shows color only after interaction
    private func outcomeButton(for outcome: RecallOutcome) -> some View {
        let descriptor = outcomeDescriptor(for: outcome)
        let keyLabel = outcome == .forgot ? "F" : "⏎"
        let isPressed = pressedOutcome == outcome
        
        return Button {
            // Animate press state first
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                pressedOutcome = outcome
            }
            
            // Delay submission slightly to show the color
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                submitOutcome(outcome)
                // Reset state after submission (though view might reload/dismiss)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        pressedOutcome = nil
                    }
                }
            }
        } label: {
            VStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                Text(outcome == .forgot ? "Study again" : "Remembered")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(isPressed ? descriptor.tint : DesignSystem.Colors.primaryText)

                Text(keyLabel)
                    .keyboardHintStyle()
                    .foregroundStyle(isPressed ? descriptor.tint.opacity(0.8) : DesignSystem.Colors.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg - 4)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(isPressed ? descriptor.tint.opacity(0.15) : DesignSystem.Colors.lightOverlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .strokeBorder(
                        isPressed ? descriptor.tint : DesignSystem.Colors.separator,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(ScaleButtonStyle())
        .keyboardShortcut(outcome == .forgot ? KeyEquivalent("f") : .return, modifiers: [])
    }

    private func outcomeSummary(for outcome: RecallOutcome) -> some View {
        let descriptor = outcomeDescriptor(for: outcome)
        return HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: descriptor.icon)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(descriptor.tint)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(descriptor.tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                Text(descriptor.detail)
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .dynamicPadding(.vertical, base: 12, relativeTo: .body)
        .dynamicPadding(.horizontal, base: 18, relativeTo: .body)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay)
        )
    }

    private func outcomeDescriptor(for outcome: RecallOutcome) -> (title: String, detail: String, icon: String, tint: Color) {
        let previewText = previewDetail(for: outcome)
        switch outcome {
        case .forgot:
            return (
                title: "Relearn soon",
                detail: previewText ?? "We'll resurface this card shortly for reinforcement.",
                icon: "arrow.counterclockwise",
                tint: retryTint
            )
        case .rememberedEasy:
            return (
                title: "Well done",
                detail: previewText ?? "Next review will be scheduled farther out.",
                icon: "sparkles",
                tint: successTint
            )
        }
    }
    
    private var successTint: Color { DesignSystem.Colors.feedbackSuccess }
    private var retryTint: Color { DesignSystem.Colors.feedbackError }

    private func previewDetail(for outcome: RecallOutcome) -> String? {
        guard let preview = viewModel.preview(for: outcome) else { return nil }
        let recallPercent = max(0, min(100, Int((preview.predictedRecall * 100).rounded())))
        let recallText = "≈\(recallPercent)% expected recall"
        let stabilityText = formatStability(preview.updatedState.stability)
        let difficultyText = String(format: "%.1f", preview.updatedState.difficulty)
        let intervalText = StudySessionView.intervalFormatter.string(from: preview.nextInterval)
        let relative = StudySessionView.relativeFormatter.localizedString(for: preview.scheduledDate, relativeTo: Date())
        let timing: String
        if preview.nextInterval < 45 {
            timing = "almost immediately"
        } else if let intervalText, preview.nextInterval < 3_600 {
            timing = "in \(intervalText)"
        } else {
            timing = relative
        }
        let prefix = preview.nextInterval < 3_600 ? "Adaptive check" : "Adaptive review"
        return "\(prefix) \(timing) • \(recallText) • Stability \(stabilityText) • Difficulty \(difficultyText)"
    }

    private func formatStability(_ days: Double) -> String {
        if days < 1 {
            let hours = max(1, Int((days * 24).rounded()))
            return "\(hours)h"
        }
        if days < 10 {
            return String(format: "%.1fd", days)
        }
        return String(format: "%.0fd", days.rounded())
    }

    private func submitOutcome(_ outcome: RecallOutcome) {
                viewModel.recordOutcome(outcome)
    }

    @ViewBuilder
    private var secondaryControls: some View {
        if viewModel.isRevealed {
            EmptyView()
        } else {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Menu {
                    Button("Bury") {
                        withAnimation(DesignSystem.Animation.layout) {
                            viewModel.buryCurrentCard()
                        }
                    }
                    .keyboardShortcut("b", modifiers: [.option])

                    Button("Suspend") {
                        withAnimation(DesignSystem.Animation.layout) {
                            viewModel.suspendCurrentCard()
                        }
                    }
                    .keyboardShortcut("s", modifiers: [.option])
                } label: {
                    Label("More", systemImage: "ellipsis")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(.primary)
                        .labelStyle(.titleAndIcon)
                        .dynamicPadding(.horizontal, base: 16, relativeTo: .body)
                        .dynamicPadding(.vertical, base: 10, relativeTo: .body)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                                .fill(DesignSystem.Colors.hoverBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentCard == nil)

                Spacer()

                Button(role: .cancel) {
                    handleDismiss()
                } label: {
                    Label("End Session", systemImage: "xmark")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(.primary)
                        .labelStyle(.titleAndIcon)
                        .dynamicPadding(.horizontal, base: 16, relativeTo: .body)
                        .dynamicPadding(.vertical, base: 10, relativeTo: .body)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                                .fill(DesignSystem.Colors.hoverBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }

    private func handleDismiss() {
        viewModel.endSessionEarly()
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func choiceList(for card: Card) -> some View {
        let stackSpacing = 12 * dynamicTypeSize.designSystemSpacingMultiplier

        return VStack(alignment: .leading, spacing: stackSpacing) {
            if card.displayChoices.isEmpty {
                Text("No answer choices configured for this card")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(DesignSystem.Colors.lightOverlay, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.xxl, style: .continuous))
            } else {
                ForEach(Array(card.displayChoices.enumerated()), id: \.offset) { index, choice in
                    choiceButton(for: card, index: index, text: choice)
                }
            }
        }
    }

    private func choiceButton(for card: Card, index: Int, text: String) -> some View {
        let isSelected = selectedChoiceIndex == index
        let isCorrect = card.correctChoiceIndex == index
        let showFeedback = viewModel.isRevealed

        let background: Color
        let border: Color
        let foreground: Color

        if showFeedback {
            if isCorrect {
                background = DesignSystem.Colors.feedbackSuccess.opacity(0.12)
                border = DesignSystem.Colors.feedbackSuccess.opacity(0.35)
                foreground = DesignSystem.Colors.feedbackSuccess
            } else if isSelected {
                background = DesignSystem.Colors.feedbackError.opacity(0.12)
                border = DesignSystem.Colors.feedbackError.opacity(0.35)
                foreground = DesignSystem.Colors.feedbackError
            } else {
                background = DesignSystem.Colors.lightOverlay
                border = DesignSystem.Colors.subtleOverlay
                foreground = .secondary
            }
        } else if isSelected {
            background = DesignSystem.Colors.studyAccentBright.opacity(0.12)
            border = DesignSystem.Colors.studyAccentBright.opacity(0.35)
            foreground = DesignSystem.Colors.studyAccentBright
        } else {
            background = DesignSystem.Colors.lightOverlay
            border = DesignSystem.Colors.subtleOverlay
            foreground = .primary
        }

        return Button {
            selectChoice(index, for: card)
        } label: {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm + 2) {
                Text(String(index + 1))
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.subtleOverlay)
                    )
                MarkdownText(text.isEmpty ? "Untitled option" : text, color: foreground)
                    .font(DesignSystem.Typography.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showFeedback {
                    if isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.feedbackSuccess)
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.feedbackError)
                    }
                }
            }
            .dynamicPadding(.vertical, base: 16, relativeTo: .body)
            .dynamicPadding(.horizontal, base: 18, relativeTo: .body)
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .stroke(border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRevealed)
    }

    private func selectChoice(_ index: Int, for card: Card) {
        guard card.displayChoices.indices.contains(index) else { return }
        if selectedChoiceIndex == index { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedChoiceIndex = index
            if let correct = card.correctChoiceIndex {
                pendingOutcome = correct == index ? .rememberedEasy : .forgot
            } else {
                pendingOutcome = .rememberedEasy
            }
            if !viewModel.isRevealed {
                viewModel.reveal()
            }
        }
    }

    private func handlePrimaryAction() {
        guard let card = viewModel.currentCard else { return }

        if card.kind == .cloze, clozeHiddenRemaining > 0 {
            // Step through cloze deletions before showing the full answer
            clozeRevealTrigger += 1
            return
        }

        if viewModel.isRevealed {
            // Space = Good (most natural "I got it" gesture) for basic/cloze cards
            if card.kind == .basic || card.kind == .cloze {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    pressedGrade = .good
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.recordGrade(.good)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation { pressedGrade = nil }
                    }
                }
            } else {
                submitOutcome(.rememberedEasy)
            }
        } else {
            viewModel.reveal()
        }
    }

    private var formattedTime: String {
        let totalSeconds = Int(viewModel.elapsedSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @ViewBuilder
    private var background: some View {
        if onClose == nil {
            DesignSystem.Colors.canvasBackground
                .ignoresSafeArea()
        } else {
            DesignSystem.Colors.canvasBackground
        }
    }

    private var shouldShowRevealButton: Bool {
        // Only show when NOT revealed (Space triggers Remembered when revealed)
        !viewModel.isRevealed
    }

    private func stageLabel(for card: Card) -> String {
        switch card.kind {
        case .multipleChoice:
            return viewModel.isRevealed ? "Answer feedback" : "Question"
        case .basic, .cloze:
            return viewModel.isRevealed ? "Answer" : "Prompt"
        }
    }

    private var sessionTitle: String {
        if viewModel.isFinished {
            return "Session complete"
        }
        return viewModel.sessionContextTitle
    }

    private var sessionSubtitle: String {
        if let card = viewModel.currentCard {
            let position = viewModel.completed + 1
            let total = max(totalCardCount, 1)
            switch card.kind {
            case .multipleChoice:
                if selectedChoiceIndex == nil {
                    return "Card \(position) of \(total)"
                }
                return "Card \(position) of \(total). Review feedback, then press Return to continue."
            case .basic, .cloze:
                return viewModel.isRevealed ? "Mark whether you remembered or forgot." : "Press Space when you're ready to reveal."
            }
        }
        if viewModel.isFinished {
            if viewModel.queueMode == .ahead {
                return "You’re ahead through the \(viewModel.aheadWindowDescription). Load more or close when you're ready."
            }
            return "All caught up — refresh or close when you're ready."
        }
        if viewModel.queueMode == .ahead {
            return "No cards queued. Load more to keep working ahead."
        }
        return "No cards queued. Refresh to bring in more reviews."
    }

    private var contextSubtitle: String {
        viewModel.sessionContextSubtitle
    }

    private var controlHint: String {
        guard let card = viewModel.currentCard else {
            return viewModel.queueMode == .ahead ? "Queue is empty — load more ahead to continue." : "Queue is empty — refresh to continue."
        }
        switch card.kind {
        case .multipleChoice:
            if selectedChoiceIndex == nil {
                return "" // Message shown in multipleChoiceOutcomeControls instead
            }
            return "Review the answer, then press Return to continue."
        case .basic, .cloze:
            if !viewModel.isRevealed {
                return "Press Space to reveal, then decide if you remembered."
            }
            return "Press F if you forgot or Return if you remembered easily."
        }
    }

    private var sessionProgress: Double {
        let total = Double(totalCardCount)
        guard total > 0 else { return 0 }
        return Double(viewModel.completed) / total
    }

    private var totalCardCount: Int {
        // Use engine-aware total that includes all item types
        viewModel.totalItemCount
    }

    private var remainingCardCount: Int {
        viewModel.queue.count + (viewModel.currentCard == nil ? 0 : 1)
    }

    private func updateRevealPulse() {
        guard let card = viewModel.currentCard else {
            revealPulse = false
            return
        }
        let shouldPulse = !viewModel.isRevealed && card.kind != .multipleChoice
        if revealPulse != shouldPulse {
            revealPulse = shouldPulse
        }
    }

    /// Minimal, calm completion view with hero typography
    private var completionView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Emerald gradient ring on completion
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.separator.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(
                        DesignSystem.Gradients.studyAccent,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                Image(systemName: viewModel.queueMode == .ahead ? "infinity" : "checkmark")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
            }

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Session complete")
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                Text(viewModel.queueMode == .ahead ? "You're studying ahead of schedule" : "All cards reviewed for now")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            
            // Stats row
            HStack(spacing: DesignSystem.Spacing.xl) {
                statItem(value: "\(viewModel.completed)", label: "cards")
                statItem(value: formattedTime, label: "time")
                if viewModel.completed > 0 {
                    let accuracy = Int((Double(viewModel.completed - viewModel.lapseCount) / Double(viewModel.completed)) * 100)
                    statItem(value: "\(accuracy)%", label: "recall")
                }
            }
            .padding(.top, DesignSystem.Spacing.md)

            // Post-session directive card
            if let postDirective = postSessionDirective {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.accent)
                        Text("Next time")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }

                    Text(postDirective.headline)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)

                    Text(postDirective.body)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .lineLimit(3)

                    if !postDirective.weakConcepts.isEmpty {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(postDirective.weakConcepts.prefix(3), id: \.self) { concept in
                                Text(concept)
                                    .font(DesignSystem.Typography.captionMedium)
                                    .foregroundStyle(DesignSystem.Colors.accent)
                                    .padding(.horizontal, DesignSystem.Spacing.sm)
                                    .padding(.vertical, DesignSystem.Spacing.xxs)
                                    .background(
                                        Capsule()
                                            .fill(DesignSystem.Colors.accent.opacity(0.12))
                                    )
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.subtleOverlay.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
                )
                .padding(.top, DesignSystem.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.vertical, DesignSystem.Spacing.xl)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .sessionItemCardStyle()
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .task(id: viewModel.isFinished) {
            guard viewModel.isFinished else { return }
            let engine = StudyDirectiveEngine()
            postSessionDirective = await engine.postSessionDirective(
                completedCards: viewModel.completed,
                lapseCount: viewModel.lapseCount,
                weakConceptKeys: extractWeakConcepts(),
                courseName: viewModel.currentDeckName
            )
        }
    }
    
    /// Extract weak concepts from the current session (placeholder for TASK-03 data).
    private func extractWeakConcepts() -> [String] {
        return []
    }

    /// Helper for completion stats
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text(value)
                .font(DesignSystem.Typography.mono)
                .foregroundStyle(DesignSystem.Colors.primaryText)
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }
}

// MARK: - Supporting types

private extension StudySessionView {
    func tagList(for tags: [String]) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(tags.prefix(3), id: \.self) { tag in
                Text("#\(tag)")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .dynamicPadding(.horizontal, base: 10, relativeTo: .caption)
                    .dynamicPadding(.vertical, base: 5, relativeTo: .caption)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.subtleOverlay)
                    )
            }
            if tags.count > 3 {
                Text("+\(tags.count - 3)")
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(.tertiary)
                    .dynamicPadding(.horizontal, base: 8, relativeTo: .caption)
                    .dynamicPadding(.vertical, base: 4, relativeTo: .caption)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.lightOverlay)
                    )
            }
        }
    }
}

// MARK: - Shared Container

struct StudySessionSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.window
                .ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Study Session") {
    StudySessionView()
        .frame(width: 800, height: 600)
}

#Preview("Study Session - Dark") {
    StudySessionView()
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}

#Preview("Study Session - Compact") {
    StudySessionView()
        .frame(width: 400, height: 700)
        .preferredColorScheme(.dark)
}
