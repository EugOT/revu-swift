import Foundation
import Testing
@testable import Revu

@Suite("Workspace study plan behavior")
struct StudyPlanWorkspaceTests {
    private struct MockStorage: Storage {
        var decks: [DeckDTO]
        var cards: [CardDTO]
        var settings: UserSettingsDTO

        func allDecks() async throws -> [DeckDTO] { decks }
        func allCards() async throws -> [CardDTO] { cards }
        func loadSettings() async throws -> UserSettingsDTO { settings }

        // Unused in these tests
        func deck(withId id: UUID) async throws -> DeckDTO? { fatalError() }
        func upsert(deck: DeckDTO) async throws { fatalError() }
        func deleteDeck(id: UUID) async throws { fatalError() }
        func cards(deckId: UUID) async throws -> [CardDTO] { fatalError() }
        func card(withId id: UUID) async throws -> CardDTO? { fatalError() }
        func searchCards(text: String, tags: Set<String>, deckId: UUID?) async throws -> [CardDTO] { fatalError() }
        func upsert(card: CardDTO) async throws { fatalError() }
        func deleteCard(id: UUID) async throws { fatalError() }
        func dueCards(on date: Date, limit: Int?) async throws -> [CardDTO] { fatalError() }
        func newCards(limit: Int) async throws -> [CardDTO] { fatalError() }
        func save(card: CardDTO) async throws { fatalError() }
        func recentLogs(limit: Int) async throws -> [ReviewLogDTO] { fatalError() }
        func append(log: ReviewLogDTO) async throws { fatalError() }
        func save(settings: UserSettingsDTO) async throws { fatalError() }
        func recentEvents(limit: Int) async throws -> [StudyEventDTO] { fatalError() }
        func append(event: StudyEventDTO) async throws { fatalError() }
        func allExams() async throws -> [ExamDTO] { fatalError() }
        func exams(parentFolderId: UUID) async throws -> [ExamDTO] { fatalError() }
        func exam(withId id: UUID) async throws -> ExamDTO? { fatalError() }
        func upsert(exam: ExamDTO) async throws { fatalError() }
        func deleteExam(id: UUID) async throws { fatalError() }
        func allStudyGuides() async throws -> [StudyGuideDTO] { fatalError() }
        func studyGuides(parentFolderId: UUID) async throws -> [StudyGuideDTO] { fatalError() }
        func searchStudyGuides(query: String, parentFolderId: UUID?) async throws -> [StudyGuideDTO] { fatalError() }
        func studyGuide(withId id: UUID) async throws -> StudyGuideDTO? { fatalError() }
        func upsert(studyGuide: StudyGuideDTO) async throws { fatalError() }
        func deleteStudyGuide(id: UUID) async throws { fatalError() }
        func allConceptStates() async throws -> [ConceptState] { [] }
        func conceptState(forKey key: String) async throws -> ConceptState? { nil }
        func upsert(conceptState: ConceptState) async throws { }

        // CourseRepository
        func allCourses() async throws -> [CourseDTO] { [] }
        func course(withId id: UUID) async throws -> CourseDTO? { nil }
        func upsert(course: CourseDTO) async throws { fatalError() }
        func deleteCourse(id: UUID) async throws { fatalError() }

        // CourseTopicRepository
        func allTopics() async throws -> [CourseTopicDTO] { [] }
        func topics(courseId: UUID) async throws -> [CourseTopicDTO] { [] }
        func topic(withId id: UUID) async throws -> CourseTopicDTO? { nil }
        func upsert(topic: CourseTopicDTO) async throws { fatalError() }
        func deleteTopic(id: UUID) async throws { fatalError() }

        // LessonRepository
        func allLessons() async throws -> [LessonDTO] { [] }
        func lessons(courseId: UUID) async throws -> [LessonDTO] { [] }
        func lesson(withId id: UUID) async throws -> LessonDTO? { nil }
        func upsert(lesson: LessonDTO) async throws { fatalError() }
        func deleteLesson(id: UUID) async throws { fatalError() }

        // CourseMaterialRepository
        func allMaterials() async throws -> [CourseMaterialDTO] { [] }
        func materials(courseId: UUID) async throws -> [CourseMaterialDTO] { [] }
        func material(withId id: UUID) async throws -> CourseMaterialDTO? { nil }
        func upsert(material: CourseMaterialDTO) async throws { fatalError() }
        func deleteMaterial(id: UUID) async throws { fatalError() }

        // LessonGenerationJobRepository
        func lessonGenerationJobs(lessonId: UUID) async throws -> [LessonGenerationJobDTO] { [] }
        func upsert(lessonGenerationJob: LessonGenerationJobDTO) async throws { fatalError() }
        func deleteLessonGenerationJobs(lessonId: UUID) async throws { fatalError() }

        // ContentChunkRepository
        func allChunks(courseId: UUID) async throws -> [ContentChunk] { [] }
        func searchChunks(courseId: UUID, keywords: [String], limit: Int) async throws -> [ContentChunk] { [] }
        func upsert(chunk: ContentChunk) async throws { fatalError() }
        func deleteChunks(courseId: UUID) async throws { fatalError() }
    }

    @Test("Workspace forecast keeps each deck active until its cards are scheduled")
    func testWorkspaceForecastDistributesAcrossDecks() async throws {
        let now = Date(timeIntervalSince1970: 0)
        let deckA = DeckDTO(
            id: UUID(),
            name: "Deck A",
            note: nil,
            dueDate: Calendar.current.date(byAdding: .day, value: 6, to: now),
            createdAt: now,
            updatedAt: now
        )
        let deckB = DeckDTO(
            id: UUID(),
            name: "Deck B",
            note: nil,
            dueDate: Calendar.current.date(byAdding: .day, value: 10, to: now),
            createdAt: now,
            updatedAt: now
        )

        func makeCard(deckId: UUID, createdOffsetMinutes: Int, queue: SRSStateDTO.Queue, fsrsReps: Int, dueOffsetDays: Int) -> CardDTO {
            let created = now.addingTimeInterval(TimeInterval(createdOffsetMinutes * 60))
            let due = now.addingTimeInterval(TimeInterval(dueOffsetDays) * 86_400)
            let srs = SRSStateDTO(
                id: UUID(),
                cardId: UUID(),
                easeFactor: 2.5,
                interval: 0,
                repetitions: fsrsReps,
                lapses: 0,
                dueDate: due,
                lastReviewed: fsrsReps > 0 ? created : nil,
                queue: queue,
                stability: fsrsReps > 0 ? 5.0 : 0.6,
                difficulty: 5.0,
                fsrsReps: fsrsReps,
                lastElapsedSeconds: nil
            )
            return CardDTO(
                id: srs.cardId,
                deckId: deckId,
                kind: .basic,
                front: "Q",
                back: "A",
                clozeSource: nil,
                choices: [],
                correctChoiceIndex: nil,
                tags: [],
                media: [],
                createdAt: created,
                updatedAt: created,
                isSuspended: false,
                srs: srs
            )
        }

        let cardsA: [CardDTO] =
            (0..<12).map { makeCard(deckId: deckA.id, createdOffsetMinutes: -$0, queue: .new, fsrsReps: 0, dueOffsetDays: 0) } +
            (0..<4).map { makeCard(deckId: deckA.id, createdOffsetMinutes: -200 - $0, queue: .review, fsrsReps: 3, dueOffsetDays: 12) }

        let cardsB: [CardDTO] =
            (0..<8).map { makeCard(deckId: deckB.id, createdOffsetMinutes: -$0, queue: .new, fsrsReps: 0, dueOffsetDays: 0) } +
            (0..<3).map { makeCard(deckId: deckB.id, createdOffsetMinutes: -120 - $0, queue: .review, fsrsReps: 4, dueOffsetDays: 8) }

        let storage = MockStorage(
            decks: [deckA, deckB],
            cards: cardsA + cardsB,
            settings: UserSettings().toDTO()
        )

        let service = StudyPlanService(storage: storage)
        let summaries = await service.workspaceForecast(referenceDate: now)
        #expect(summaries.count == 2)

        for summary in summaries {
            let counts = summary.days.map(\.total)
            let totalPlanned = counts.reduce(0, +)
            let expected = summary.deckId == deckA.id ? cardsA.count : cardsB.count
            #expect(totalPlanned == expected)

            if let firstNonZero = counts.firstIndex(where: { $0 > 0 }),
               let lastNonZero = counts.lastIndex(where: { $0 > 0 }),
               firstNonZero < lastNonZero {
                for idx in firstNonZero..<lastNonZero {
                    #expect(counts[idx] > 0) // no idle gap once work starts
                }
            }
        }
    }

    @Test("Existing far-out reviews get pulled inside the deck deadline buffer")
    func testReviewClampingBeforeDeadline() async throws {
        let now = Date(timeIntervalSince1970: 100_000)
        let dueDate = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        let deck = DeckDTO(
            id: UUID(),
            name: "Deadline Deck",
            note: nil,
            dueDate: dueDate,
            createdAt: now,
            updatedAt: now
        )

        let farFutureReview = CardDTO(
            id: UUID(),
            deckId: deck.id,
            kind: .basic,
            front: "Q",
            back: "A",
            clozeSource: nil,
            choices: [],
            correctChoiceIndex: nil,
            tags: [],
            media: [],
            createdAt: now,
            updatedAt: now,
            isSuspended: false,
            srs: SRSStateDTO(
                id: UUID(),
                cardId: UUID(),
                easeFactor: 2.5,
                interval: 30,
                repetitions: 5,
                lapses: 0,
                dueDate: Calendar.current.date(byAdding: .day, value: 20, to: now)!, // well past the deck due date
                lastReviewed: Calendar.current.date(byAdding: .day, value: -1, to: now),
                queue: .review,
                stability: 8.0,
                difficulty: 5.0,
                fsrsReps: 5,
                lastElapsedSeconds: nil
            )
        )

        let newCard = CardDTO(
            id: UUID(),
            deckId: deck.id,
            kind: .basic,
            front: "NQ",
            back: "NA",
            clozeSource: nil,
            choices: [],
            correctChoiceIndex: nil,
            tags: [],
            media: [],
            createdAt: now,
            updatedAt: now,
            isSuspended: false,
            srs: SRSStateDTO(
                id: UUID(),
                cardId: UUID(),
                easeFactor: 2.5,
                interval: 0,
                repetitions: 0,
                lapses: 0,
                dueDate: now,
                lastReviewed: nil,
                queue: .new,
                stability: 0.6,
                difficulty: 5.0,
                fsrsReps: 0,
                lastElapsedSeconds: nil
            )
        )

        let storage = MockStorage(
            decks: [deck],
            cards: [farFutureReview, newCard],
            settings: UserSettings().toDTO()
        )

        let service = StudyPlanService(storage: storage)
        let summaries = await service.workspaceForecast(referenceDate: now)
        let summary = try #require(summaries.first)

        let counts = summary.days.map(\.total)
        #expect(counts.reduce(0, +) == 2)

        // The review should appear no later than the start of the due date window.
        let lastDayWithWorkIndex = try #require(counts.lastIndex(where: { $0 > 0 }))
        let lastDay = summary.days[lastDayWithWorkIndex].date
        let expectedLatest = Calendar.current.startOfDay(for: dueDate)
        #expect(lastDay <= expectedLatest)
    }
}
