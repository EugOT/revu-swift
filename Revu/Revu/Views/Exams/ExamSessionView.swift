import SwiftUI

/// The main exam-taking session view.
/// Provides start screen, question navigation, answer selection, timer, and submit flow.
struct ExamSessionView: View {
    @Environment(\.storage) private var storage
    @Binding var exam: Exam
    let onClose: () -> Void
    
    enum SessionPhase {
        case start
        case inProgress
        case results
    }
    
    @State private var phase: SessionPhase = .start
    @State private var currentQuestionIndex = 0
    @State private var answers: [UUID: Int] = [:] // questionId -> selectedChoiceIndex
    @State private var shuffledQuestions: [Exam.Question] = []
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showSubmitConfirmation = false
    
    private var currentQuestion: Exam.Question? {
        guard shuffledQuestions.indices.contains(currentQuestionIndex) else { return nil }
        return shuffledQuestions[currentQuestionIndex]
    }
    
    private var answeredCount: Int {
        shuffledQuestions.filter { answers[$0.id] != nil }.count
    }
    
    private var timeRemaining: TimeInterval? {
        guard let limit = exam.config.timeLimit else { return nil }
        return max(0, Double(limit) - elapsedSeconds)
    }
    
    private var isTimeUp: Bool {
        if let remaining = timeRemaining {
            return remaining <= 0
        }
        return false
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.canvasBackground
                .ignoresSafeArea()
            
            switch phase {
            case .start:
                startScreen
            case .inProgress:
                examContent
            case .results:
                ExamResultsView(
                    exam: exam,
                    answers: answers,
                    onRetake: retakeExam,
                    onClose: onClose
                )
            }
        }
        .confirmationDialog(
            "Submit Exam?",
            isPresented: $showSubmitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Submit") {
                submitExam()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have answered \(answeredCount) of \(shuffledQuestions.count) questions. Are you sure you want to submit?")
        }
        .onChange(of: isTimeUp) { _, timeUp in
            if timeUp && phase == .inProgress {
                submitExam()
            }
        }
    }
    
    // MARK: - Start Screen
    
    private var startScreen: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer(minLength: DesignSystem.Spacing.lg)

            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(spacing: DesignSystem.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.studyAccentDeep.opacity(0.14))
                            .frame(width: 72, height: 72)
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(DesignSystem.Typography.title)
                            .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                    }

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text(displayTitle)
                            .font(DesignSystem.Typography.title)
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                            .multilineTextAlignment(.center)
                        Text("Focus on one question at a time. Your progress updates continuously.")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 520)
                    }
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    startMetricPill(text: "\(exam.questions.count) questions", icon: "list.number")
                    if let limit = exam.config.timeLimit {
                        startMetricPill(text: "\(limit / 60) min", icon: "timer")
                    }
                    if exam.config.shuffleQuestions {
                        startMetricPill(text: "Shuffle on", icon: "shuffle")
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.xxl)
            .frame(maxWidth: 760)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                    .fill(DesignSystem.Colors.window)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )

            VStack(spacing: DesignSystem.Spacing.md) {
                if exam.questions.isEmpty {
                    Text("This exam has no questions yet.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)

                    Button {
                        onClose()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "arrow.left")
                                .font(DesignSystem.Typography.captionMedium)
                            Text("Back to Editor")
                                .font(DesignSystem.Typography.bodyMedium)
                        }
                        .secondaryButtonStyle()
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        beginExam()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "play.fill")
                                .font(DesignSystem.Typography.captionMedium)
                            Text("Begin Exam")
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
                        .shadow(color: DesignSystem.Colors.studyAccentGlow.opacity(0.22), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])

                    Button {
                        onClose()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: DesignSystem.Spacing.xl)
        }
        .padding(DesignSystem.Spacing.xl)
    }

    private var displayTitle: String {
        let trimmed = exam.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Exam" : trimmed
    }

    private func startMetricPill(text: String, icon: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.smallMedium)
            Text(text)
                .font(DesignSystem.Typography.captionMedium)
        }
        .foregroundStyle(DesignSystem.Colors.secondaryText)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.subtleOverlay)
        )
        .overlay(
            Capsule()
                .stroke(DesignSystem.Colors.separator.opacity(0.7), lineWidth: 1)
        )
    }
    
    // MARK: - Exam Content
    
    private var examContent: some View {
        VStack(spacing: 0) {
            examHeader
            
            Divider()
                .background(DesignSystem.Colors.separator)
            
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if let question = currentQuestion {
                        questionCard(question)
                    }
                    
                    navigationControls
                }
                .padding(DesignSystem.Spacing.xl)
                .frame(maxWidth: 980)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
        }
    }
    
    private var examHeader: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            // Back/close button
            Button {
                showSubmitConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(DesignSystem.Colors.subtleOverlay)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Progress indicator
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("Question \(currentQuestionIndex + 1) of \(shuffledQuestions.count)")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                ProgressView(value: Double(currentQuestionIndex + 1), total: Double(shuffledQuestions.count))
                    .progressViewStyle(.linear)
                    .tint(DesignSystem.Colors.studyAccentBright)
                    .frame(width: 240)
            }
            
            Spacer()
            
            // Timer
            if let remaining = timeRemaining {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: remaining < 60 ? "timer" : "clock")
                        .foregroundStyle(remaining < 60 ? DesignSystem.Colors.feedbackError : DesignSystem.Colors.secondaryText)
                    Text(formatTime(remaining))
                        .font(DesignSystem.Typography.mono)
                        .foregroundStyle(remaining < 60 ? DesignSystem.Colors.feedbackError : DesignSystem.Colors.primaryText)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    remaining < 60 ? DesignSystem.Colors.feedbackError.opacity(0.1) : DesignSystem.Colors.studyAccentDeep.opacity(0.10)
                )
                .clipShape(Capsule())
            }
            
            // Question navigator
            questionNavigator
            
            // Submit button
            Button {
                showSubmitConfirmation = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DesignSystem.Typography.captionMedium)
                    Text("Submit")
                        .font(DesignSystem.Typography.captionMedium)
                }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Gradients.studyAccentDiagonal)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(DesignSystem.Colors.studyAccentBorder.opacity(0.8), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.topBarBackground)
    }
    
    private var questionNavigator: some View {
        Menu {
            ForEach(Array(shuffledQuestions.enumerated()), id: \.element.id) { index, question in
                Button {
                    currentQuestionIndex = index
                } label: {
                    HStack {
                        Text("Question \(index + 1)")
                        Spacer()
                        if answers[question.id] != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "list.number")
                    .font(DesignSystem.Typography.smallMedium)
                Text("\(answeredCount)/\(shuffledQuestions.count)")
                    .font(DesignSystem.Typography.captionMedium)
                Image(systemName: "chevron.down")
                    .font(DesignSystem.Typography.smallMedium)
            }
            .foregroundStyle(DesignSystem.Colors.secondaryText)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.Colors.hoverBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
        }
        .menuIndicator(.hidden)
    }
    
    // MARK: - Question Card
    
    private func questionCard(_ question: Exam.Question) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Question prompt
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: "text.quote")
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    Text("Question \(currentQuestionIndex + 1)")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                
                Text(question.prompt)
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            
            Divider()
                .background(DesignSystem.Colors.separator)
            
            // Choices
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                    choiceButton(
                        question: question,
                        choiceIndex: choiceIndex,
                        choice: choice
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(DesignSystem.Colors.window)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    private func choiceButton(question: Exam.Question, choiceIndex: Int, choice: String) -> some View {
        let isSelected = answers[question.id] == choiceIndex
        
        return Button {
            selectAnswer(for: question.id, choiceIndex: choiceIndex)
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Choice letter/number
                Text("\(choiceIndex + 1)")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(isSelected ? .white : DesignSystem.Colors.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isSelected ? DesignSystem.Colors.studyAccentMid : DesignSystem.Colors.window)
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? DesignSystem.Colors.studyAccentBorder : DesignSystem.Colors.separator, lineWidth: 1)
                    )
                
                Text(choice.isEmpty ? "Untitled choice" : choice)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.studyAccentDeep.opacity(0.12) : DesignSystem.Colors.window)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(isSelected ? DesignSystem.Colors.studyAccentBorder : DesignSystem.Colors.separator, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(choiceIndex + 1)")), modifiers: [])
    }
    
    // MARK: - Navigation Controls
    
    private var navigationControls: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Previous button
            Button {
                if currentQuestionIndex > 0 {
                    withAnimation(DesignSystem.Animation.quick) {
                        currentQuestionIndex -= 1
                    }
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "chevron.left")
                        .font(DesignSystem.Typography.captionMedium)
                    Text("Previous")
                        .font(DesignSystem.Typography.bodyMedium)
                }
                .secondaryButtonStyle()
            }
            .buttonStyle(.plain)
            .disabled(currentQuestionIndex == 0)
            .opacity(currentQuestionIndex == 0 ? 0.5 : 1)
            .keyboardShortcut(.leftArrow, modifiers: [])
            
            Spacer()
            
            // Question dots
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Array(shuffledQuestions.enumerated()), id: \.element.id) { index, question in
                    Circle()
                        .fill(
                            index == currentQuestionIndex ? DesignSystem.Colors.studyAccentBright :
                            (answers[question.id] != nil ? DesignSystem.Colors.studyAccentBright.opacity(0.42) : DesignSystem.Colors.separator)
                        )
                        .frame(width: 8, height: 8)
                        .onTapGesture {
                            withAnimation(DesignSystem.Animation.quick) {
                                currentQuestionIndex = index
                            }
                        }
                }
            }
            
            Spacer()
            
            // Next button
            if currentQuestionIndex < shuffledQuestions.count - 1 {
                Button {
                    withAnimation(DesignSystem.Animation.quick) {
                        currentQuestionIndex += 1
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Next")
                            .font(DesignSystem.Typography.bodyMedium)
                        Image(systemName: "chevron.right")
                            .font(DesignSystem.Typography.captionMedium)
                    }
                    .secondaryButtonStyle()
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.rightArrow, modifiers: [])
            } else {
                Button {
                    showSubmitConfirmation = true
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(DesignSystem.Typography.captionMedium)
                        Text("Finish")
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
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }
    
    // MARK: - Actions
    
    private func beginExam() {
        // Shuffle questions if configured
        if exam.config.shuffleQuestions {
            shuffledQuestions = exam.questions.shuffled()
        } else {
            shuffledQuestions = exam.questions
        }
        
        currentQuestionIndex = 0
        answers = [:]
        elapsedSeconds = 0
        
        // Start timer
        startTimer()
        
        withAnimation(DesignSystem.Animation.smooth) {
            phase = .inProgress
        }
    }
    
    private func selectAnswer(for questionId: UUID, choiceIndex: Int) {
        withAnimation(DesignSystem.Animation.quick) {
            answers[questionId] = choiceIndex
        }
    }
    
    private func submitExam() {
        stopTimer()
        withAnimation(DesignSystem.Animation.smooth) {
            phase = .results
        }
    }
    
    private func retakeExam() {
        withAnimation(DesignSystem.Animation.smooth) {
            phase = .start
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

#if DEBUG
struct ExamSessionView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var exam = Exam(
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
                ),
                Exam.Question(
                    prompt: "What is the process by which plants convert sunlight into energy?",
                    choices: ["Respiration", "Photosynthesis", "Fermentation", "Digestion"],
                    correctChoiceIndex: 1
                )
            ]
        )
        
        var body: some View {
            ExamSessionView(exam: $exam, onClose: {})
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .frame(width: 900, height: 700)
    }
}
#endif
