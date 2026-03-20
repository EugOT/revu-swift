import SwiftUI

/// Sheet for pasting raw text that will be sent to the AI deck generator.
struct PasteTextForCardsSheet: View {
    @Binding var text: String
    var onGenerate: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header
            HStack {
                Label("Generate Cards from Text", systemImage: "doc.on.clipboard")
                    .font(DesignSystem.Typography.subheading)
                Spacer()
                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }

            Text("Paste your notes, lecture content, or study material below. The AI will generate flashcards from it.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)

            // Text editor
            TextEditor(text: $text)
                .font(DesignSystem.Typography.body)
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.subtleOverlay)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                )

            // Footer
            HStack {
                Text("\(text.split(separator: " ").count) words")
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)

                Spacer()

                Button("Generate Cards") {
                    onGenerate(text)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.primaryText)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(minWidth: 500, minHeight: 350)
    }
}
