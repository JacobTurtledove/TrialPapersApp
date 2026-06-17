import Foundation
import PDFKit
import SwiftData

struct FlaggedQuestionSaveRequest {
    let paper: Paper
    let subject: Subject
    let school: School
    let questionDocument: PDFDocument
    let questionRange: PDFCaptureRange
    let solutionDocument: PDFDocument?
    let solutionRange: PDFCaptureRange?
    let questionNumber: String
    let category: QuestionCategory
}

@MainActor
struct FlaggedQuestionSaveService {
    let captureService: FlaggedQuestionCaptureService
    private let persist: (FlaggedQuestion, ModelContext) throws -> Void

    init(
        rootURL: URL,
        persist: @escaping (FlaggedQuestion, ModelContext) throws -> Void = {
            flaggedQuestion,
            modelContext in
            modelContext.insert(flaggedQuestion)
            try modelContext.save()
        }
    ) {
        captureService = FlaggedQuestionCaptureService(rootURL: rootURL)
        self.persist = persist
    }

    func save(
        _ request: FlaggedQuestionSaveRequest,
        modelContext: ModelContext
    ) throws -> FlaggedQuestion {
        let questionPNG = try captureService.capturePNG(
            from: request.questionDocument,
            range: request.questionRange
        )

        let solutionPNG: Data?
        switch (request.solutionDocument, request.solutionRange) {
        case let (document?, range?):
            solutionPNG = try captureService.capturePNG(from: document, range: range)
        case (nil, nil):
            solutionPNG = nil
        default:
            throw FlaggedQuestionCaptureService.CaptureError.invalidPageRange
        }

        let images = try captureService.saveImages(
            questionPNG: questionPNG,
            solutionPNG: solutionPNG,
            subject: request.subject,
            school: request.school,
            year: request.paper.year,
            questionNumber: request.questionNumber,
            category: request.category
        )
        let flaggedQuestion = makeFlaggedQuestion(
            request: request,
            images: images
        )

        do {
            try persist(flaggedQuestion, modelContext)
            return flaggedQuestion
        } catch {
            modelContext.delete(flaggedQuestion)
            try? captureService.deleteImages(for: flaggedQuestion)
            throw error
        }
    }

    private func makeFlaggedQuestion(
        request: FlaggedQuestionSaveRequest,
        images: SavedFlaggedQuestionImages
    ) -> FlaggedQuestion {
        FlaggedQuestion(
            paperID: request.paper.id,
            subjectID: request.subject.id,
            schoolID: request.school.id,
            year: request.paper.year,
            questionNumber: request.questionNumber.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            category: request.category,
            questionImageRelativePath: images.questionRelativePath,
            solutionImageRelativePath: images.solutionRelativePath
        )
    }
}
