import Foundation
import Testing
@testable import Revu

@Suite("Course lesson-first flow")
struct CourseLessonFlowTests {
    @Test("Grouping materials assigns them to the created lesson")
    func groupingMaterialsAssignsLesson() async throws {
        let root = tempRoot()
        let storage = try await MainActor.run { try SQLiteStorage(rootURL: root) }
        let service = CourseService(storage: storage)

        let course = Course(name: "Biology 101")
        await service.upsert(course: course)

        let materialA = CourseMaterialDTO(
            courseId: course.id,
            filename: "Lecture 1.pdf",
            fileType: "pdf",
            extractedText: "Cell theory basics.",
            wordCount: 3,
            processingStatus: .ready,
            processedAt: Date()
        )
        let materialB = CourseMaterialDTO(
            courseId: course.id,
            filename: "Lecture 2.pdf",
            fileType: "pdf",
            extractedText: "Mitochondria and ATP.",
            wordCount: 3,
            processingStatus: .ready,
            processedAt: Date()
        )
        try await storage.upsert(material: materialA)
        try await storage.upsert(material: materialB)

        let createdLesson = await service.createLesson(
            fromMaterialIds: [materialA.id, materialB.id],
            title: "Week 1"
        )
        let lesson = try #require(createdLesson)
        #expect(lesson.title == "Week 1")

        let refreshedA = try #require(try await storage.material(withId: materialA.id))
        let refreshedB = try #require(try await storage.material(withId: materialB.id))
        #expect(refreshedA.lessonId == lesson.id)
        #expect(refreshedB.lessonId == lesson.id)
    }

    @Test("Dashboard marks flashcards ready when lesson-linked deck exists")
    func dashboardReflectsLessonArtifacts() async throws {
        let root = tempRoot()
        let storage = try await MainActor.run { try SQLiteStorage(rootURL: root) }
        let service = CourseService(storage: storage)

        let course = Course(name: "Chemistry")
        await service.upsert(course: course)

        let lesson = Lesson(courseId: course.id, title: "Stoichiometry")
        await service.upsert(lesson: lesson)

        let material = CourseMaterial(
            courseId: course.id,
            lessonId: lesson.id,
            filename: "Stoichiometry.pdf",
            fileType: "pdf",
            extractedText: "Moles and balancing equations.",
            wordCount: 4,
            processingStatus: .ready,
            processedAt: Date()
        )
        await service.upsert(material: material)

        let deck = Deck(
            courseId: course.id,
            originLessonId: lesson.id,
            kind: .deck,
            name: "Stoichiometry Flashcards"
        )
        try await storage.upsert(deck: deck.toDTO())

        let card = Card(deckId: deck.id, kind: .basic, front: "What is a mole?", back: "6.022e23 particles")
        try await storage.upsert(card: card.toDTO())

        let dashboard = await service.courseDashboard(courseId: course.id)
        let summary = try #require(dashboard.lessonSummaries.first(where: { $0.lesson.id == lesson.id }))
        let flashcards = try #require(summary.artifactSummaries.first(where: { $0.kind == .flashcards }))
        #expect(flashcards.status == .ready)
        #expect(flashcards.count == 1)
    }

    private func tempRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("revu-course-lesson-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
