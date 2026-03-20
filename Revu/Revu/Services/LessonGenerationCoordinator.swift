@preconcurrency import Foundation

struct LessonGenerationCoordinator {
    private let storage: Storage
    private let deckService: DeckService
    private let cardService: CardService

    init(storage: Storage) {
        self.storage = storage
        self.deckService = DeckService(storage: storage)
        self.cardService = CardService(storage: storage)
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    func generateLessonArtifacts(
        lesson: Lesson,
        course: Course?,
        materials: [CourseMaterial],
        kinds: [LessonArtifactKind]
    ) async {
        guard !materials.isEmpty else { return }

        var lessonInProgress = lesson
        lessonInProgress.status = .processing
        lessonInProgress.updatedAt = Date()
        try? await storage.upsert(lesson: lessonInProgress.toDTO())

        var failed = false
        for kind in kinds {
            let jobId = UUID()
            let startedAt = Date()
            try? await storage.upsert(
                lessonGenerationJob: LessonGenerationJobDTO(
                    id: jobId,
                    lessonId: lesson.id,
                    kind: kind,
                    status: .inProgress,
                    itemCount: 0,
                    errorMessage: nil,
                    startedAt: startedAt,
                    updatedAt: startedAt
                )
            )

            do {
                let itemCount = try await generateSingleArtifact(
                    kind: kind,
                    lesson: lesson,
                    course: course,
                    materials: materials
                )
                try? await storage.upsert(
                    lessonGenerationJob: LessonGenerationJobDTO(
                        id: jobId,
                        lessonId: lesson.id,
                        kind: kind,
                        status: .ready,
                        itemCount: itemCount,
                        errorMessage: nil,
                        startedAt: startedAt,
                        updatedAt: Date()
                    )
                )
            } catch {
                failed = true
                try? await storage.upsert(
                    lessonGenerationJob: LessonGenerationJobDTO(
                        id: jobId,
                        lessonId: lesson.id,
                        kind: kind,
                        status: .failed,
                        itemCount: 0,
                        errorMessage: error.localizedDescription,
                        startedAt: startedAt,
                        updatedAt: Date()
                    )
                )
            }
        }

        var completedLesson = lesson
        completedLesson.status = failed ? .failed : .ready
        completedLesson.updatedAt = Date()
        try? await storage.upsert(lesson: completedLesson.toDTO())
    }

    func generateCourseMixedQuiz(
        course: Course,
        lessons: [Lesson],
        materials: [CourseMaterial]
    ) async {
        let textByLesson = Dictionary(grouping: materials.filter { $0.courseId == course.id }, by: { $0.lessonId })
        let points = lessons.flatMap { lesson in
            (textByLesson[lesson.id] ?? [])
                .flatMap { extractStudyPoints(from: $0.extractedText ?? "", maxPoints: 6) }
                .prefix(6)
                .map { (lesson.title, $0) }
        }

        guard !points.isEmpty else { return }

        let allExams = (try? await storage.allExams()) ?? []
        let existingMixed = allExams
            .filter { $0.courseId == course.id && $0.originLessonId == nil && $0.title.lowercased().contains("mixed quiz") }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        let questions = buildQuizQuestions(from: points.map { $0.1 }, maxCount: 15)
        let exam = ExamDTO(
            id: existingMixed?.id ?? UUID(),
            parentFolderId: existingMixed?.parentFolderId,
            courseId: course.id,
            originLessonId: nil,
            title: "\(course.name) Mixed Quiz",
            config: ExamDTO.ConfigDTO(shuffleQuestions: true),
            questions: questions,
            createdAt: existingMixed?.createdAt ?? Date(),
            updatedAt: Date()
        )
        try? await storage.upsert(exam: exam)
    }

    // MARK: - Private

    private func generateSingleArtifact(
        kind: LessonArtifactKind,
        lesson: Lesson,
        course: Course?,
        materials: [CourseMaterial]
    ) async throws -> Int {
        switch kind {
        case .notes:
            return try await generateNotes(lesson: lesson, course: course, materials: materials)
        case .quiz:
            return try await generateQuiz(lesson: lesson, materials: materials)
        case .flashcards:
            return try await generateFlashcards(lesson: lesson, materials: materials)
        }
    }

    private func generateNotes(lesson: Lesson, course: Course?, materials: [CourseMaterial]) async throws -> Int {
        let combined = materials.compactMap(\.extractedText).joined(separator: "\n\n")
        guard !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CourseServiceError.noLessonMaterials
        }

        let bulletPoints = extractStudyPoints(from: combined, maxPoints: 10)
        var markdown: [String] = []
        markdown.append("# \(lesson.title) — Notes")
        if let courseName = course?.name {
            markdown.append("_Course: \(courseName)_")
        }
        markdown.append("## Key Takeaways")
        for point in bulletPoints {
            markdown.append("- \(point)")
        }
        if !combined.isEmpty {
            markdown.append("## Source Excerpt")
            markdown.append(String(combined.prefix(2500)))
        }

        let existingGuides = ((try? await storage.allStudyGuides()) ?? [])
            .filter { $0.courseId == lesson.courseId && $0.originLessonId == lesson.id }
            .sorted { $0.updatedAt > $1.updatedAt }
        let existing = existingGuides.first
        let guide = StudyGuideDTO(
            id: existing?.id ?? UUID(),
            parentFolderId: existing?.parentFolderId,
            courseId: lesson.courseId,
            originLessonId: lesson.id,
            title: "\(lesson.title) Notes",
            markdownContent: markdown.joined(separator: "\n\n"),
            attachments: existing?.attachments ?? [],
            tags: ["lesson-notes", lesson.title],
            createdAt: existing?.createdAt ?? Date(),
            lastEditedAt: Date()
        )
        try await storage.upsert(studyGuide: guide)
        return 1
    }

    private func generateQuiz(lesson: Lesson, materials: [CourseMaterial]) async throws -> Int {
        let combined = materials.compactMap(\.extractedText).joined(separator: "\n\n")
        guard !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CourseServiceError.noLessonMaterials
        }

        let points = extractStudyPoints(from: combined, maxPoints: 20)
        let questions = buildQuizQuestions(from: points, maxCount: 10)
        guard !questions.isEmpty else {
            throw CourseServiceError.noLessonMaterials
        }

        let existingExams = ((try? await storage.allExams()) ?? [])
            .filter { $0.courseId == lesson.courseId && $0.originLessonId == lesson.id }
            .sorted { $0.updatedAt > $1.updatedAt }
        let existing = existingExams.first
        let exam = ExamDTO(
            id: existing?.id ?? UUID(),
            parentFolderId: existing?.parentFolderId,
            courseId: lesson.courseId,
            originLessonId: lesson.id,
            title: "\(lesson.title) Quiz",
            config: ExamDTO.ConfigDTO(shuffleQuestions: true),
            questions: questions,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
        try await storage.upsert(exam: exam)
        return questions.count
    }

    private func generateFlashcards(lesson: Lesson, materials: [CourseMaterial]) async throws -> Int {
        let combined = materials.compactMap(\.extractedText).joined(separator: "\n\n")
        guard !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CourseServiceError.noLessonMaterials
        }

        let points = extractStudyPoints(from: combined, maxPoints: 28)
        guard !points.isEmpty else {
            throw CourseServiceError.noLessonMaterials
        }

        let existingDecks = ((try? await storage.allDecks()) ?? [])
            .filter { $0.courseId == lesson.courseId && $0.originLessonId == lesson.id && $0.kind == .deck }
            .sorted { $0.updatedAt > $1.updatedAt }
        let existing = existingDecks.first

        let deck = Deck(
            id: existing?.id ?? UUID(),
            parentId: existing?.parentId,
            courseId: lesson.courseId,
            originLessonId: lesson.id,
            kind: .deck,
            name: "\(lesson.title) Flashcards",
            note: "Auto-generated from lesson uploads.",
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date(),
            isArchived: false
        )
        await deckService.upsert(deck: deck)

        // Replace existing deck cards when regenerating.
        let oldCards = (try? await storage.cards(deckId: deck.id)) ?? []
        for card in oldCards {
            try? await storage.deleteCard(id: card.id)
        }

        var generatedCount = 0
        for (index, point) in points.enumerated() {
            let front = "Explain key point \(index + 1) from \(lesson.title)."
            let back = point
            let card = Card(
                deckId: deck.id,
                kind: .basic,
                front: front,
                back: back,
                tags: [lesson.title, "lesson"]
            )
            await cardService.upsert(card: card)
            generatedCount += 1
        }

        return generatedCount
    }

    private func extractStudyPoints(from text: String, maxPoints: Int) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
        let rawSentences = normalized
            .split(whereSeparator: { $0 == "." || $0 == "!" || $0 == "?" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 40 && $0.count <= 260 }

        var unique: [String] = []
        var seen: Set<String> = []
        for sentence in rawSentences {
            let key = sentence.lowercased()
            if seen.insert(key).inserted {
                unique.append(sentence)
            }
            if unique.count >= maxPoints { break }
        }
        return unique
    }

    private func buildQuizQuestions(from points: [String], maxCount: Int) -> [ExamDTO.QuestionDTO] {
        guard !points.isEmpty else { return [] }
        let candidates = Array(points.prefix(maxCount))
        guard !candidates.isEmpty else { return [] }

        var questions: [ExamDTO.QuestionDTO] = []
        for (index, point) in candidates.enumerated() {
            let correctChoice = String(point.prefix(90))
            let distractors = candidates
                .enumerated()
                .filter { $0.offset != index }
                .map { String($0.element.prefix(90)) }
                .prefix(3)
            var choices = [correctChoice]
            choices.append(contentsOf: distractors)
            while choices.count < 4 {
                choices.append("None of the above")
            }
            let shuffled = choices.shuffled()
            let correctIndex = shuffled.firstIndex(of: correctChoice) ?? 0
            questions.append(
                ExamDTO.QuestionDTO(
                    prompt: "Which option best reflects this lesson concept?",
                    choices: shuffled,
                    correctChoiceIndex: correctIndex
                )
            )
        }
        return questions
    }
}
