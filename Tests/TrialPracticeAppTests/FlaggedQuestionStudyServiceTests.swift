import Foundation
import SwiftData
import Testing
@testable import TrialPracticeApp

struct FlaggedQuestionStudyServiceTests {
    @Test
    func statusCompatibilityMapsExistingCompletedBoolean() {
        let completed = makeQuestion(isCompleted: true)
        let incomplete = makeQuestion(isCompleted: false)

        #expect(completed.studyStatus == .mastered)
        #expect(incomplete.studyStatus == .active)

        incomplete.studyStatus = .needsReview
        #expect(!incomplete.isCompleted)
        incomplete.studyStatus = .mastered
        #expect(incomplete.isCompleted)
    }

    @Test
    func schedulerAppliesOutcomeAndConfidenceRules() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let attemptedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let scheduler = FlaggedQuestionStudyScheduler(calendar: calendar)

        let wrong = scheduler.schedule(
            outcome: .wrong,
            confidence: .high,
            attemptedAt: attemptedAt
        )
        let partial = scheduler.schedule(
            outcome: .partial,
            confidence: .medium,
            attemptedAt: attemptedAt
        )
        let correctLow = scheduler.schedule(
            outcome: .correct,
            confidence: .low,
            attemptedAt: attemptedAt
        )
        let correctMedium = scheduler.schedule(
            outcome: .correct,
            confidence: .medium,
            attemptedAt: attemptedAt
        )
        let correctHigh = scheduler.schedule(
            outcome: .correct,
            confidence: .high,
            attemptedAt: attemptedAt
        )

        #expect(wrong.status == .needsReview)
        #expect(wrong.nextReviewAt == calendar.date(byAdding: .day, value: 1, to: attemptedAt))
        #expect(partial.status == .needsReview)
        #expect(partial.nextReviewAt == calendar.date(byAdding: .day, value: 3, to: attemptedAt))
        #expect(correctLow.status == .active)
        #expect(correctLow.nextReviewAt == calendar.date(byAdding: .day, value: 3, to: attemptedAt))
        #expect(correctMedium.status == .active)
        #expect(correctMedium.nextReviewAt == calendar.date(byAdding: .day, value: 7, to: attemptedAt))
        #expect(correctHigh.status == .mastered)
        #expect(correctHigh.nextReviewAt == nil)
    }

    @Test
    @MainActor
    func attemptSaveCreatesAttemptAndUpdatesQuestion() throws {
        let container = try modelContainer()
        let question = makeQuestion()
        container.mainContext.insert(question)
        try container.mainContext.save()
        let attemptedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let attempt = try FlaggedQuestionAttemptService().recordAttempt(
            for: question,
            outcome: .partial,
            confidence: .medium,
            notes: "  revise method  ",
            attemptedAt: attemptedAt,
            modelContext: container.mainContext
        )
        let savedAttempts = try container.mainContext.fetch(
            FetchDescriptor<FlaggedQuestionAttempt>()
        )

        #expect(savedAttempts.map(\.id) == [attempt.id])
        #expect(attempt.notes == "revise method")
        #expect(question.studyStatus == .needsReview)
        #expect(question.lastAttemptedAt == attemptedAt)
        #expect(question.nextReviewAt != nil)
    }

    @Test
    func queueFiltersInactiveParentsAndSortsByDuePriorityAndCreatedDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let subject = Subject(displayName: "Physics", filenameValue: "Physics")
        let deletedSubject = Subject(
            displayName: "Chemistry",
            filenameValue: "Chemistry",
            deletedAt: now
        )
        let paper = Paper(
            subjectID: subject.id,
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: "paper.pdf",
            solutionsPDFRelativePath: "paper.pdf"
        )
        let deletedPaper = Paper(
            subjectID: subject.id,
            schoolID: UUID(),
            year: "2024",
            questionPDFRelativePath: "deleted.pdf",
            solutionsPDFRelativePath: "deleted.pdf",
            deletedAt: now
        )
        let dueHigh = makeQuestion(
            paperID: paper.id,
            subjectID: subject.id,
            schoolID: paper.schoolID,
            priority: .high,
            nextReviewAt: now.addingTimeInterval(-100),
            createdAt: now.addingTimeInterval(-300)
        )
        let dueNormal = makeQuestion(
            paperID: paper.id,
            subjectID: subject.id,
            schoolID: paper.schoolID,
            priority: .normal,
            nextReviewAt: now.addingTimeInterval(-100),
            createdAt: now.addingTimeInterval(-100)
        )
        let futureActive = makeQuestion(
            paperID: paper.id,
            subjectID: subject.id,
            schoolID: paper.schoolID,
            nextReviewAt: now.addingTimeInterval(100)
        )
        let mastered = makeQuestion(
            paperID: paper.id,
            subjectID: subject.id,
            schoolID: paper.schoolID,
            studyStatus: .mastered
        )
        let deletedParentQuestion = makeQuestion(
            paperID: deletedPaper.id,
            subjectID: subject.id,
            schoolID: deletedPaper.schoolID
        )
        let deletedSubjectQuestion = makeQuestion(
            subjectID: deletedSubject.id,
            schoolID: UUID()
        )

        let queue = FlaggedQuestionStudyQueueService().defaultQueue(
            questions: [
                futureActive,
                mastered,
                dueNormal,
                deletedParentQuestion,
                dueHigh,
                deletedSubjectQuestion
            ],
            papers: [paper, deletedPaper],
            subjects: [subject, deletedSubject],
            now: now
        )

        #expect(queue.map(\.id) == [dueHigh.id, dueNormal.id, futureActive.id])
    }

    @MainActor
    private func modelContainer() throws -> ModelContainer {
        let schema = Schema([
            FlaggedQuestion.self,
            FlaggedQuestionAttempt.self
        ])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    private func makeQuestion(
        paperID: UUID = UUID(),
        subjectID: UUID = UUID(),
        schoolID: UUID = UUID(),
        isCompleted: Bool = false,
        studyStatus: FlaggedQuestionStudyStatus? = nil,
        priority: FlaggedQuestionPriority = .normal,
        nextReviewAt: Date? = nil,
        createdAt: Date = .now
    ) -> FlaggedQuestion {
        FlaggedQuestion(
            paperID: paperID,
            subjectID: subjectID,
            schoolID: schoolID,
            year: "2025",
            questionNumber: "1",
            category: .mistake,
            isCompleted: isCompleted,
            questionImageRelativePath: "Flagged Questions/Physics/Mistakes/q1.png",
            studyStatus: studyStatus,
            priority: priority,
            nextReviewAt: nextReviewAt,
            createdAt: createdAt
        )
    }
}
