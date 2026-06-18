import Foundation
import SwiftData

struct FlaggedQuestionScheduleResult: Equatable {
    let status: FlaggedQuestionStudyStatus
    let nextReviewAt: Date?
}

struct FlaggedQuestionStudyScheduler {
    var calendar: Calendar = .current

    func schedule(
        outcome: FlaggedQuestionAttemptOutcome,
        confidence: FlaggedQuestionAttemptConfidence,
        attemptedAt: Date
    ) -> FlaggedQuestionScheduleResult {
        switch outcome {
        case .wrong:
            return FlaggedQuestionScheduleResult(
                status: .needsReview,
                nextReviewAt: reviewDate(days: 1, from: attemptedAt)
            )
        case .partial:
            return FlaggedQuestionScheduleResult(
                status: .needsReview,
                nextReviewAt: reviewDate(days: 3, from: attemptedAt)
            )
        case .correct:
            switch confidence {
            case .low:
                return FlaggedQuestionScheduleResult(
                    status: .active,
                    nextReviewAt: reviewDate(days: 3, from: attemptedAt)
                )
            case .medium:
                return FlaggedQuestionScheduleResult(
                    status: .active,
                    nextReviewAt: reviewDate(days: 7, from: attemptedAt)
                )
            case .high:
                return FlaggedQuestionScheduleResult(status: .mastered, nextReviewAt: nil)
            }
        }
    }

    private func reviewDate(days: Int, from date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
}

@MainActor
struct FlaggedQuestionAttemptService {
    var scheduler = FlaggedQuestionStudyScheduler()

    func recordAttempt(
        for question: FlaggedQuestion,
        outcome: FlaggedQuestionAttemptOutcome,
        confidence: FlaggedQuestionAttemptConfidence,
        notes: String?,
        attemptedAt: Date = .now,
        modelContext: ModelContext
    ) throws -> FlaggedQuestionAttempt {
        let result = scheduler.schedule(
            outcome: outcome,
            confidence: confidence,
            attemptedAt: attemptedAt
        )
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let attempt = FlaggedQuestionAttempt(
            questionID: question.id,
            attemptedAt: attemptedAt,
            outcome: outcome,
            confidence: confidence,
            notes: trimmedNotes?.isEmpty == true ? nil : trimmedNotes,
            appliedStatus: result.status,
            nextReviewAt: result.nextReviewAt
        )

        let oldStatus = question.studyStatus
        let oldNextReviewAt = question.nextReviewAt
        let oldLastAttemptedAt = question.lastAttemptedAt
        modelContext.insert(attempt)
        question.studyStatus = result.status
        question.nextReviewAt = result.nextReviewAt
        question.lastAttemptedAt = attemptedAt

        do {
            try modelContext.save()
            return attempt
        } catch {
            question.studyStatus = oldStatus
            question.nextReviewAt = oldNextReviewAt
            question.lastAttemptedAt = oldLastAttemptedAt
            modelContext.delete(attempt)
            modelContext.rollback()
            throw error
        }
    }

    func saveMetadata(
        for question: FlaggedQuestion,
        status: FlaggedQuestionStudyStatus,
        priority: FlaggedQuestionPriority,
        marksAvailable: Int?,
        topic: String,
        studyNotes: String,
        nextReviewAt: Date?,
        modelContext: ModelContext
    ) throws {
        let snapshot = MetadataSnapshot(question)
        question.studyStatus = status
        question.priority = priority
        question.marksAvailable = marksAvailable
        question.topic = normalizedOptional(topic)
        question.studyNotes = normalizedOptional(studyNotes)
        question.nextReviewAt = status == .mastered ? nil : nextReviewAt

        do {
            try modelContext.save()
        } catch {
            snapshot.restore(question)
            modelContext.rollback()
            throw error
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private struct MetadataSnapshot {
        let status: FlaggedQuestionStudyStatus
        let priority: FlaggedQuestionPriority
        let marksAvailable: Int?
        let topic: String?
        let studyNotes: String?
        let nextReviewAt: Date?

        init(_ question: FlaggedQuestion) {
            status = question.studyStatus
            priority = question.priority
            marksAvailable = question.marksAvailable
            topic = question.topic
            studyNotes = question.studyNotes
            nextReviewAt = question.nextReviewAt
        }

        func restore(_ question: FlaggedQuestion) {
            question.studyStatus = status
            question.priority = priority
            question.marksAvailable = marksAvailable
            question.topic = topic
            question.studyNotes = studyNotes
            question.nextReviewAt = nextReviewAt
        }
    }
}

struct FlaggedQuestionStudyQueueService {
    func activeQuestions(
        questions: [FlaggedQuestion],
        papers: [Paper],
        subjects: [Subject]
    ) -> [FlaggedQuestion] {
        let activeSubjectIDs = Set(subjects.filter { $0.deletedAt == nil }.map(\.id))
        let activePaperIDs = Set(papers.filter {
            $0.deletedAt == nil && activeSubjectIDs.contains($0.subjectID)
        }.map(\.id))
        return questions.filter {
            $0.deletedAt == nil &&
            activeSubjectIDs.contains($0.subjectID) &&
            activePaperIDs.contains($0.paperID)
        }
    }

    func defaultQueue(
        questions: [FlaggedQuestion],
        papers: [Paper],
        subjects: [Subject],
        now: Date = .now
    ) -> [FlaggedQuestion] {
        activeQuestions(questions: questions, papers: papers, subjects: subjects)
            .filter { question in
                question.studyStatus != .mastered ||
                    question.nextReviewAt.map { $0 <= now } == true
            }
            .sorted { lhs, rhs in
                compare(lhs, rhs, now: now)
            }
    }

    private func compare(
        _ lhs: FlaggedQuestion,
        _ rhs: FlaggedQuestion,
        now: Date
    ) -> Bool {
        let lhsOverdue = lhs.nextReviewAt.map { $0 <= now } ?? false
        let rhsOverdue = rhs.nextReviewAt.map { $0 <= now } ?? false
        if lhsOverdue != rhsOverdue {
            return lhsOverdue
        }

        switch (lhs.nextReviewAt, rhs.nextReviewAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            break
        }

        if lhs.priority.sortRank != rhs.priority.sortRank {
            return lhs.priority.sortRank < rhs.priority.sortRank
        }
        return lhs.createdAt > rhs.createdAt
    }
}
