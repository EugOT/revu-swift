@preconcurrency import Foundation
import Combine

@MainActor
final class CourseViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var courses: [Course] = []
    @Published var selectedCourse: Course?
    @Published private(set) var topics: [CourseTopic] = []
    @Published private(set) var lessons: [Lesson] = []
    @Published private(set) var materials: [CourseMaterial] = []
    @Published private(set) var linkedDecks: [Deck] = []
    @Published private(set) var linkedExams: [Exam] = []
    @Published private(set) var linkedStudyGuides: [StudyGuide] = []
    @Published private(set) var courseProgress: CourseProgress?
    @Published private(set) var dashboard: CourseDashboardSnapshot?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var error: String?

    // Available (unlinked) items for picker
    @Published private(set) var availableDecks: [Deck] = []
    @Published private(set) var availableExams: [Exam] = []
    @Published private(set) var availableStudyGuides: [StudyGuide] = []
    @Published private(set) var isMaterialUploading: Bool = false

    // MARK: - Private

    private let courseService: CourseService

    // MARK: - Init

    init(storage: Storage) {
        self.courseService = CourseService(storage: storage)
    }

    convenience init() {
        self.init(storage: DataController.shared.storage)
    }

    // MARK: - Course List

    func loadCourses() {
        Task {
            isLoading = true
            error = nil
            defer { isLoading = false }

            courses = await courseService.allCourses()
        }
    }

    // MARK: - Selection

    func selectCourse(_ course: Course) {
        selectedCourse = course
        Task {
            await loadDetailData(for: course.id)
        }
    }

    func refreshSelectedCourse() {
        guard let course = selectedCourse else { return }
        Task {
            if let refreshed = await courseService.course(withId: course.id) {
                selectedCourse = refreshed
            }
            await loadDetailData(for: course.id)
        }
    }

    // MARK: - Course CRUD

    func createCourse(
        name: String,
        courseCode: String? = nil,
        examDate: Date? = nil,
        weeklyTimeBudgetMinutes: Int? = nil,
        colorHex: String? = nil
    ) {
        Task {
            error = nil
            let now = Date()
            let course = Course(
                id: UUID(),
                name: name,
                courseCode: courseCode,
                examDate: examDate,
                weeklyTimeBudgetMinutes: weeklyTimeBudgetMinutes,
                colorHex: colorHex,
                createdAt: now,
                updatedAt: now
            )
            await courseService.upsert(course: course)
            courses = await courseService.allCourses()
        }
    }

    func updateCourse(_ course: Course) {
        Task {
            error = nil
            await courseService.upsert(course: course)
            courses = await courseService.allCourses()

            if selectedCourse?.id == course.id {
                selectedCourse = await courseService.course(withId: course.id)
                await loadDetailData(for: course.id)
            }
        }
    }

    func deleteCourse(id: UUID) {
        Task {
            error = nil
            await courseService.deleteCourse(id: id)
            courses = await courseService.allCourses()

            if selectedCourse?.id == id {
                selectedCourse = nil
                clearDetailData()
            }
        }
    }

    // MARK: - Topics (Legacy)

    func addTopic(name: String, courseId: UUID) {
        Task {
            error = nil
            let existingTopics = await courseService.topics(courseId: courseId)
            let nextOrder = (existingTopics.map(\.sortOrder).max() ?? -1) + 1
            let topic = CourseTopic(
                id: UUID(),
                courseId: courseId,
                name: name,
                sortOrder: nextOrder
            )
            await courseService.upsert(topic: topic)

            if selectedCourse?.id == courseId {
                topics = await courseService.topics(courseId: courseId)
            }
        }
    }

    func deleteTopic(id: UUID) {
        Task {
            error = nil
            await courseService.deleteTopic(id: id)

            if let courseId = selectedCourse?.id {
                topics = await courseService.topics(courseId: courseId)
            }
        }
    }

    // MARK: - Lesson Actions

    func createLessonFromMaterials(materialIds: [UUID], title: String? = nil) {
        guard !materialIds.isEmpty else { return }
        Task {
            guard selectedCourse != nil else { return }
            error = nil
            _ = await courseService.createLesson(fromMaterialIds: materialIds, title: title)
            await refreshCurrentCourseData()
        }
    }

    func assignMaterial(materialId: UUID, toLessonId lessonId: UUID?) {
        Task {
            await courseService.assignMaterial(materialId: materialId, toLessonId: lessonId)
            await refreshCurrentCourseData()
        }
    }

    func generateLessonArtifacts(lessonId: UUID, kinds: [LessonArtifactKind]) {
        Task {
            isGenerating = true
            defer { isGenerating = false }
            await courseService.generateLessonArtifacts(lessonId: lessonId, kinds: kinds)
            await refreshCurrentCourseData()
        }
    }

    func generateMissingArtifacts(kind: LessonArtifactKind) {
        guard let dashboard else { return }
        Task {
            isGenerating = true
            defer { isGenerating = false }

            let lessonIds = dashboard.lessonSummaries.compactMap { summary -> UUID? in
                let item = summary.artifactSummaries.first(where: { $0.kind == kind })
                return item?.status == .ready ? nil : summary.lesson.id
            }

            for lessonId in lessonIds {
                await courseService.generateLessonArtifacts(lessonId: lessonId, kinds: [kind])
            }
            await refreshCurrentCourseData()
        }
    }

    func refreshMixedQuiz() {
        guard let courseId = selectedCourse?.id else { return }
        Task {
            isGenerating = true
            defer { isGenerating = false }
            await courseService.generateCourseMixedQuiz(courseId: courseId)
            await refreshCurrentCourseData()
        }
    }

    // MARK: - Available Items (for linking picker)

    func loadAvailableItems() {
        Task {
            async let decks = courseService.availableDecks()
            async let exams = courseService.availableExams()
            async let guides = courseService.availableStudyGuides()

            availableDecks = await decks
            availableExams = await exams
            availableStudyGuides = await guides
        }
    }

    // MARK: - Linking: Decks

    func linkDeck(_ deckId: UUID) {
        guard let courseId = selectedCourse?.id else { return }
        Task {
            error = nil
            await courseService.linkDeck(deckId, toCourse: courseId)
            linkedDecks = await courseService.decks(courseId: courseId)
            availableDecks = await courseService.availableDecks()
            dashboard = await courseService.courseDashboard(courseId: courseId)
        }
    }

    func unlinkDeck(_ deckId: UUID) {
        guard let courseId = selectedCourse?.id else { return }
        Task {
            error = nil
            await courseService.unlinkDeck(deckId)
            linkedDecks = await courseService.decks(courseId: courseId)
            availableDecks = await courseService.availableDecks()
            dashboard = await courseService.courseDashboard(courseId: courseId)
        }
    }

    // MARK: - Linking: Exams

    func linkExam(_ examId: UUID) {
        guard let courseId = selectedCourse?.id else { return }
        Task {
            error = nil
            await courseService.linkExam(examId, toCourse: courseId)
            linkedExams = await courseService.exams(courseId: courseId)
            availableExams = await courseService.availableExams()
            dashboard = await courseService.courseDashboard(courseId: courseId)
        }
    }

    func unlinkExam(_ examId: UUID) {
        guard let courseId = selectedCourse?.id else { return }
        Task {
            error = nil
            await courseService.unlinkExam(examId)
            linkedExams = await courseService.exams(courseId: courseId)
            availableExams = await courseService.availableExams()
            dashboard = await courseService.courseDashboard(courseId: courseId)
        }
    }

    // MARK: - Linking: Study Guides

    func linkStudyGuide(_ guideId: UUID) {
        guard let courseId = selectedCourse?.id else { return }
        Task {
            error = nil
            await courseService.linkStudyGuide(guideId, toCourse: courseId)
            linkedStudyGuides = await courseService.studyGuides(courseId: courseId)
            availableStudyGuides = await courseService.availableStudyGuides()
            dashboard = await courseService.courseDashboard(courseId: courseId)
        }
    }

    func unlinkStudyGuide(_ guideId: UUID) {
        guard let courseId = selectedCourse?.id else { return }
        Task {
            error = nil
            await courseService.unlinkStudyGuide(guideId)
            linkedStudyGuides = await courseService.studyGuides(courseId: courseId)
            availableStudyGuides = await courseService.availableStudyGuides()
            dashboard = await courseService.courseDashboard(courseId: courseId)
        }
    }

    // MARK: - Material Upload

    func addMaterial(url: URL) {
        guard let courseId = selectedCourse?.id else { return }
        Task {
            error = nil
            isMaterialUploading = true
            defer { isMaterialUploading = false }

            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }

            do {
                _ = try await courseService.ingestMaterial(url: url, courseId: courseId)
                await refreshCurrentCourseData()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    func dashboardLessonSummary(lessonId: UUID) -> LessonDashboardSummary? {
        dashboard?.lessonSummaries.first(where: { $0.lesson.id == lessonId })
    }

    // MARK: - Private

    private func refreshCurrentCourseData() async {
        guard let courseId = selectedCourse?.id else { return }
        await loadDetailData(for: courseId)
    }

    private func loadDetailData(for courseId: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        async let fetchedTopics = courseService.topics(courseId: courseId)
        async let fetchedLessons = courseService.lessons(courseId: courseId)
        async let fetchedMaterials = courseService.materials(courseId: courseId)
        async let fetchedDecks = courseService.decks(courseId: courseId)
        async let fetchedExams = courseService.exams(courseId: courseId)
        async let fetchedGuides = courseService.studyGuides(courseId: courseId)
        async let fetchedProgress = courseService.courseProgress(courseId: courseId)
        async let fetchedDashboard = courseService.courseDashboard(courseId: courseId)

        topics = await fetchedTopics
        lessons = await fetchedLessons
        materials = await fetchedMaterials
        linkedDecks = await fetchedDecks
        linkedExams = await fetchedExams
        linkedStudyGuides = await fetchedGuides
        courseProgress = await fetchedProgress
        dashboard = await fetchedDashboard
    }

    private func clearDetailData() {
        topics = []
        lessons = []
        materials = []
        linkedDecks = []
        linkedExams = []
        linkedStudyGuides = []
        courseProgress = nil
        dashboard = nil
        availableDecks = []
        availableExams = []
        availableStudyGuides = []
    }
}
