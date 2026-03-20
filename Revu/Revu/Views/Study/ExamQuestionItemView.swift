import SwiftUI

/// Exam-style question with multiline answer input, submit, and skip.
///
/// Flow: question displayed -> student writes answer in TextEditor ->
/// "Submit Answer" applies a local scoring heuristic -> feedback shown -> "Continue".
/// "Skip" advances without marking success or failure.
struct ExamQuestionItemView: View {
    let item: ExamQuestionItem
    let onAnswer: (Bool) -> Void  // wasSuccessful

    @State private var userAnswer: String = ""
    @State private var feedbackState: FeedbackState = .unanswered
    @State private var feedbackText: String = ""
    @State private var isSubmitting = false
    @FocusState private var isEditorFocused: Bool

    private enum FeedbackState {
        case unanswered
        case passed
        case failed
        case skipped
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Stage label
            stageLabel

            // Question (may be multi-paragraph)
            MarkdownText(item.question)
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(DesignSystem.Colors.primaryText)

            // Answer area
            if feedbackState == .unanswered {
                answerEditor
            }

            // Feedback
            if feedbackState == .passed || feedbackState == .failed {
                feedbackView
            }

            // Action buttons
            actionButtons
        }
        .dynamicPadding(.horizontal, base: 36, relativeTo: .title2)
        .dynamicPadding(.vertical, base: 32, relativeTo: .title2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sessionItemCardStyle()
        .onAppear { isEditorFocused = true }
    }

    // MARK: - Sub-views

    private var stageLabel: some View {
        SessionStageBadge(label: "CHALLENGE", icon: "bolt.fill", tint: DesignSystem.Colors.feedbackWarning)
    }

    private var answerEditor: some View {
        TextEditor(text: $userAnswer)
            .font(DesignSystem.Typography.body)
            .foregroundStyle(DesignSystem.Colors.primaryText)
            .scrollContentBackground(.hidden)
            .focused($isEditorFocused)
            .frame(minHeight: 120, maxHeight: 240)
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(DesignSystem.Colors.lightOverlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if userAnswer.isEmpty {
                    Text("Your answer...")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .padding(DesignSystem.Spacing.sm)
                        .padding(.top, DesignSystem.Spacing.xs)
                        .padding(.leading, DesignSystem.Spacing.xxs)
                        .allowsHitTesting(false)
                }
            }
    }

    private var feedbackView: some View {
        let isPassed = feedbackState == .passed
        let tint: Color = isPassed ? DesignSystem.Colors.feedbackSuccess : DesignSystem.Colors.feedbackError

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(tint)
                Text(isPassed ? "Good answer" : "Needs work")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(tint)
            }

            if !feedbackText.isEmpty {
                MarkdownText(feedbackText)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
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
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    Task { await submitAnswer() }
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView().controlSize(.small)
                        }
                        Text("Submit Answer")
                            .font(DesignSystem.Typography.bodyMedium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                            .fill(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? DesignSystem.Colors.feedbackWarning.opacity(0.4)
                                  : DesignSystem.Colors.feedbackWarning)
                    )
                }
                .buttonStyle(.plain)
                .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

                Button {
                    skip()
                } label: {
                    Text("Skip")
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

        case .passed, .failed:
            Button {
                onAnswer(feedbackState == .passed)
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

        case .skipped:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func submitAnswer() async {
        isSubmitting = true
        defer { isSubmitting = false }

        // Simple local rubric-based evaluation.
        let trimmedAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmedAnswer.components(separatedBy: .whitespacesAndNewlines).count

        // Simple heuristic: answers with reasonable length are considered passing
        let passed = wordCount >= 8

        withAnimation(DesignSystem.Animation.layout) {
            if passed {
                feedbackState = .passed
                feedbackText = "Your response demonstrates a reasonable understanding of the concept."
            } else {
                feedbackState = .failed
                feedbackText = item.rubric ?? "Try to provide a more detailed answer that addresses the key aspects of the question."
            }
        }
    }

    private func skip() {
        feedbackState = .skipped
        // Skip counts as neither success nor failure
        onAnswer(false)
    }
}
