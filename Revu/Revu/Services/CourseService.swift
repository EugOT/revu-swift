@preconcurrency import Foundation

/// Result of computing coverage for a single topic within a course.
struct TopicCoverage: Identifiable, Equatable, Sendable {
    let topicId: UUID
    let topicName: String
    let linkedCardCount: Int
    let masteredCardCount: Int
    let conceptMastery: Double?

    var id: UUID { topicId }

    /// Combined mastery metric: card-level review progress blended with concept mastery.
    var mastery: Double {
        if linkedCardCount == 0 {
            return conceptMastery ?? 0
        }
        let cardMastery = Double(masteredCardCount) / Double(linkedCardCount)
        if let concept = conceptMastery {
            return (cardMastery + concept) / 2
        }
        return cardMastery
    }
}

/// Aggregated progress for an entire course.
struct CourseProgress: Equatable, Sendable {
    let courseId: UUID
    let topicCoverage: [TopicCoverage]
    let daysUntilExam: Int?
    let totalCards: Int
    let masteredCards: Int
    let dueCards: Int

    var overallMastery: Double {
        guard !topicCoverage.isEmpty else { return 0 }
        let total = topicCoverage.reduce(0.0) { $0 + $1.mastery }
        return total / Double(topicCoverage.count)
    }

    enum Pace: String, Sendable {
        case onTrack
        case atRisk
        case critical
        case noExam
    }

    var pace: Pace {
        guard let days = daysUntilExam else { return .noExam }
        if days <= 0 { return overallMastery >= 0.8 ? .onTrack : .critical }
        if overallMastery >= 0.7 { return .onTrack }
        if overallMastery >= 0.4 || days > 14 { return .atRisk }
        return .critical
    }
}

enum CourseServiceError: LocalizedError {
    case unsupportedMaterialType(String)
    case lessonNotFound
    case courseNotFound
    case noLessonMaterials

    var errorDescription: String? {
        switch self {
        case .unsupportedMaterialType(let ext):
            return "Only PDF uploads are supported right now. Received: \(ext)."
        case .lessonNotFound:
            return "Lesson not found."
        case .courseNotFound:
            return "Course not found."
        case .noLessonMaterials:
            return "No materials are assigned to this lesson yet."
        }
    }
}

struct CourseService {
    private let storage: Storage
    private let ingestionService: ContentIngestionService
    private let generationCoordinator: LessonGenerationCoordinator

    init(
        storage: Storage,
        ingestionService: ContentIngestionService = ContentIngestionService(),
        generationCoordinator: LessonGenerationCoordinator? = nil
    ) {
        self.storage = storage
        self.ingestionService = ingestionService
        self.generationCoordinator = generationCoordinator ?? LessonGenerationCoordinator(storage: storage)
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    // MARK: - Course CRUD

    func allCourses() async -> [Course] {
        (try? await storage.allCourses().map { $0.toDomain() }) ?? []
    }

    func course(withId id: UUID) async -> Course? {
        guard let dto = try? await storage.course(withId: id) else { return nil }
        return dto.toDomain()
    }

    func upsert(course: Course) async {
        var updated = course
        updated.updatedAt = Date()
        try? await storage.upsert(course: updated.toDTO())
    }

    func deleteCourse(id: UUID) async {
        let topics = (try? await storage.topics(courseId: id)) ?? []
        for topic in topics {
            try? await storage.deleteTopic(id: topic.id)
        }

        let lessons = (try? await storage.lessons(courseId: id)) ?? []
        for lesson in lessons {
            try? await storage.deleteLessonGenerationJobs(lessonId: lesson.id)
            try? await storage.deleteLesson(id: lesson.id)
        }

        let materials = (try? await storage.materials(courseId: id)) ?? []
        for material in materials {
            try? await storage.deleteMaterial(id: material.id)
        }

        await unlinkEntities(fromCourseId: id)
        try? await storage.deleteCourse(id: id)
    }

    // MARK: - Topic CRUD (Legacy compatibility)

    func topics(courseId: UUID) async -> [CourseTopic] {
        let dtos = (try? await storage.topics(courseId: courseId)) ?? []
        return dtos.map { $0.toDomain() }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func upsert(topic: CourseTopic) async {
        try? await storage.upsert(topic: topic.toDTO())
    }

    func deleteTopic(id: UUID) async {
        try? await storage.deleteTopic(id: id)
    }

    // MARK: - Lesson CRUD

    func lessons(courseId: UUID) async -> [Lesson] {
        let dtos = (try? await storage.lessons(courseId: courseId)) ?? []
        return dtos.map { $0.toDomain() }.sorted { $0.createdAt < $1.createdAt }
    }

    func lesson(withId id: UUID) async -> Lesson? {
        guard let dto = try? await storage.lesson(withId: id) else { return nil }
        return dto.toDomain()
    }

    func upsert(lesson: Lesson) async {
        var updated = lesson
        updated.updatedAt = Date()
        try? await storage.upsert(lesson: updated.toDTO())
    }

    @discardableResult
    func createLesson(fromMaterialIds materialIds: [UUID], title: String?) async -> Lesson? {
        let uniqueIds = Array(Set(materialIds))
        guard !uniqueIds.isEmpty else { return nil }

        var materialDTOs: [CourseMaterialDTO] = []
        materialDTOs.reserveCapacity(uniqueIds.count)
        for id in uniqueIds {
            if let material = try? await storage.material(withId: id) {
                materialDTOs.append(material)
            }
        }
        guard let firstMaterial = materialDTOs.first else { return nil }

        let lessonTitle: String = {
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return title.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if materialDTOs.count == 1 {
                return Self.lessonTitle(fromFilename: firstMaterial.filename)
            }
            return "Grouped Lesson"
        }()

        let lesson = Lesson(
            courseId: firstMaterial.courseId,
            title: lessonTitle,
            summary: materialDTOs.count > 1 ? "Grouped from \(materialDTOs.count) uploads." : nil,
            sourceType: materialDTOs.count > 1 ? .groupedUpload : .upload,
            status: .ready
        )

        try? await storage.upsert(lesson: lesson.toDTO())

        for var material in materialDTOs where material.courseId == lesson.courseId {
            material.lessonId = lesson.id
            material.processingStatus = .ready
            material.processedAt = material.processedAt ?? Date()
            try? await storage.upsert(material: material)
        }

        return lesson
    }

    func assignMaterial(materialId: UUID, toLessonId lessonId: UUID?) async {
        guard var material = try? await storage.material(withId: materialId) else { return }
        material.lessonId = lessonId
        try? await storage.upsert(material: material)
    }

    // MARK: - Material CRUD

    func materials(courseId: UUID) async -> [CourseMaterial] {
        let dtos = (try? await storage.materials(courseId: courseId)) ?? []
        return dtos.map { $0.toDomain() }.sorted { $0.importedAt < $1.importedAt }
    }

    func upsert(material: CourseMaterial) async {
        try? await storage.upsert(material: material.toDTO())
    }

    func deleteMaterial(id: UUID) async {
        try? await storage.deleteMaterial(id: id)
    }

    // MARK: - Material Ingestion

    /// Ingests a PDF, extracts text/chunks, stores material, and auto-creates a lesson.
    func ingestMaterial(url: URL, courseId: UUID, topicId: UUID? = nil) async throws -> CourseMaterial {
        let ext = url.pathExtension.lowercased()
        guard ext == "pdf" else {
            throw CourseServiceError.unsupportedMaterialType(ext.isEmpty ? "unknown" : ext)
        }

        let now = Date()
        let extractedText = try await ingestionService.ingest(url: url)
        let wordCount = extractedText.split { $0.isWhitespace || $0.isNewline }.count

        let lesson = Lesson(
            courseId: courseId,
            title: Self.lessonTitle(fromFilename: url.lastPathComponent),
            summary: "Auto-created from uploaded PDF.",
            createdAt: now,
            updatedAt: now,
            sourceType: .upload,
            status: .ready
        )
        try? await storage.upsert(lesson: lesson.toDTO())

        let material = CourseMaterial(
            courseId: courseId,
            topicId: topicId,
            lessonId: lesson.id,
            filename: url.lastPathComponent,
            fileType: ext,
            extractedText: extractedText,
            wordCount: wordCount,
            processingStatus: .ready,
            processingError: nil,
            processedAt: now,
            importedAt: now
        )
        try? await storage.upsert(material: material.toDTO())

        let chunks = makeChunks(from: material)
        for chunk in chunks {
            try? await storage.upsert(chunk: chunk)
        }
        return material
    }

    // MARK: - Generation APIs

    func generateLessonArtifacts(lessonId: UUID, kinds: [LessonArtifactKind]) async {
        guard let lessonDTO = try? await storage.lesson(withId: lessonId) else { return }
        let lesson = lessonDTO.toDomain()
        let course = await course(withId: lesson.courseId)
        let materials = ((try? await storage.materials(courseId: lesson.courseId)) ?? [])
            .map { $0.toDomain() }
            .filter { $0.lessonId == lessonId }

        guard !materials.isEmpty else { return }
        await generationCoordinator.generateLessonArtifacts(
            lesson: lesson,
            course: course,
            materials: materials,
            kinds: kinds
        )
    }

    func generateCourseMixedQuiz(courseId: UUID) async {
        guard let course = await course(withId: courseId) else { return }
        let lessons = await lessons(courseId: courseId)
        let materials = await materials(courseId: courseId)
        await generationCoordinator.generateCourseMixedQuiz(
            course: course,
            lessons: lessons,
            materials: materials
        )
    }

    // MARK: - Linking

    func linkDeck(_ deckId: UUID, toCourse courseId: UUID) async {
        guard var dto = try? await storage.deck(withId: deckId) else { return }
        dto.courseId = courseId
        try? await storage.upsert(deck: dto)
    }

    func unlinkDeck(_ deckId: UUID) async {
        guard var dto = try? await storage.deck(withId: deckId) else { return }
        dto.courseId = nil
        dto.originLessonId = nil
        try? await storage.upsert(deck: dto)
    }

    func linkExam(_ examId: UUID, toCourse courseId: UUID) async {
        guard var dto = try? await storage.exam(withId: examId) else { return }
        dto.courseId = courseId
        try? await storage.upsert(exam: dto)
    }

    func unlinkExam(_ examId: UUID) async {
        guard var dto = try? await storage.exam(withId: examId) else { return }
        dto.courseId = nil
        dto.originLessonId = nil
        try? await storage.upsert(exam: dto)
    }

    func linkStudyGuide(_ guideId: UUID, toCourse courseId: UUID) async {
        guard var dto = try? await storage.studyGuide(withId: guideId) else { return }
        dto.courseId = courseId
        try? await storage.upsert(studyGuide: dto)
    }

    func unlinkStudyGuide(_ guideId: UUID) async {
        guard var dto = try? await storage.studyGuide(withId: guideId) else { return }
        dto.courseId = nil
        dto.originLessonId = nil
        try? await storage.upsert(studyGuide: dto)
    }

    // MARK: - Linked Items

    func decks(courseId: UUID) async -> [Deck] {
        let allDecks = (try? await storage.allDecks()) ?? []
        return allDecks.filter { $0.courseId == courseId }.map { $0.toDomain() }
    }

    func exams(courseId: UUID) async -> [Exam] {
        let allExams = (try? await storage.allExams()) ?? []
        return allExams.filter { $0.courseId == courseId }.map { $0.toDomain() }
    }

    func studyGuides(courseId: UUID) async -> [StudyGuide] {
        let allGuides = (try? await storage.allStudyGuides()) ?? []
        return allGuides.filter { $0.courseId == courseId }.map { $0.toDomain() }
    }

    // MARK: - Available (Unlinked) Items

    func availableDecks() async -> [Deck] {
        let allDecks = (try? await storage.allDecks()) ?? []
        return allDecks.filter { $0.courseId == nil && $0.kind != .folder }.map { $0.toDomain() }
    }

    func availableExams() async -> [Exam] {
        let allExams = (try? await storage.allExams()) ?? []
        return allExams.filter { $0.courseId == nil }.map { $0.toDomain() }
    }

    func availableStudyGuides() async -> [StudyGuide] {
        let allGuides = (try? await storage.allStudyGuides()) ?? []
        return allGuides.filter { $0.courseId == nil }.map { $0.toDomain() }
    }

    func courseColorMap() async -> [UUID: String] {
        let courses = await allCourses()
        var map: [UUID: String] = [:]
        for course in courses {
            if let hex = course.colorHex {
                map[course.id] = hex
            }
        }
        return map
    }

    // MARK: - Dashboard

    func courseDashboard(courseId: UUID) async -> CourseDashboardSnapshot {
        let lessonList = await lessons(courseId: courseId)
        let materials = await self.materials(courseId: courseId)
        let deckDTOs = ((try? await storage.allDecks()) ?? []).filter { $0.courseId == courseId && $0.kind == .deck }
        let examDTOs = ((try? await storage.allExams()) ?? []).filter { $0.courseId == courseId }
        let guideDTOs = ((try? await storage.allStudyGuides()) ?? []).filter { $0.courseId == courseId }

        var jobsByLesson: [UUID: [LessonGenerationJobDTO]] = [:]
        for lesson in lessonList {
            jobsByLesson[lesson.id] = (try? await storage.lessonGenerationJobs(lessonId: lesson.id)) ?? []
        }

        let now = Date()
        var dueCardsByDeck: [UUID: Int] = [:]
        var cardsByDeck: [UUID: [Card]] = [:]
        for deck in deckDTOs {
            let cards = ((try? await storage.cards(deckId: deck.id)) ?? []).map { $0.toDomain() }
            cardsByDeck[deck.id] = cards
            dueCardsByDeck[deck.id] = cards.filter { !$0.isSuspended && $0.srs.dueDate <= now }.count
        }

        let lessonSummaries: [LessonDashboardSummary] = lessonList.map { lesson in
            let lessonMaterials = materials.filter { $0.lessonId == lesson.id }
            let lessonDecks = deckDTOs.filter { $0.originLessonId == lesson.id }
            let lessonQuizzes = examDTOs.filter { $0.originLessonId == lesson.id }
            let lessonNotes = guideDTOs.filter { $0.originLessonId == lesson.id }
            let jobs = jobsByLesson[lesson.id] ?? []

            let noteSummary = buildArtifactSummary(
                kind: .notes,
                count: lessonNotes.count,
                latestArtifactAt: lessonNotes.map(\.updatedAt).max(),
                jobs: jobs
            )
            let quizSummary = buildArtifactSummary(
                kind: .quiz,
                count: lessonQuizzes.count,
                latestArtifactAt: lessonQuizzes.map(\.updatedAt).max(),
                jobs: jobs
            )
            let flashcardSummary = buildArtifactSummary(
                kind: .flashcards,
                count: lessonDecks.count,
                latestArtifactAt: lessonDecks.map(\.updatedAt).max(),
                jobs: jobs
            )
            let artifactSummaries = [noteSummary, quizSummary, flashcardSummary]
            let readyCount = artifactSummaries.filter { $0.status == .ready }.count
            let readiness = Double(readyCount) / 3.0
            let dueCards = lessonDecks.reduce(0) { $0 + (dueCardsByDeck[$1.id] ?? 0) }
            let words = lessonMaterials.reduce(0) { $0 + ($1.wordCount ?? 0) }

            return LessonDashboardSummary(
                lesson: lesson,
                materialCount: lessonMaterials.count,
                wordCount: words,
                artifactSummaries: artifactSummaries,
                notesIds: lessonNotes.map(\.id),
                quizIds: lessonQuizzes.map(\.id),
                flashcardDeckIds: lessonDecks.map(\.id),
                readiness: readiness,
                dueCards: dueCards
            )
        }

        let mixedQuizExam = examDTOs
            .filter { $0.originLessonId == nil && $0.title.lowercased().contains("mixed quiz") }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        let mixedQuestionCount: Int = {
            guard let mixedQuizExam else { return 0 }
            return mixedQuizExam.questions.count
        }()
        let mixedQuizSummary = MixedQuizSummary(
            examId: mixedQuizExam?.id,
            status: mixedQuizExam == nil ? .notStarted : .ready,
            questionCount: mixedQuestionCount,
            updatedAt: mixedQuizExam?.updatedAt
        )

        let reviewLogs = (try? await storage.recentLogs(limit: 10_000)) ?? []
        var logsByCardId: [UUID: [ReviewLogDTO]] = [:]
        for log in reviewLogs {
            logsByCardId[log.cardId, default: []].append(log)
        }

        let weakLessons = buildWeakLessons(
            lessonSummaries: lessonSummaries,
            cardsByDeck: cardsByDeck,
            logsByCardId: logsByCardId
        )

        let timelineItems = buildTimelineItems(
            lessonSummaries: lessonSummaries,
            mixedQuiz: mixedQuizSummary,
            weakLessons: weakLessons
        )

        let readiness = lessonSummaries.isEmpty ? 0 : lessonSummaries.reduce(0) { $0 + $1.readiness } / Double(lessonSummaries.count)
        let courseProgress = await courseProgress(courseId: courseId)
        let kpis = CourseDashboardKPI(
            readiness: readiness,
            dueItems: timelineItems.count,
            pace: mapPace(courseProgress.pace),
            weakLessonCount: weakLessons.count,
            lessonCount: lessonSummaries.count
        )

        return CourseDashboardSnapshot(
            courseId: courseId,
            lessonSummaries: lessonSummaries,
            mixedQuiz: mixedQuizSummary,
            weakLessons: weakLessons,
            timelineItems: timelineItems,
            topKpis: kpis
        )
    }

    // MARK: - Coverage & Progress (legacy)

    func courseCoverage(courseId: UUID) async -> [TopicCoverage] {
        let topics = await self.topics(courseId: courseId)
        let linkedDecks = await self.decks(courseId: courseId)
        let deckIds = Set(linkedDecks.map(\.id))

        var allCards: [Card] = []
        for deckId in deckIds {
            let deckCards = (try? await storage.cards(deckId: deckId)) ?? []
            allCards.append(contentsOf: deckCards.map { $0.toDomain() })
        }

        let conceptStates = (try? await storage.allConceptStates()) ?? []
        let conceptsByKey = Dictionary(uniqueKeysWithValues: conceptStates.map { ($0.key, $0) })

        return topics.map { topic in
            let topicCards = allCards
            let cardCount = topics.isEmpty ? 0 : topicCards.count / max(topics.count, 1)

            let masteredCount = topicCards.filter { card in
                card.srs.fsrsReps >= 2 && card.srs.stability >= 5.0
            }.count / max(topics.count, 1)

            let normalizedName = topic.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let conceptMastery = conceptsByKey[normalizedName]?.pKnown

            return TopicCoverage(
                topicId: topic.id,
                topicName: topic.name,
                linkedCardCount: cardCount,
                masteredCardCount: masteredCount,
                conceptMastery: conceptMastery
            )
        }
    }

    func courseProgress(courseId: UUID) async -> CourseProgress {
        let course = await self.course(withId: courseId)
        let topicCoverage = await self.courseCoverage(courseId: courseId)

        let linkedDecks = await self.decks(courseId: courseId)
        let deckIds = Set(linkedDecks.map(\.id))

        var allCards: [Card] = []
        for deckId in deckIds {
            let deckCards = (try? await storage.cards(deckId: deckId)) ?? []
            allCards.append(contentsOf: deckCards.map { $0.toDomain() })
        }

        let now = Date()
        let masteredCards = allCards.filter { $0.srs.fsrsReps >= 2 && $0.srs.stability >= 5.0 }
        let dueCards = allCards.filter { !$0.isSuspended && $0.srs.dueDate <= now }

        let daysUntilExam: Int? = {
            guard let examDate = course?.examDate else { return nil }
            let calendar = Calendar.current
            return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: examDate)).day
        }()

        return CourseProgress(
            courseId: courseId,
            topicCoverage: topicCoverage,
            daysUntilExam: daysUntilExam,
            totalCards: allCards.count,
            masteredCards: masteredCards.count,
            dueCards: dueCards.count
        )
    }

    // MARK: - Private

    private func unlinkEntities(fromCourseId courseId: UUID) async {
        let allDecks = (try? await storage.allDecks()) ?? []
        for var dto in allDecks where dto.courseId == courseId {
            dto.courseId = nil
            dto.originLessonId = nil
            try? await storage.upsert(deck: dto)
        }

        let allExams = (try? await storage.allExams()) ?? []
        for var dto in allExams where dto.courseId == courseId {
            dto.courseId = nil
            dto.originLessonId = nil
            try? await storage.upsert(exam: dto)
        }

        let allGuides = (try? await storage.allStudyGuides()) ?? []
        for var dto in allGuides where dto.courseId == courseId {
            dto.courseId = nil
            dto.originLessonId = nil
            try? await storage.upsert(studyGuide: dto)
        }
    }

    private static func lessonTitle(fromFilename filename: String) -> String {
        let base = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let clean = base.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Lesson" : clean
    }

    private func makeChunks(from material: CourseMaterial) -> [ContentChunk] {
        guard let text = material.extractedText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let maxWords = 180
        var chunks: [ContentChunk] = []
        var buffer: [String] = []
        var bufferWordCount = 0

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            let content = buffer.joined(separator: "\n\n")
            let wordCount = content.split { $0.isWhitespace || $0.isNewline }.count
            chunks.append(
                ContentChunk(
                    id: UUID(),
                    materialId: material.id,
                    courseId: material.courseId,
                    sourceFilename: material.filename,
                    sourcePage: nil,
                    sectionHeading: nil,
                    content: content,
                    wordCount: wordCount,
                    conceptKeys: [],
                    createdAt: Date()
                )
            )
            buffer.removeAll(keepingCapacity: true)
            bufferWordCount = 0
        }

        for paragraph in paragraphs {
            let words = paragraph.split { $0.isWhitespace || $0.isNewline }.count
            if bufferWordCount + words > maxWords, !buffer.isEmpty {
                flushBuffer()
            }
            buffer.append(paragraph)
            bufferWordCount += words
        }
        flushBuffer()
        return chunks
    }

    private func buildArtifactSummary(
        kind: LessonArtifactKind,
        count: Int,
        latestArtifactAt: Date?,
        jobs: [LessonGenerationJobDTO]
    ) -> LessonArtifactSummary {
        let latestJob = jobs
            .filter { $0.kind == kind }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        let status: ArtifactStatus
        let error: String?
        if count > 0 {
            status = .ready
            error = nil
        } else if latestJob?.status == .inProgress {
            status = .inProgress
            error = nil
        } else if latestJob?.status == .failed {
            status = .failed
            error = latestJob?.errorMessage
        } else {
            status = .notStarted
            error = nil
        }

        let updatedAt = max(latestArtifactAt ?? .distantPast, latestJob?.updatedAt ?? .distantPast)
        let safeUpdatedAt = updatedAt == .distantPast ? nil : updatedAt
        return LessonArtifactSummary(
            kind: kind,
            status: status,
            count: count,
            error: error,
            updatedAt: safeUpdatedAt
        )
    }

    private func buildWeakLessons(
        lessonSummaries: [LessonDashboardSummary],
        cardsByDeck: [UUID: [Card]],
        logsByCardId: [UUID: [ReviewLogDTO]]
    ) -> [WeakLessonInsight] {
        let scored: [WeakLessonInsight] = lessonSummaries.compactMap { summary in
            let cards = summary.flashcardDeckIds.flatMap { cardsByDeck[$0] ?? [] }
            guard !cards.isEmpty else { return nil }

            var attempts = 0
            var misses = 0
            var totalElapsedMs = 0
            for card in cards {
                let logs = logsByCardId[card.id] ?? []
                attempts += logs.count
                misses += logs.filter { $0.grade <= 1 }.count
                totalElapsedMs += logs.reduce(0) { $0 + $1.elapsedMs }
            }

            let missRate = attempts == 0 ? 0.5 : Double(misses) / Double(attempts)
            let avgElapsed = attempts == 0 ? 0 : Double(totalElapsedMs) / Double(attempts)
            let slowPenalty = min(max((avgElapsed - 6_000) / 12_000, 0), 0.25)
            let confidence = max(0.05, min(0.99, 1.0 - (missRate * 0.8) - slowPenalty))

            let recommendation: String
            if missRate > 0.5 {
                recommendation = "Regenerate quiz and run a focused review set."
            } else if summary.dueCards > 0 {
                recommendation = "Clear due cards before generating fresh artifacts."
            } else {
                recommendation = "Run a quick mixed review to stabilize recall."
            }

            return WeakLessonInsight(
                lessonId: summary.lesson.id,
                lessonTitle: summary.lesson.title,
                confidence: confidence,
                missRate: missRate,
                dueCards: summary.dueCards,
                recommendation: recommendation
            )
        }

        return scored
            .sorted {
                if $0.confidence == $1.confidence {
                    return $0.dueCards > $1.dueCards
                }
                return $0.confidence < $1.confidence
            }
            .prefix(5)
            .map { $0 }
    }

    private func buildTimelineItems(
        lessonSummaries: [LessonDashboardSummary],
        mixedQuiz: MixedQuizSummary,
        weakLessons: [WeakLessonInsight]
    ) -> [CourseTimelineItem] {
        var items: [CourseTimelineItem] = []

        for lesson in lessonSummaries {
            for artifact in lesson.artifactSummaries where artifact.status != .ready {
                let subtitle = artifact.status == .failed
                    ? (artifact.error ?? "Previous generation failed.")
                    : "Missing \(artifact.kind.rawValue)."
                items.append(
                    CourseTimelineItem(
                        title: "Generate \(artifact.kind.rawValue.capitalized) for \(lesson.lesson.title)",
                        subtitle: subtitle,
                        urgency: artifact.status == .failed ? 3 : 2,
                        cta: CourseTimelineCTA(
                            title: "Generate",
                            actionType: .generateLessonArtifact,
                            lessonId: lesson.lesson.id,
                            artifactKind: artifact.kind,
                            examId: nil,
                            deckId: nil,
                            studyGuideId: nil
                        )
                    )
                )
            }
        }

        for weak in weakLessons.prefix(3) {
            items.append(
                CourseTimelineItem(
                    title: "Reinforce weak lesson: \(weak.lessonTitle)",
                    subtitle: "Confidence \(Int(weak.confidence * 100))% • \(weak.recommendation)",
                    urgency: 3,
                    cta: CourseTimelineCTA(
                        title: "Review",
                        actionType: .reviewWeakLesson,
                        lessonId: weak.lessonId,
                        artifactKind: .flashcards,
                        examId: nil,
                        deckId: nil,
                        studyGuideId: nil
                    )
                )
            )
        }

        if mixedQuiz.status == .ready, let examId = mixedQuiz.examId {
            items.append(
                CourseTimelineItem(
                    title: "Run mixed quiz",
                    subtitle: "\(mixedQuiz.questionCount) questions across lessons.",
                    urgency: 1,
                    cta: CourseTimelineCTA(
                        title: "Open Mixed Quiz",
                        actionType: .openMixedQuiz,
                        lessonId: nil,
                        artifactKind: nil,
                        examId: examId,
                        deckId: nil,
                        studyGuideId: nil
                    )
                )
            )
        } else {
            items.append(
                CourseTimelineItem(
                    title: "Refresh mixed quiz",
                    subtitle: "Generate one cross-lesson quiz for exam readiness.",
                    urgency: 2,
                    cta: CourseTimelineCTA(
                        title: "Generate Mixed Quiz",
                        actionType: .generateMixedQuiz,
                        lessonId: nil,
                        artifactKind: nil,
                        examId: nil,
                        deckId: nil,
                        studyGuideId: nil
                    )
                )
            )
        }

        return items.sorted {
            if $0.urgency == $1.urgency {
                return $0.title < $1.title
            }
            return $0.urgency > $1.urgency
        }
    }

    private func mapPace(_ pace: CourseProgress.Pace) -> CourseDashboardPace {
        switch pace {
        case .onTrack:
            return .onTrack
        case .atRisk:
            return .atRisk
        case .critical:
            return .critical
        case .noExam:
            return .noExam
        }
    }
}
