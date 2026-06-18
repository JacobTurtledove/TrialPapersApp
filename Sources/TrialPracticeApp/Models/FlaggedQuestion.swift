import Foundation
import SwiftData

enum QuestionCategory: String, Codable, CaseIterable {
    case mistake = "Mistake"
    case unlearnedContent = "Unlearned Content"
}

enum FlaggedQuestionStudyStatus: String, Codable, CaseIterable, Identifiable {
    case active = "Active"
    case needsReview = "Needs Review"
    case mastered = "Mastered"

    var id: String { rawValue }
}

enum FlaggedQuestionPriority: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"

    var id: String { rawValue }

    var sortRank: Int {
        switch self {
        case .high: 0
        case .normal: 1
        case .low: 2
        }
    }
}

enum FlaggedQuestionAttemptOutcome: String, Codable, CaseIterable, Identifiable {
    case correct = "Correct"
    case partial = "Partial"
    case wrong = "Wrong"

    var id: String { rawValue }
}

enum FlaggedQuestionAttemptConfidence: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

@Model
final class FlaggedQuestion {
    @Attribute(.unique) var id: UUID
    var paperID: UUID
    var subjectID: UUID
    var schoolID: UUID
    var year: String
    var questionNumber: String
    var categoryRawValue: String
    var isCompleted: Bool
    var questionImageRelativePath: String
    var solutionImageRelativePath: String?
    var studyStatusRawValue: String?
    var priorityRawValue: String?
    var marksAvailable: Int?
    var topic: String?
    var studyNotes: String?
    var nextReviewAt: Date?
    var lastAttemptedAt: Date?
    var createdAt: Date
    var deletedAt: Date?

    var category: QuestionCategory {
        get { QuestionCategory(rawValue: categoryRawValue) ?? .mistake }
        set { categoryRawValue = newValue.rawValue }
    }

    var studyStatus: FlaggedQuestionStudyStatus {
        get {
            if let studyStatusRawValue,
               let status = FlaggedQuestionStudyStatus(rawValue: studyStatusRawValue) {
                return status
            }
            return isCompleted ? .mastered : .active
        }
        set {
            studyStatusRawValue = newValue.rawValue
            isCompleted = newValue == .mastered
        }
    }

    var priority: FlaggedQuestionPriority {
        get {
            guard let priorityRawValue,
                  let priority = FlaggedQuestionPriority(rawValue: priorityRawValue) else {
                return .normal
            }
            return priority
        }
        set {
            priorityRawValue = newValue.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        paperID: UUID,
        subjectID: UUID,
        schoolID: UUID,
        year: String,
        questionNumber: String,
        category: QuestionCategory,
        isCompleted: Bool = false,
        questionImageRelativePath: String,
        solutionImageRelativePath: String? = nil,
        studyStatus: FlaggedQuestionStudyStatus? = nil,
        priority: FlaggedQuestionPriority = .normal,
        marksAvailable: Int? = nil,
        topic: String? = nil,
        studyNotes: String? = nil,
        nextReviewAt: Date? = nil,
        lastAttemptedAt: Date? = nil,
        createdAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.paperID = paperID
        self.subjectID = subjectID
        self.schoolID = schoolID
        self.year = year
        self.questionNumber = questionNumber
        self.categoryRawValue = category.rawValue
        self.isCompleted = isCompleted
        self.questionImageRelativePath = questionImageRelativePath
        self.solutionImageRelativePath = solutionImageRelativePath
        self.studyStatusRawValue = studyStatus?.rawValue
        self.priorityRawValue = priority.rawValue
        self.marksAvailable = marksAvailable
        self.topic = topic
        self.studyNotes = studyNotes
        self.nextReviewAt = nextReviewAt
        self.lastAttemptedAt = lastAttemptedAt
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

@Model
final class FlaggedQuestionAttempt {
    @Attribute(.unique) var id: UUID
    var questionID: UUID
    var attemptedAt: Date
    var outcomeRawValue: String
    var confidenceRawValue: String
    var notes: String?
    var appliedStatusRawValue: String
    var nextReviewAt: Date?

    var outcome: FlaggedQuestionAttemptOutcome {
        get { FlaggedQuestionAttemptOutcome(rawValue: outcomeRawValue) ?? .wrong }
        set { outcomeRawValue = newValue.rawValue }
    }

    var confidence: FlaggedQuestionAttemptConfidence {
        get { FlaggedQuestionAttemptConfidence(rawValue: confidenceRawValue) ?? .medium }
        set { confidenceRawValue = newValue.rawValue }
    }

    var appliedStatus: FlaggedQuestionStudyStatus {
        get { FlaggedQuestionStudyStatus(rawValue: appliedStatusRawValue) ?? .active }
        set { appliedStatusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        questionID: UUID,
        attemptedAt: Date = .now,
        outcome: FlaggedQuestionAttemptOutcome,
        confidence: FlaggedQuestionAttemptConfidence,
        notes: String? = nil,
        appliedStatus: FlaggedQuestionStudyStatus,
        nextReviewAt: Date? = nil
    ) {
        self.id = id
        self.questionID = questionID
        self.attemptedAt = attemptedAt
        self.outcomeRawValue = outcome.rawValue
        self.confidenceRawValue = confidence.rawValue
        self.notes = notes
        self.appliedStatusRawValue = appliedStatus.rawValue
        self.nextReviewAt = nextReviewAt
    }
}
