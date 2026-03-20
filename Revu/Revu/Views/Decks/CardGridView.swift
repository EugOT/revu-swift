import SwiftUI

struct CardGridView: View {
    let cards: [Card]
    let isLoading: Bool
    @Binding var selection: Set<Card.ID>
    let stateProvider: (Card) -> SRSState
    let onSelect: (Card) -> Void
    let onEdit: (Card) -> Void
    let onDelete: (Card) -> Void
    let onToggleSuspend: (Card) -> Void
    let cardSizeScale: Double
    @DesignSystemScaledMetric private var gridSpacing: CGFloat = DesignSystem.Spacing.lg
    @DesignSystemScaledMetric(relativeTo: .title3) private var gridPadding: CGFloat = DesignSystem.Spacing.xl

    private var minColumnWidth: CGFloat { 200 + CGFloat(cardSizeScale) * 240 }
    private var maxColumnWidth: CGFloat { 260 + CGFloat(cardSizeScale) * 280 }

    init(
        cards: [Card],
        isLoading: Bool = false,
        selection: Binding<Set<Card.ID>>,
        stateProvider: @escaping (Card) -> SRSState,
        cardSizeScale: Double = 0.5,
        onSelect: @escaping (Card) -> Void = { _ in },
        onEdit: @escaping (Card) -> Void = { _ in },
        onDelete: @escaping (Card) -> Void = { _ in },
        onToggleSuspend: @escaping (Card) -> Void = { _ in }
    ) {
        self.cards = cards
        self.isLoading = isLoading
        self._selection = selection
        self.stateProvider = stateProvider
        self.cardSizeScale = cardSizeScale
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggleSuspend = onToggleSuspend
    }

    var body: some View {
        Group {
            if cards.isEmpty && !isLoading {
                emptyState
            } else {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
                    ForEach(cards) { card in
                        CardGridItem(
                            card: card,
                            state: stateProvider(card),
                            isSelected: selection.contains(card.id),
                            cardSizeScale: cardSizeScale,
                            onTap: { onSelect(card) },
                            onEdit: { onEdit(card) },
                            onDelete: { onDelete(card) },
                            onToggleSuspend: { onToggleSuspend(card) }
                        )
                    }
                }
                .padding(.horizontal, gridPadding)
                .padding(.vertical, gridSpacing)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.window)
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: minColumnWidth, maximum: maxColumnWidth), spacing: gridSpacing, alignment: .top)]
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
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
}

// MARK: - Procedural Grain Texture

/// Lightweight procedural noise overlay that gives flashcards a paper-like grain.
/// Uses a seeded LCG so each card gets a unique but deterministic pattern.
private struct CardGrainTexture: View {
    let seed: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            var rng = CardGrainRNG(seed: UInt64(seed))
            let step: CGFloat = 3
            let cols = Int(size.width / step)
            let rows = Int(size.height / step)
            let maxAlpha = colorScheme == .dark ? 0.07 : 0.045

            for row in 0..<rows {
                for col in 0..<cols {
                    // ~30% fill rate keeps texture subtle
                    guard Double.random(in: 0...1, using: &rng) < 0.30 else { continue }
                    let x = CGFloat(col) * step + CGFloat.random(in: -0.5...0.5, using: &rng)
                    let y = CGFloat(row) * step + CGFloat.random(in: -0.5...0.5, using: &rng)
                    let alpha = Double.random(in: 0.005...maxAlpha, using: &rng)
                    let dotSize = CGFloat.random(in: 0.6...1.4, using: &rng)
                    let dotColor = colorScheme == .dark ? Color.white : Color.black
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                        with: .color(dotColor.opacity(alpha))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Simple linear congruential generator for deterministic grain per card.
private struct CardGrainRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Card Grid Item

private struct CardGridItem: View {
    let card: Card
    let state: SRSState
    let isSelected: Bool
    let cardSizeScale: Double
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleSuspend: () -> Void
    @State private var isHovered: Bool = false
    @State private var isFlipped: Bool = false
    @State private var hasAppeared: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var cardHeight: CGFloat { 160 + CGFloat(cardSizeScale) * 160 }
    @DesignSystemScaledMetric(relativeTo: .caption) private var headerHeight: CGFloat = 28
    @DesignSystemScaledMetric private var verticalSpacing: CGFloat = DesignSystem.Spacing.md
    @DesignSystemScaledMetric private var contentSpacing: CGFloat = DesignSystem.Spacing.sm
    @DesignSystemScaledMetric(relativeTo: .caption) private var headerSpacing: CGFloat = DesignSystem.Spacing.xs
    @DesignSystemScaledMetric(relativeTo: .title3) private var cardPadding: CGFloat = DesignSystem.Spacing.lg
    @DesignSystemScaledMetric(relativeTo: .caption) private var footerVerticalPadding: CGFloat = DesignSystem.Spacing.sm
    @DesignSystemScaledMetric(relativeTo: .caption) private var footerHorizontalPadding: CGFloat = DesignSystem.Spacing.lg

    /// Stable seed derived from the card ID for deterministic grain.
    private var grainSeed: Int {
        abs(card.id.hashValue)
    }

    private static let dueFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// Whether the card is due now or overdue
    private var isDue: Bool {
        state.dueDate <= Date()
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Front face
                cardFront
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

                // Back face
                cardBack
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Flip Card") {
                withAnimation(DesignSystem.Animation.cardFlip) {
                    isFlipped.toggle()
                }
            }
            Button(card.isSuspended ? "Unsuspend" : "Suspend") { onToggleSuspend() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
        .onHover { isHovered = $0 }
        // Hover lift effect
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .offset(y: isHovered ? -3 : 0)
        // Soft shadow with animated elevation
        .shadow(
            color: Color(light: Color.black.opacity(0.08), dark: Color.black.opacity(0.5)),
            radius: (isSelected || isHovered) ? 18 : 8,
            x: 0,
            y: (isSelected || isHovered) ? 8 : 3
        )
        .animation(DesignSystem.Animation.elevation, value: isHovered)
        .animation(DesignSystem.Animation.elevation, value: isSelected)
        .onAppear {
            withAnimation(DesignSystem.Animation.smooth.delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Front Face

    private var cardFront: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header with card type and status - FIXED HEIGHT
                HStack(spacing: headerSpacing) {
                    Image(systemName: cardTypeIcon)
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.subtleOverlay)
                        )

                    if !card.tags.isEmpty {
                        Text("#\(card.tags.first!)")
                            .font(DesignSystem.Typography.smallMedium)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 0)

                    statusBadge
                }
                .frame(height: headerHeight)

                Spacer(minLength: verticalSpacing)

                // Card content - FLEXIBLE HEIGHT with consistent behavior
                VStack(alignment: .leading, spacing: contentSpacing) {
                    Text(card.displayPrompt)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    // Always reserve space for answer section for consistency
                    Group {
                        if !card.displayAnswer.isEmpty {
                            DesignSystem.Colors.flashcardDivider
                                .frame(height: 1)

                            Text(card.displayAnswer)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        } else {
                            // Empty spacer to maintain consistent height
                            Color.clear
                                .frame(height: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(cardPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            DesignSystem.Colors.flashcardDivider
                .frame(height: 1)

            // Footer — reduced prominence
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: contentSpacing) {
                    Label(dueText, systemImage: "calendar")
                        .font(DesignSystem.Typography.small)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(state.interval)d")
                        .dynamicSystemFont(size: 10, design: .monospaced, relativeTo: .caption2)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText.opacity(0.7))
                }

                DeckCardProgressBar(progress: hasAppeared ? masteryProgress : 0)
            }
            .padding(.horizontal, footerHorizontalPadding)
            .padding(.vertical, footerVerticalPadding)
            .background(DesignSystem.Colors.flashcardFooter)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .fill(DesignSystem.Colors.flashcardSurface)
        )
        // Procedural grain texture
        .overlay(
            CardGrainTexture(seed: grainSeed)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        )
        // Subtle inner vignette — darkens edges slightly for depth
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(colorScheme == .dark ? 0.04 : 0.015)
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 240
                    )
                )
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        // Border — crisp edge
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(
                    isSelected ? DesignSystem.Colors.studyAccentBorder : DesignSystem.Colors.flashcardBorder,
                    lineWidth: isSelected ? 1.8 : 1
                )
        )
        // Faint top edge highlight (inner)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.55),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 0.5
                )
                .allowsHitTesting(false)
        )
    }

    // MARK: - Back Face

    private var cardBack: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(.secondary)
                Text("Answer")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(card.displayAnswer.isEmpty ? "No answer" : card.displayAnswer)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .fill(DesignSystem.Colors.flashcardSurface)
        )
        .overlay(
            CardGrainTexture(seed: grainSeed &+ 7)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(colorScheme == .dark ? 0.04 : 0.015)
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 240
                    )
                )
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(DesignSystem.Colors.studyAccentBorder.opacity(0.5), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.55),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 0.5
                )
                .allowsHitTesting(false)
        )
    }

    private var cardTypeIcon: String {
        switch card.kind {
        case .basic: return "rectangle.on.rectangle"
        case .cloze: return "text.insert"
        case .multipleChoice: return "list.bullet.circle"
        }
    }

    private var statusBadge: some View {
        Group {
            if card.isSuspended {
                Image(systemName: "pause.circle.fill")
                    .dynamicSystemFont(size: 14, relativeTo: .caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            } else {
                Circle()
                    .fill(DesignSystem.Gradients.studyAccentSoft)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.Colors.studyAccentBorder.opacity(0.55), lineWidth: 0.6)
                    )
                    // Pulse when due
                    .scaleEffect(isDue ? 1.3 : 1.0)
                    .opacity(isDue ? 0.8 : 1.0)
                    .animation(isDue ? DesignSystem.Animation.ambientPulse : .default, value: isDue)
            }
        }
    }

    private var dueText: String {
        Self.dueFormatter.localizedString(for: state.dueDate, relativeTo: Date())
    }

    private var masteryProgress: Double {
        state.masteryProgress()
    }
}

private struct DeckCardProgressBar: View {
    let progress: Double

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DesignSystem.Colors.cardProgressTrack)

                if clampedProgress > 0 {
                    let fillWidth = max(geometry.size.width * clampedProgress, 10)
                    Capsule()
                        .fill(DesignSystem.Gradients.studyAccentSoft)
                        .frame(width: fillWidth)
                        .shadow(
                            color: DesignSystem.Colors.studyAccentGlow.opacity(0.22),
                            radius: 3,
                            x: 0,
                            y: 1
                        )
                }
            }
        }
        .frame(height: 8)
        .animation(DesignSystem.Animation.smooth, value: clampedProgress)
        .accessibilityLabel("Mastery progress")
        .accessibilityValue(Text("\(Int((clampedProgress * 100).rounded())) percent"))
    }
}

#if DEBUG
private struct CardGridViewPreview: View {
    @State private var selection: Set<Card.ID> = []

    private let cards: [Card] = [
        Card(kind: .basic, front: "What is the difference between an iterable and an indexable?", back: "Iterable: can be looped over; indexable: supports obj[i] (random access).", tags: ["L3"]),
        Card(kind: .basic, front: "Give the literal syntax for an empty list, empty tuple, empty set, empty dict.", back: "`[]`, `()`, `set()`, `{}`.", tags: ["L3"]),
        Card(kind: .cloze, front: "", back: "", clozeSource: "Sets are {{c1::iterable}} but do not support {{c2::indexing}}.", tags: ["L3"]),
        Card(kind: .basic, front: "Predict: `print('a,b,c'.split(','))`", back: "`split` returns a list of substrings separated by the delimiter.", tags: ["L3"]),
        Card(kind: .basic, front: "What is indexing?", back: "Accessing an element of an indexable sequence by position, e.g. `s[0]`.", tags: ["L3"]),
        Card(kind: .basic, front: "Give two common string methods used in FoP file-processing.", back: "`strip()`, `split()` (also `replace()`, `lower()`, `upper()`).", tags: ["L3"]),
    ]

    var body: some View {
        CardGridView(
            cards: cards,
            selection: $selection,
            stateProvider: { $0.srs },
            onSelect: { selection = [$0.id] }
        )
        .frame(width: 1080, height: 600)
    }
}

#Preview("CardGrid — Dark") {
    CardGridViewPreview()
        .preferredColorScheme(.dark)
}

#Preview("CardGrid — Light") {
    CardGridViewPreview()
        .preferredColorScheme(.light)
}
#endif
