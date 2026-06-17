import Foundation
import SwiftData

@Model
final class Paper {
    @Attribute(.unique) var id: UUID
    var subjectID: UUID
    var schoolID: UUID
    var year: String
    var mark: Double?
    var questionPDFRelativePath: String
    var solutionsPDFRelativePath: String
    var combinedPDFRelativePath: String?
    var solutionsStartPage: Int?
    var hasSolutions: Bool?
    var isCompleted: Bool = false
    var createdAt: Date
    var deletedAt: Date?

    var primaryPDFRelativePath: String {
        combinedPDFRelativePath ?? questionPDFRelativePath
    }

    init(
        id: UUID = UUID(),
        subjectID: UUID,
        schoolID: UUID,
        year: String,
        mark: Double? = nil,
        questionPDFRelativePath: String,
        solutionsPDFRelativePath: String,
        combinedPDFRelativePath: String? = nil,
        solutionsStartPage: Int? = nil,
        hasSolutions: Bool? = nil,
        isCompleted: Bool = false,
        createdAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.subjectID = subjectID
        self.schoolID = schoolID
        self.year = year
        self.mark = mark
        self.questionPDFRelativePath = questionPDFRelativePath
        self.solutionsPDFRelativePath = solutionsPDFRelativePath
        self.combinedPDFRelativePath = combinedPDFRelativePath
        self.solutionsStartPage = solutionsStartPage
        self.hasSolutions = hasSolutions
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}
