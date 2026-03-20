import SwiftUI

/// A view displaying exam results after submission.
/// Shows score, per-question review with correctness indicators, and explanations.
struct ExamResultsView: View {
    let exam: Exam
    let answers: [UUID: Int] // questionId -> selected choice index
    let onRetake: () -> Void
    let onClose: () -> Void
    
    private var score: Int {
        exam.questions.reduce(0) { total, question in
            if let selected = answers[question.id], selected == question.correctChoiceIndex {
                return total + 1
            }
            return total
        }
    }
    
    private var scorePercentage: Double {
        guard !exam.questions.isEmpty else { return 0 }
        return Double(score) / Double(exam.questions.count) * 100
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                scoreHeader
                questionReview
                actionButtons
            }
            .padding(DesignSystem.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.canvasBackground)
    }
    
    // MARK: - Score Header
    
    private var scoreHeader: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.separator, lineWidth: 8)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: scorePercentage / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(DesignSystem.Animation.layout, value: scorePercentage)
                
                VStack(spacing: DesignSystem.Spacing.xxs) {
                    Text("\(Int(scorePercentage.rounded()))%")
                        .font(DesignSystem.Typography.hero)
                        .foregroundStyle(scoreColor)
                    Text("\(score)/\(exam.questions.count)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
            }
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(scoreMessage)
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                Text(exam.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }
    
    private var scoreColor: Color {
        switch scorePercentage {
        case 90...100: return DesignSystem.Colors.studyAccentBright
        case 70..<90: return DesignSystem.Colors.studyAccentMid
        case 50..<70: return DesignSystem.Colors.feedbackWarning
        default: return DesignSystem.Colors.feedbackError
        }
    }
    
    private var scoreMessage: String {
        switch scorePercentage {
        case 90...100: return "Excellent!"
        case 70..<90: return "Good job!"
        case 50..<70: return "Keep practicing"
        default: return "Needs improvement"
        }
    }
    
    // MARK: - Question Review
    
    private var questionReview: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "list.clipboard")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Question Review")
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            
            ForEach(Array(exam.questions.enumerated()), id: \.element.id) { index, question in
                questionReviewCard(index: index, question: question)
            }
        }
    }
    
    private func questionReviewCard(index: Int, question: Exam.Question) -> some View {
        let selectedIndex = answers[question.id]
        let isCorrect = selectedIndex == question.correctChoiceIndex
        let answered = selectedIndex != nil
        
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Question header with result indicator
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                // Result badge
                Image(systemName: isCorrect ? "checkmark.circle.fill" : (answered ? "xmark.circle.fill" : "minus.circle.fill"))
                    .font(DesignSystem.Typography.subheading)
                    .foregroundStyle(isCorrect ? DesignSystem.Colors.studyAccentBright : (answered ? DesignSystem.Colors.feedbackError : DesignSystem.Colors.tertiaryText))
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Question \(index + 1)")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    
                    Text(question.prompt)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                
                Spacer()
            }
            
            // Choices review
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                    choiceReviewRow(
                        choice: choice,
                        choiceIndex: choiceIndex,
                        isSelected: selectedIndex == choiceIndex,
                        isCorrect: choiceIndex == question.correctChoiceIndex
                    )
                }
            }
            .padding(.leading, DesignSystem.Spacing.lg)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(isCorrect ? DesignSystem.Colors.studyAccentDeep.opacity(0.08) : (answered ? DesignSystem.Colors.feedbackError.opacity(0.05) : DesignSystem.Colors.window))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(isCorrect ? DesignSystem.Colors.studyAccentBorder.opacity(0.9) : (answered ? DesignSystem.Colors.feedbackError.opacity(0.3) : DesignSystem.Colors.separator.opacity(0.7)), lineWidth: 1)
        )
    }
    
    private func choiceReviewRow(choice: String, choiceIndex: Int, isSelected: Bool, isCorrect: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Choice indicator
            ZStack {
                if isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                } else if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.feedbackError)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
            }
            .font(DesignSystem.Typography.bodyMedium)
            
            Text(choice)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(
                    isCorrect ? DesignSystem.Colors.studyAccentBright :
                    (isSelected ? DesignSystem.Colors.feedbackError : DesignSystem.Colors.secondaryText)
                )
                .fontWeight(isCorrect || isSelected ? .medium : .regular)
            
            Spacer()
            
            // Labels
            if isCorrect {
                Text("Correct")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                    .background(DesignSystem.Colors.studyAccentDeep.opacity(0.16))
                    .clipShape(Capsule())
            }
            if isSelected && !isCorrect {
                Text("Your answer")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.feedbackError)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                    .background(DesignSystem.Colors.feedbackError.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                onRetake()
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "arrow.clockwise")
                        .font(DesignSystem.Typography.captionMedium)
                    Text("Retake")
                        .font(DesignSystem.Typography.bodyMedium)
                }
                .secondaryButtonStyle()
            }
            .buttonStyle(.plain)
            
            Button {
                onClose()
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DesignSystem.Typography.captionMedium)
                    Text("Done")
                        .font(DesignSystem.Typography.bodyMedium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    Capsule()
                        .fill(DesignSystem.Gradients.studyAccentDiagonal)
                )
                .overlay(
                    Capsule()
                        .stroke(DesignSystem.Colors.studyAccentBorder.opacity(0.82), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, DesignSystem.Spacing.md)
    }
}

#if DEBUG
struct ExamResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let exam = Exam(
            title: "Biology Midterm",
            questions: [
                Exam.Question(
                    id: UUID(),
                    prompt: "What is the powerhouse of the cell?",
                    choices: ["Nucleus", "Mitochondria", "Ribosome", "Golgi apparatus"],
                    correctChoiceIndex: 1
                ),
                Exam.Question(
                    id: UUID(),
                    prompt: "Which molecule carries genetic information?",
                    choices: ["RNA", "DNA", "Protein", "Lipid"],
                    correctChoiceIndex: 1
                )
            ]
        )
        
        let answers: [UUID: Int] = [
            exam.questions[0].id: 1, // Correct
            exam.questions[1].id: 0  // Incorrect
        ]
        
        ExamResultsView(
            exam: exam,
            answers: answers,
            onRetake: {},
            onClose: {}
        )
        .frame(width: 700, height: 800)
    }
}
#endif
