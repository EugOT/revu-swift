import SwiftUI

/// Renders a study explanation within the session flow.
///
/// Shows an explanation for a concept the student struggled with,
/// followed by "Got it" / "Still confused" action buttons.
struct ExplanationItemView: View {
    let item: ExplanationItem
    let onDismiss: (Bool) -> Void  // true = understood, false = still confused

    @State private var explanationText: String = ""
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Stage label
            stageLabel

            // Concept name
            Text(item.conceptName)
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(DesignSystem.Colors.primaryText)

            // Explanation content (streamed)
            if isLoading {
                loadingIndicator
            } else {
                MarkdownText(explanationText)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }

            // Action buttons
            if !isLoading {
                actionButtons
            }
        }
        .dynamicPadding(.horizontal, base: 36, relativeTo: .title2)
        .dynamicPadding(.vertical, base: 32, relativeTo: .title2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sessionItemCardStyle()
        .task { await generateExplanation() }
    }

    // MARK: - Sub-views

    private var stageLabel: some View {
        SessionStageBadge(label: "EXPLANATION", icon: "sparkles", tint: DesignSystem.Colors.studyAccentBright)
    }

    private var loadingIndicator: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView().controlSize(.small).tint(DesignSystem.Colors.studyAccentBright)
            Text("Thinking...")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button { onDismiss(true) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                    Text("Got it")
                }
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                        .fill(DesignSystem.Colors.studyAccentDeep)
                )
            }
            .buttonStyle(.plain)

            Button { onDismiss(false) } label: {
                Text("Still confused")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Explanation Generation

    private func generateExplanation() async {
        if !item.materialChunks.isEmpty {
            explanationText = item.materialChunks.joined(separator: "\n\n")
        } else {
            explanationText = "Generating explanation for **\(item.conceptName)**..."
        }
        isLoading = false
    }
}
