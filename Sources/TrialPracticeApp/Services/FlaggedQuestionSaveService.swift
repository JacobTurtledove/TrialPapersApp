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
    let studyStatus: FlaggedQuestionStudyStatus
    let priority: FlaggedQuestionPriority
    let marksAvailable: Int?
    let topic: String?
    let studyNotes: String?
    let nextReviewAt: Date?

    init(
        paper: Paper,
        subject: Subject,
        school: School,
        questionDocument: PDFDocument,
        questionRange: PDFCaptureRange,
        solutionDocument: PDFDocument?,
        solutionRange: PDFCaptureRange?,
        questionNumber: String,
        category: QuestionCategory,
        studyStatus: FlaggedQuestionStudyStatus = .active,
        priority: FlaggedQuestionPriority = .normal,
        marksAvailable: Int? = nil,
        topic: String? = nil,
        studyNotes: String? = nil,
        nextReviewAt: Date? = nil
    ) {
        self.paper = paper
        self.subject = subject
        self.school = school
        self.questionDocument = questionDocument
        self.questionRange = questionRange
        self.solutionDocument = solutionDocument
        self.solutionRange = solutionRange
        self.questionNumber = questionNumber
        self.category = category
        self.studyStatus = studyStatus
        self.priority = priority
        self.marksAvailable = marksAvailable
        self.topic = topic
        self.studyNotes = studyNotes
        self.nextReviewAt = nextReviewAt
    }
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
            solutionImageRelativePath: images.solutionRelativePath,
            studyStatus: request.studyStatus,
            priority: request.priority,
            marksAvailable: request.marksAvailable,
            topic: normalizedOptional(request.topic),
            studyNotes: normalizedOptional(request.studyNotes),
            nextReviewAt: request.studyStatus == .mastered ? nil : request.nextReviewAt
        )
    }

    private func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
