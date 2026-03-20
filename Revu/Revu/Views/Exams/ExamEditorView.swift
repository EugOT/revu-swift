import SwiftUI

/// A design-system aligned editor for authoring MCQ exams.
/// Focuses on low-friction question creation with autosave and scalable list rendering.
struct ExamEditorView: View {
    @Environment(\.storage) private var storage
    @Binding var exam: Exam

    @State private var editingQuestionId: UUID?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var lastSavedAt: Date?
    @State private var hasPendingChanges = false
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var focusedQuestionId: UUID?

    var body: some View {
        WorkspaceCanvas { _ in
            heroSection
            metadataFields
            questionsSection
        }
        .alert(
            "Save Error",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK") {
                saveError = nil
            }
        } message: {
            if let saveError {
                Text(saveError)
            }
        }
        .onDisappear {
            saveTask?.cancel()
            if hasPendingChanges {
                Task { await performSave() }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            TextField("Untitled Exam", text: Binding(
                get: { exam.title },
                set: { newValue in
                    exam.title = newValue
                    scheduleAutoSave()
                }
            ))
            .textFieldStyle(.plain)
            .font(DesignSystem.Typography.heading)
            .foregroundStyle(DesignSystem.Colors.primaryText)

            Spacer()

            saveStatusPill
        }
    }

    private var saveStatusPill: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if isSaving {
                ProgressView()
                    .controlSize(.small)
                Text("Saving…")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            } else if hasPendingChanges {
                Image(systemName: "clock.badge")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Unsaved changes")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                Text(savedTimestamp)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.subtleOverlay)
        )
        .overlay(
            Capsule()
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    private var savedTimestamp: String {
        guard let lastSavedAt else { return "All changes saved" }
        return "Saved at \(lastSavedAt.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Metadata (inline fields, no card)

    private var metadataFields: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: "timer")
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    Text("Time Limit")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    TextField("Optional", value: timeLimitMinutesBinding, format: .number)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.hoverBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                        )
                        .frame(maxWidth: 120)

                    Text("minutes")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)

                    if exam.config.timeLimit != nil {
                        IconButton("xmark.circle.fill", size: 28) {
                            exam.config.timeLimit = nil
                            scheduleAutoSave()
                        }
                        .help("Clear time limit")
                    }
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: "shuffle")
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    Text("Question Order")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                HStack {
                    Text("Shuffle questions")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    Spacer()
                    DesignSystemToggle(isOn: Binding(
                        get: { exam.config.shuffleQuestions },
                        set: { newValue in
                            exam.config.shuffleQuestions = newValue
                            scheduleAutoSave()
                        }
                    ))
                }
            }
        }
    }

    private var timeLimitMinutesBinding: Binding<Int?> {
        Binding(
            get: { exam.config.timeLimit.map { $0 / 60 } },
            set: { newValue in
                exam.config.timeLimit = newValue.map { $0 * 60 }
                scheduleAutoSave()
            }
        )
    }

    // MARK: - Questions

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Divider()
                .foregroundStyle(DesignSystem.Colors.separator)
                .padding(.bottom, DesignSystem.Spacing.xs)

            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        Text("Questions")
                            .font(DesignSystem.Typography.heading)
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                    }

                    Text("\(readyQuestionCount) ready · \(draftQuestionCount) draft")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                Menu {
                    ForEach(QuestionTemplate.allCases.filter { $0 != .blank }) { template in
                        Button {
                            addQuestion(template: template)
                        } label: {
                            Label(template.title, systemImage: template.icon)
                        }
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "wand.and.stars")
                            .font(DesignSystem.Typography.captionMedium)
                        Text("Templates")
                            .font(DesignSystem.Typography.captionMedium)
                        Image(systemName: "chevron.down")
                            .font(DesignSystem.Typography.smallMedium)
                    }
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .fill(DesignSystem.Colors.hoverBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)

                Button {
                    addQuestion(template: .blank)
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(DesignSystem.Typography.captionMedium)
                        Text("Add Question")
                            .font(DesignSystem.Typography.captionMedium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Gradients.studyAccentDiagonal)
                    )
                    .overlay(
                        Capsule()
                            .stroke(DesignSystem.Colors.studyAccentBorder.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: DesignSystem.Colors.studyAccentGlow.opacity(0.2), radius: 7, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .help("Add a blank question (⇧⌘N)")
            }

            if exam.questions.isEmpty {
                emptyQuestionsCard
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(exam.questions.enumerated()), id: \.element.id) { index, question in
                        let isEditing = editingQuestionId == question.id
                        if isEditing {
                            questionCardExpanded(index: index, question: question)
                        } else {
                            questionRowCompact(index: index, question: question)
                        }
                    }
                }
            }
        }
    }

    private var emptyQuestionsCard: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(DesignSystem.Typography.hero)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("No Questions Yet")
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text("Start with a blank prompt or pick a template to build structured questions faster.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            Button {
                addQuestion(template: .blank)
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "plus.circle.fill")
                        .font(DesignSystem.Typography.captionMedium)
                    Text("Add Your First Question")
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
                .shadow(color: DesignSystem.Colors.studyAccentGlow.opacity(0.18), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    private var readyQuestionCount: Int {
        exam.questions.filter { question in
            let promptReady = !question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let nonEmptyChoiceCount = question.choices.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            let hasValidCorrectIndex = question.choices.indices.contains(question.correctChoiceIndex)
            let correctChoiceReady = hasValidCorrectIndex
                && !question.choices[question.correctChoiceIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return promptReady && nonEmptyChoiceCount >= 2 && correctChoiceReady
        }.count
    }

    private var draftQuestionCount: Int {
        max(0, exam.questions.count - readyQuestionCount)
    }

    // MARK: - Compact Question Row (read-only)

    private func questionRowCompact(index: Int, question: Exam.Question) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text("\(index + 1)")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                .frame(width: 24, alignment: .leading)

            Text(question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled question" : question.prompt)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(
                    question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? DesignSystem.Colors.tertiaryText
                        : DesignSystem.Colors.primaryText
                )
                .lineLimit(1)

            Spacer()

            StatusBadge(
                text: questionStatusText(question),
                color: questionStatusColor(question)
            )

            HStack(spacing: DesignSystem.Spacing.xxs) {
                IconButton("pencil", size: 26) {
                    withAnimation(DesignSystem.Animation.quick) {
                        editingQuestionId = question.id
                        focusedQuestionId = question.id
                    }
                }
                .help("Edit question")

                Button {
                    removeQuestion(at: index)
                } label: {
                    Image(systemName: "trash")
                        .font(DesignSystem.Typography.small)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Delete question")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.Colors.subtleOverlay, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(DesignSystem.Animation.quick) {
                editingQuestionId = question.id
                focusedQuestionId = question.id
            }
        }
    }

    // MARK: - Expanded Question Card (editing)

    private func questionCardExpanded(index: Int, question: Exam.Question) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                Text("\(index + 1)")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .frame(width: 24, alignment: .leading)

                StatusBadge(
                    text: questionStatusText(question),
                    color: questionStatusColor(question)
                )

                Spacer()

                HStack(spacing: DesignSystem.Spacing.xs) {
                    SecondaryButton(action: {
                        withAnimation(DesignSystem.Animation.quick) {
                            editingQuestionId = nil
                            focusedQuestionId = nil
                        }
                        scheduleAutoSave()
                    }) {
                        Label("Done", systemImage: "checkmark")
                    }

                    if index > 0 {
                        IconButton("chevron.up", size: 28) {
                            moveQuestion(from: index, to: index - 1)
                        }
                        .help("Move up")
                    }

                    if index < exam.questions.count - 1 {
                        IconButton("chevron.down", size: 28) {
                            moveQuestion(from: index, to: index + 1)
                        }
                        .help("Move down")
                    }

                    Button {
                        removeQuestion(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.feedbackError)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.feedbackError.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Delete question")
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Prompt")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                TextField(
                    "Write a clear question prompt",
                    text: questionPromptBinding(for: question.id),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.bodyMedium)
                .lineLimit(1...4)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.hoverBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                )
                .focused($focusedQuestionId, equals: question.id)
            }

            choicesView(for: question, isEditing: true)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.studyAccentBorder.opacity(0.9), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func choicesView(for question: Exam.Question, isEditing: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Choices")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                Spacer()

                if isEditing, question.choices.count < 6 {
                    Button {
                        addChoice(to: question.id)
                    } label: {
                        Label("Add Choice", systemImage: "plus")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(Array(question.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                editableChoiceRow(question: question, choiceIndex: choiceIndex, choice: choice)
            }
        }
    }

    private func editableChoiceRow(question: Exam.Question, choiceIndex: Int, choice: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                setCorrectAnswer(for: question.id, choiceIndex: choiceIndex)
            } label: {
                Image(systemName: choiceIndex == question.correctChoiceIndex ? "checkmark.circle.fill" : "circle")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(choiceIndex == question.correctChoiceIndex ? DesignSystem.Colors.studyAccentBright : DesignSystem.Colors.tertiaryText)
            }
            .buttonStyle(.plain)
            .help("Mark as correct answer")

            TextField("Choice \(choiceIndex + 1)", text: choiceTextBinding(questionId: question.id, choiceIndex: choiceIndex))
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.hoverBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                )

            if question.choices.count > 2 {
                Button {
                    removeChoice(from: question.id, at: choiceIndex)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
                .buttonStyle(.plain)
                .help("Remove choice")
            }
        }
    }

    private func questionStatusText(_ question: Exam.Question) -> String {
        let hasPrompt = !question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let choiceCount = question.choices.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let hasCorrect = question.choices.indices.contains(question.correctChoiceIndex)
            && !question.choices[question.correctChoiceIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasPrompt && choiceCount >= 2 && hasCorrect ? "Ready" : "Draft"
    }

    private func questionStatusColor(_ question: Exam.Question) -> Color {
        questionStatusText(question) == "Ready" ? DesignSystem.Colors.studyAccentBright : DesignSystem.Colors.feedbackWarning
    }

    // MARK: - Bindings

    private func questionPromptBinding(for questionId: UUID) -> Binding<String> {
        Binding(
            get: {
                exam.questions.first { $0.id == questionId }?.prompt ?? ""
            },
            set: { newValue in
                guard let index = exam.questions.firstIndex(where: { $0.id == questionId }) else { return }
                exam.questions[index].prompt = newValue
                scheduleAutoSave()
            }
        )
    }

    private func choiceTextBinding(questionId: UUID, choiceIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard let question = exam.questions.first(where: { $0.id == questionId }),
                      choiceIndex < question.choices.count else {
                    return ""
                }
                return question.choices[choiceIndex]
            },
            set: { newValue in
                guard let questionIndex = exam.questions.firstIndex(where: { $0.id == questionId }),
                      choiceIndex < exam.questions[questionIndex].choices.count else {
                    return
                }
                exam.questions[questionIndex].choices[choiceIndex] = newValue
                scheduleAutoSave()
            }
        )
    }

    // MARK: - Actions

    private enum QuestionTemplate: String, CaseIterable, Identifiable {
        case blank
        case definition
        case comparison
        case scenario

        var id: String { rawValue }

        var title: String {
            switch self {
            case .blank: return "Blank Question"
            case .definition: return "Definition"
            case .comparison: return "Comparison"
            case .scenario: return "Scenario"
            }
        }

        var icon: String {
            switch self {
            case .blank: return "plus.circle"
            case .definition: return "text.book.closed"
            case .comparison: return "arrow.left.arrow.right"
            case .scenario: return "lightbulb"
            }
        }

        var question: Exam.Question {
            switch self {
            case .blank:
                return Exam.Question(prompt: "", choices: ["", "", "", ""], correctChoiceIndex: 0)
            case .definition:
                return Exam.Question(
                    prompt: "Which statement best defines this concept?",
                    choices: ["", "", "", ""],
                    correctChoiceIndex: 0
                )
            case .comparison:
                return Exam.Question(
                    prompt: "What is the key difference between A and B?",
                    choices: ["", "", "", ""],
                    correctChoiceIndex: 0
                )
            case .scenario:
                return Exam.Question(
                    prompt: "Given this scenario, what is the best next step?",
                    choices: ["", "", "", ""],
                    correctChoiceIndex: 0
                )
            }
        }
    }

    private func addQuestion(template: QuestionTemplate) {
        let newQuestion = template.question
        withAnimation(DesignSystem.Animation.quick) {
            exam.questions.append(newQuestion)
            editingQuestionId = newQuestion.id
        }
        focusedQuestionId = newQuestion.id
        scheduleAutoSave()
    }

    private func removeQuestion(at index: Int) {
        guard exam.questions.indices.contains(index) else { return }
        withAnimation(DesignSystem.Animation.quick) {
            let removedId = exam.questions[index].id
            exam.questions.remove(at: index)
            if editingQuestionId == removedId {
                editingQuestionId = nil
                focusedQuestionId = nil
            }
        }
        scheduleAutoSave()
    }

    private func moveQuestion(from source: Int, to destination: Int) {
        guard exam.questions.indices.contains(source),
              destination >= 0 && destination < exam.questions.count else {
            return
        }

        withAnimation(DesignSystem.Animation.quick) {
            let question = exam.questions.remove(at: source)
            exam.questions.insert(question, at: destination)
        }
        scheduleAutoSave()
    }

    private func addChoice(to questionId: UUID) {
        guard let index = exam.questions.firstIndex(where: { $0.id == questionId }), exam.questions[index].choices.count < 6 else {
            return
        }

        withAnimation(DesignSystem.Animation.quick) {
            exam.questions[index].choices.append("")
        }
        scheduleAutoSave()
    }

    private func removeChoice(from questionId: UUID, at choiceIndex: Int) {
        guard let questionIndex = exam.questions.firstIndex(where: { $0.id == questionId }),
              exam.questions[questionIndex].choices.count > 2,
              exam.questions[questionIndex].choices.indices.contains(choiceIndex) else {
            return
        }

        withAnimation(DesignSystem.Animation.quick) {
            exam.questions[questionIndex].choices.remove(at: choiceIndex)

            if exam.questions[questionIndex].correctChoiceIndex >= exam.questions[questionIndex].choices.count {
                exam.questions[questionIndex].correctChoiceIndex = max(0, exam.questions[questionIndex].choices.count - 1)
            } else if exam.questions[questionIndex].correctChoiceIndex > choiceIndex {
                exam.questions[questionIndex].correctChoiceIndex -= 1
            }
        }
        scheduleAutoSave()
    }

    private func setCorrectAnswer(for questionId: UUID, choiceIndex: Int) {
        guard let index = exam.questions.firstIndex(where: { $0.id == questionId }),
              exam.questions[index].choices.indices.contains(choiceIndex) else {
            return
        }
        exam.questions[index].correctChoiceIndex = choiceIndex
        scheduleAutoSave()
    }

    // MARK: - Auto-Save

    private func scheduleAutoSave() {
        hasPendingChanges = true
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await performSave()
        }
    }

    @MainActor
    private func performSave() async {
        guard hasPendingChanges else { return }

        isSaving = true
        defer { isSaving = false }

        var updatedExam = exam
        updatedExam.updatedAt = Date()

        do {
            try await storage.upsert(exam: updatedExam.toDTO())
            exam = updatedExam
            hasPendingChanges = false
            lastSavedAt = Date()
        } catch {
            saveError = "Failed to save exam: \(error.localizedDescription)"
        }
    }
}

#if DEBUG
struct ExamEditorView_Previews: PreviewProvider {
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
                )
            ]
        )

        var body: some View {
            ExamEditorView(exam: $exam)
                .workspaceCanvasSurface()
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .frame(width: 920, height: 800)
    }
}
#endif
