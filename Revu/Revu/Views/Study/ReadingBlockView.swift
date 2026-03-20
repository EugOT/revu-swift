import SwiftUI

/// Renders markdown content from a study guide with a "Done Reading" button.
///
/// Used to surface relevant reading material mid-session when the engine
/// detects a student needs to review foundational content.
struct ReadingBlockView: View {
    let item: ReadingBlockItem
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Stage label
            stageLabel

            // Section title
            Text(item.title)
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(DesignSystem.Colors.primaryText)

            // Markdown content
            MarkdownText(item.content)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.primaryText)

            // Done button
            Button {
                onDone()
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Done Reading")
                        .font(DesignSystem.Typography.bodyMedium)
                    Image(systemName: "checkmark")
                        .font(DesignSystem.Typography.captionMedium)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .dynamicPadding(.horizontal, base: 36, relativeTo: .title2)
        .dynamicPadding(.vertical, base: 32, relativeTo: .title2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sessionItemCardStyle()
    }

    // MARK: - Sub-views

    private var stageLabel: some View {
        SessionStageBadge(label: "REVIEW", icon: "book", tint: DesignSystem.Colors.feedbackInfo)
    }
}
