import SwiftUI

/// A unified exam surface that handles both editing and session modes.
/// This view manages the exam state and routes to either ExamEditorView or ExamSessionView.
struct ExamSurfaceView: View {
    @Environment(\.storage) private var storage
    @Environment(\.colorScheme) private var colorScheme
    @State private var exam: Exam
    @State private var mode: Mode = .editor
    @State private var isLoading = false
    @State private var examDirective: StudyDirective?

    enum Mode {
        case editor
        case session
    }

    init(exam: Exam) {
        _exam = State(initialValue: exam)
    }

    var body: some View {
        Group {
            switch mode {
            case .editor:
                editorView
            case .session:
                ExamSessionView(exam: $exam, onClose: endSession)
            }
        }
        .task(id: exam.id) {
            examDirective = await StudyDirectiveEngine().generateDirective()
        }
        .onChange(of: exam.id) { _, newId in
            Task { await loadExam(id: newId) }
        }
    }

    private var editorView: some View {
        VStack(spacing: 0) {
            editorTopBar

            Divider()
                .background(DesignSystem.Colors.separator)

            if let courseId = exam.courseId {
                ExamReadinessView(
                    courseId: courseId,
                    examTitle: examTitle,
                    daysUntilExam: examDirective?.examCountdown?.daysRemaining
                )
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.md)
            }

            ExamEditorView(exam: $exam)
                .workspaceCanvasSurface()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .workspaceCanvasSurface()
    }

    private var editorTopBar: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Text("Exam Workspace")
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .textCase(.uppercase)
                        .tracking(0.8)
                }

                Text(examTitle)
                    .font(DesignSystem.Typography.subheading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    metadataPill("\(exam.questions.count)", "questionmark.bubble")
                    if let limit = exam.config.timeLimit {
                        metadataPill("\(limit / 60)m", "timer")
                    }
                    if exam.config.shuffleQuestions {
                        metadataPill("Shuffle", "shuffle")
                    }
                }

                if let countdown = examDirective?.examCountdown {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.accent)

                        if let score = countdown.estimatedScore {
                            Text("Based on your mastery, you'd score ~\(Int(score * 100))% right now.")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }

                        if countdown.daysRemaining > 0 {
                            Text("\(countdown.daysRemaining) days remaining")
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xxs)
                                .background(Capsule().fill(DesignSystem.Colors.accent.opacity(0.12)))
                        }
                    }
                    .padding(DesignSystem.Spacing.sm)
                }
            }

            Spacer()

            Button(action: startSession) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Take Exam")
                        .font(DesignSystem.Typography.smallMedium)
                }
                .foregroundStyle(Color.white.opacity(0.96))
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    Capsule()
                        .fill(DesignSystem.Gradients.studyAccentDiagonal)
                )
                .overlay(
                    Capsule()
                        .stroke(DesignSystem.Colors.studyAccentBorder.opacity(0.86), lineWidth: 1)
                )
                .shadow(
                    color: DesignSystem.Colors.studyAccentGlow.opacity(colorScheme == .dark ? 0.24 : 0.2),
                    radius: 8,
                    x: 0,
                    y: 3
                )
            }
            .buttonStyle(.plain)
            .disabled(!canStartSession || isLoading)
            .opacity(!canStartSession || isLoading ? 0.5 : 1)
            .help(exam.questions.isEmpty ? "Add questions to take the exam" : "Start the exam")
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.top, DesignSystem.Spacing.sm)
        .padding(.bottom, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.topBarBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.separator.opacity(0.5))
                .frame(height: 1)
        }
    }

    private var examTitle: String {
        let trimmed = exam.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Exam" : trimmed
    }

    private var canStartSession: Bool {
        !exam.questions.isEmpty
    }

    private func metadataPill(_ text: String, _ icon: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(DesignSystem.Typography.captionMedium)
        }
        .foregroundStyle(DesignSystem.Colors.secondaryText)
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.subtleOverlay)
        )
        .overlay(
            Capsule()
                .stroke(DesignSystem.Colors.separator.opacity(0.7), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func startSession() {
        withAnimation(DesignSystem.Animation.smooth) {
            mode = .session
        }
    }

    private func endSession() {
        Task {
            await loadExam(id: exam.id)
            await MainActor.run {
                withAnimation(DesignSystem.Animation.smooth) {
                    mode = .editor
                }
            }
        }
    }

    @MainActor
    private func loadExam(id: UUID) async {
        isLoading = true
        defer { isLoading = false }

        if let examDTO = try? await storage.exam(withId: id) {
            exam = examDTO.toDomain()
        }
    }
}

#if DEBUG
struct ExamSurfaceView_Previews: PreviewProvider {
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

        ExamSurfaceView(exam: exam)
            .frame(width: 980, height: 760)
    }
}
#endif
