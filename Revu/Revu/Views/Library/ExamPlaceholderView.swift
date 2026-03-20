import SwiftUI

/// A placeholder detail surface for viewing an Exam.
/// Future iterations will add exam taking, editing, and scoring UI.
struct ExamPlaceholderView: View {
    let exam: Exam

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            header
            questionsSection
            Spacer()
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignSystem.Colors.window)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "doc.questionmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text(exam.title)
                    .font(DesignSystem.Typography.hero)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Label("\(exam.questions.count) questions", systemImage: "list.number")
                if let limit = exam.config.timeLimit {
                    Label("\(limit / 60) min", systemImage: "timer")
                }
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private var questionsSection: some View {
        if exam.questions.isEmpty {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                Text("No questions yet")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Edit this exam to add multiple-choice questions.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xxl)
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Questions")
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                ForEach(Array(exam.questions.enumerated()), id: \.element.id) { index, question in
                    questionRow(index: index + 1, question: question)
                }
            }
        }
    }

    private func questionRow(index: Int, question: Exam.Question) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Text("\(index).")
                    .font(DesignSystem.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .frame(width: 28, alignment: .trailing)
                Text(question.prompt)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }

            if !question.choices.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            let isCorrect = choiceIndex == question.correctChoiceIndex
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(isCorrect ? Color.green : DesignSystem.Colors.tertiaryText)
                            Text(choice)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(isCorrect ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                        }
                        .padding(.leading, 36)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.subtleOverlay)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
    }
}

#if DEBUG
struct ExamPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        let exam = Exam(
            title: "Biology Midterm",
            config: Exam.Config(timeLimit: 3600, shuffleQuestions: true),
            questions: [
                Exam.Question(
                    prompt: "What is the powerhouse of the cell?",
                    choices: ["Nucleus", "Mitochondria", "Ribosome", "Golgi apparatus"],
                    correctChoiceIndex: 1
                ),
                Exam.Question(
                    prompt: "Which molecule carries genetic information?",
                    choices: ["RNA", "DNA", "Protein", "Lipid"],
                    correctChoiceIndex: 1
                )
            ]
        )
        ExamPlaceholderView(exam: exam)
            .frame(width: 600, height: 500)
    }
}
#endif
