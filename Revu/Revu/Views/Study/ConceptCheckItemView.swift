import SwiftUI

/// Quick concept verification: a question with text input and heuristic feedback.
///
/// Flow: question displayed -> student types answer -> "Check Answer" ->
/// local heuristics evaluate -> shows correct/incorrect feedback -> "Continue" advances session.
struct ConceptCheckItemView: View {
    let item: ConceptCheckItem
    let onAnswer: (Bool) -> Void  // wasCorrect

    @State private var userAnswer: String = ""
    @State private var feedbackState: FeedbackState = .unanswered
    @State private var feedbackText: String = ""
    @State private var isChecking = false
    @FocusState private var isTextFieldFocused: Bool

    private enum FeedbackState {
        case unanswered
        case correct
        case incorrect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Stage label
            stageLabel

            // Question
            Text(item.question)
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            // Answer input
            if feedbackState == .unanswered {
                answerInput
            }

            // Feedback
            if feedbackState != .unanswered {
                feedbackView
            }

            // Action buttons
            actionButtons
        }
        .dynamicPadding(.horizontal, base: 36, relativeTo: .title2)
        .dynamicPadding(.vertical, base: 32, relativeTo: .title2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sessionItemCardStyle()
        .onAppear { isTextFieldFocused = true }
    }

    // MARK: - Sub-views

    private var stageLabel: some View {
        SessionStageBadge(label: "CONCEPT CHECK", icon: "sparkles", tint: DesignSystem.Colors.studyAccentBright)
    }

    private var answerInput: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            TextField("Type your answer...", text: $userAnswer, axis: .vertical)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .focused($isTextFieldFocused)
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.lightOverlay)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
                )
        }
    }

    private var feedbackView: some View {
        let isCorrect = feedbackState == .correct
        let tint: Color = isCorrect ? DesignSystem.Colors.feedbackSuccess : DesignSystem.Colors.feedbackError

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(tint)
                Text(isCorrect ? "Correct!" : "Not quite...")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(tint)
            }

            if !feedbackText.isEmpty {
                MarkdownText(feedbackText)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }

            // Show what the student wrote
            Text("Your answer: \(userAnswer)")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                .lineLimit(2)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch feedbackState {
        case .unanswered:
            Button {
                Task { await checkAnswer() }
            } label: {
                HStack {
                    if isChecking {
                        ProgressView().controlSize(.small)
                    }
                    Text("Check Answer")
                        .font(DesignSystem.Typography.bodyMedium)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? DesignSystem.Colors.accent.opacity(0.4)
                              : DesignSystem.Colors.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChecking)

        case .correct, .incorrect:
            Button {
                onAnswer(feedbackState == .correct)
            } label: {
                Text("Continue")
                    .font(DesignSystem.Typography.bodyMedium)
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
    }

    // MARK: - Answer Checking

    private func checkAnswer() async {
        isChecking = true
        defer { isChecking = false }

        // Compare the response against expected keywords for a fast local check.
        let trimmedAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let expectedWords = item.expectedInsight.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 }

        // Simple heuristic: if the answer contains at least one meaningful keyword
        let matchCount = expectedWords.filter { trimmedAnswer.contains($0) }.count
        let isCorrect = !expectedWords.isEmpty && Double(matchCount) / Double(expectedWords.count) >= 0.3

        withAnimation(DesignSystem.Animation.layout) {
            if isCorrect {
                feedbackState = .correct
                feedbackText = "Good understanding of the concept."
            } else {
                feedbackState = .incorrect
                feedbackText = item.expectedInsight
            }
        }
    }
}
