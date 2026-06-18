import Foundation
import Testing
@testable import TrialPracticeApp

struct PaperValidationTests {
    @Test
    func papersStartIncompleteAndCanBeCompleted() {
        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: "paper.pdf",
            solutionsPDFRelativePath: "paper.pdf"
        )

        #expect(!paper.isCompleted)
        paper.isCompleted = true
        #expect(paper.isCompleted)
    }

    @Test
    func primaryPDFRelativePathUsesQuestionPathWhenCombinedPathIsMissing() {
        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: "question.pdf",
            solutionsPDFRelativePath: "solutions.pdf"
        )

        #expect(paper.primaryPDFRelativePath == "question.pdf")
    }

    @Test
    func primaryPDFRelativePathPrefersCombinedPathWhenPresent() {
        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: "question.pdf",
            solutionsPDFRelativePath: "solutions.pdf",
            combinedPDFRelativePath: "combined.pdf"
        )

        #expect(paper.primaryPDFRelativePath == "combined.pdf")
    }

    @Test
    func acceptsNumericYears() {
        #expect(PaperValidation.year(from: " 2025 ") == "2025")
    }

    @Test
    func rejectsNonNumericYears() {
        #expect(PaperValidation.year(from: "2025a") == nil)
        #expect(PaperValidation.year(from: "") == nil)
    }

    @Test
    func papersCanStoreNotes() {
        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            notes: "Completed multis",
            questionPDFRelativePath: "paper.pdf",
            solutionsPDFRelativePath: "paper.pdf"
        )

        #expect(paper.notes == "Completed multis")
    }

    @Test
    func createsSpecificationCompliantPaperFilenames() {
        let subject = Subject(
            displayName: "Maths Advanced",
            filenameValue: "MathsAdvanced"
        )
        let school = School(
            displayName: "North Sydney Boys",
            filenameValue: "NorthSydneyBoys"
        )

        #expect(
            PaperFileNames.combined(subject: subject, school: school, year: "2025")
                == "MathsAdvanced_NorthSydneyBoys_2025.pdf"
        )
        #expect(
            PaperFileNames.solutions(subject: subject, school: school, year: "2025")
                == "MathsAdvanced_NorthSydneyBoys_2025_sols.pdf"
        )
    }
}
