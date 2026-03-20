import SwiftUI

/// Interactive cloze prompt that hides deletions behind spoiler chips and reveals them individually on click.
/// Uses a lightweight wrapping layout to approximate inline placement without WebKit.
struct ClozePromptView: View {
    let source: String
    let revealTrigger: Int
    let onRevealProgress: ((Int, Int) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    // Track reveal state per deletion in reading order
    @State private var revealed: [Bool] = []

    private var fragments: [ClozeRenderer.LinearFragment] {
        ClozeRenderer.linearFragments(from: source)
    }

    init(
        source: String,
        revealTrigger: Int = 0,
        onRevealProgress: ((Int, Int) -> Void)? = nil
    ) {
        self.source = source
        self.revealTrigger = revealTrigger
        self.onRevealProgress = onRevealProgress
    }

    var body: some View {
        let frags = fragments
        InlineWrapLayout(alignment: .leading, spacing: 6, lineSpacing: 6) {
            ForEach(Array(frags.enumerated()), id: \.offset) { idx, frag in
                switch frag {
                case .text(let s):
                    // Render inline text with Markdown/LaTeX support.
                    MarkdownText(s)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                case .deletion(let index, let answer, let hint):
                    ClozeChip(
                        index: index,
                        hint: hint,
                        answer: answer,
                        revealed: revealedBinding(for: idx)
                    )
                }
            }
        }
        .onAppear {
            syncState(with: frags)
            reportProgress(for: frags)
        }
        .onChange(of: source) { oldValue, newValue in
            syncState(with: fragments)
            reportProgress(for: fragments)
        }
        .onChange(of: revealTrigger) { oldValue, newValue in
            revealNextDeletion()
        }
        .onChange(of: revealed) { oldValue, newValue in
            reportProgress(for: fragments)
        }
        .accessibilityElement(children: .contain)
    }

    private func revealedBinding(for fragmentIndex: Int) -> Binding<Bool> {
        Binding(
            get: { (0..<revealed.count).contains(fragmentIndex) ? revealed[fragmentIndex] : false },
            set: { newValue in
                if (0..<revealed.count).contains(fragmentIndex) {
                    revealed[fragmentIndex] = newValue
                }
            }
        )
    }

    private func syncState(with fragments: [ClozeRenderer.LinearFragment]) {
        if revealed.count != fragments.count {
            revealed = fragments.map { frag in
                if case .deletion = frag { return false } else { return true }
            }
        }
    }

    private func revealNextDeletion() {
        let frags = fragments
        guard !frags.isEmpty else { return }

        if revealed.count != frags.count {
            syncState(with: frags)
        }

        guard !frags.isEmpty else { return }

        if let nextIndex = frags.enumerated().first(where: { idx, frag in
            if case .deletion = frag {
                return !(revealed.indices.contains(idx) ? revealed[idx] : true)
            } else {
                return false
            }
        })?.0 {
            withAnimation(.easeInOut(duration: 0.15)) {
                if revealed.indices.contains(nextIndex) {
                    revealed[nextIndex] = true
                }
            }
        }
    }

    private func reportProgress(for fragments: [ClozeRenderer.LinearFragment]) {
        guard let onRevealProgress else { return }
        let totals = fragments.enumerated().reduce((total: 0, remaining: 0)) { partial, entry in
            let (idx, frag) = entry
            guard case .deletion = frag else { return partial }
            let isRevealed = revealed.indices.contains(idx) ? revealed[idx] : false
            let newTotal = partial.total + 1
            let newRemaining = partial.remaining + (isRevealed ? 0 : 1)
            return (newTotal, newRemaining)
        }
        onRevealProgress(totals.remaining, totals.total)
    }
}

// MARK: - Cloze chip

private struct ClozeChip: View {
    let index: Int
    let hint: String?
    let answer: String
    @Binding var revealed: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { revealed.toggle() }
        } label: {
            HStack(spacing: 6) {
                if revealed {
                    // Allow light Markdown in revealed content
                    MarkdownText(answer)
                        .foregroundStyle(.primary)
                } else {
                    let idx = index > 0 ? String(index) : "…"
                    if let hint, !hint.isEmpty {
                        Text("[\(idx) | \(hint)]")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("[\(idx)]")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.hoverBackground)
            )
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(revealed ? "Cloze answer \(index)" : "Reveal cloze \(index)")
    }
}

// MARK: - Inline wrapping layout

/// Simple flow layout that wraps children horizontally onto new lines.
struct InlineWrapLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth { // wrap
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth { // wrap
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#if DEBUG
#Preview("ClozePromptView") {
    ClozePromptView(
        source: "The derivative of {{c1::$x^2$}} is {{c2::$2x$}}. Hint: {{c3::power rule::Rule name}}."
    )
    .padding()
    .frame(width: 520)
    .background(DesignSystem.Colors.window)
}
#endif
