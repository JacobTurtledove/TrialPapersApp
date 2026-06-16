import Foundation
import SwiftData

enum QuestionCategory: String, Codable, CaseIterable {
    case mistake = "Mistake"
    case unlearnedContent = "Unlearned Content"
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
    var createdAt: Date
    var deletedAt: Date?

    var category: QuestionCategory {
        get { QuestionCategory(rawValue: categoryRawValue) ?? .mistake }
        set { categoryRawValue = newValue.rawValue }
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
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}
