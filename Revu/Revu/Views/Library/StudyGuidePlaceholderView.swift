import SwiftUI

/// A placeholder detail surface for viewing a StudyGuide.
/// Future iterations will add markdown editing and outline navigation.
struct StudyGuidePlaceholderView: View {
    let studyGuide: StudyGuide

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            header
            contentSection
            Spacer()
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignSystem.Colors.window)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text(studyGuide.title)
                    .font(DesignSystem.Typography.hero)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }

            let wordCount = studyGuide.markdownContent.split(whereSeparator: \.isWhitespace).count
            Label("\(wordCount) words", systemImage: "doc.text")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if studyGuide.markdownContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                Text("No content yet")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Edit this study guide to add markdown content.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xxl)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Content")
                        .font(DesignSystem.Typography.heading)
                        .foregroundStyle(DesignSystem.Colors.primaryText)

                    Text(studyGuide.markdownContent)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.subtleOverlay)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            }
        }
    }
}

#if DEBUG
struct StudyGuidePlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        let guide = StudyGuide(
            title: "Cell Biology Notes",
            markdownContent: """
            # Cell Structure
            
            ## Organelles
            
            - **Mitochondria**: The powerhouse of the cell
            - **Nucleus**: Contains genetic material
            - **Ribosomes**: Protein synthesis
            
            ## Cell Membrane
            
            The cell membrane is a phospholipid bilayer that controls what enters and exits the cell.
            """
        )
        StudyGuidePlaceholderView(studyGuide: guide)
            .frame(width: 600, height: 500)
    }
}
#endif
