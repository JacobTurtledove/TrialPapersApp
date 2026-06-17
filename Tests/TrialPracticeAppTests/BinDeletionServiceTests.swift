import Foundation
import SwiftData
import Testing
@testable import TrialPracticeApp

private enum BinDeletionServiceTestError: Error {
    case saveFailed
}

struct BinDeletionServiceTests {
    @Test
    @MainActor
    func permanentlyDeletingSubjectRemovesRelatedModelsAndFiles() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let container = try modelContainer()
        let context = container.mainContext
        let subject = Subject(displayName: "Physics", filenameValue: "Physics")
        let otherSubject = Subject(displayName: "Chemistry", filenameValue: "Chemistry")
        let paper = Paper(
            subjectID: subject.id,
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: "Papers/Physics/Example/paper.pdf",
            solutionsPDFRelativePath: "Papers/Physics/Example/paper.pdf"
        )
        let otherPaper = Paper(
            subjectID: otherSubject.id,
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: "Papers/Chemistry/Example/paper.pdf",
            solutionsPDFRelativePath: "Papers/Chemistry/Example/paper.pdf"
        )
        let question = FlaggedQuestion(
            paperID: paper.id,
            subjectID: subject.id,
            schoolID: paper.schoolID,
            year: paper.year,
            questionNumber: "1",
            category: .mistake,
            questionImageRelativePath: "Flagged Questions/Physics/Mistakes/q1.png"
        )
        let importRecord = THSCImportRecord(
            sourceIdentifier: "physics-paper",
            sourceTitle: "Physics Paper",
            sourcePageURL: "https://example.com",
            paperID: paper.id
        )
        try insertAndSave(in: context) {
            $0.insert(subject)
            $0.insert(otherSubject)
            $0.insert(paper)
            $0.insert(otherPaper)
            $0.insert(question)
            $0.insert(importRecord)
        }
        try writeFile("paper", at: rootURL.appending(path: paper.questionPDFRelativePath))
        try writeFile("other", at: rootURL.appending(path: otherPaper.questionPDFRelativePath))
        try writeFile("question", at: rootURL.appending(path: question.questionImageRelativePath))

        try BinDeletionService(rootURL: rootURL, modelContext: context).permanentlyDelete(
            subject,
            papers: [paper, otherPaper],
            flaggedQuestions: [question],
            importRecords: [importRecord]
        )

        #expect(try context.fetch(FetchDescriptor<Subject>()).map(\.id) == [otherSubject.id])
        #expect(try context.fetch(FetchDescriptor<Paper>()).map(\.id) == [otherPaper.id])
        #expect(try context.fetch(FetchDescriptor<FlaggedQuestion>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<THSCImportRecord>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: rootURL.appending(path: "Papers/Physics").path))
        #expect(!FileManager.default.fileExists(
            atPath: rootURL.appending(path: "Flagged Questions/Physics").path
        ))
        #expect(FileManager.default.fileExists(atPath: rootURL.appending(path: otherPaper.questionPDFRelativePath).path))
    }

    @Test
    @MainActor
    func permanentlyDeletingPaperRemovesRelatedQuestionsRecordsAndFiles() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let container = try modelContainer()
        let context = container.mainContext
        let subjectID = UUID()
        let paper = Paper(
            subjectID: subjectID,
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: "Papers/Physics/Example/paper.pdf",
            solutionsPDFRelativePath: "Papers/Physics/Example/paper.pdf"
        )
        let otherPaper = Paper(
            subjectID: subjectID,
            schoolID: UUID(),
            year: "2024",
            questionPDFRelativePath: "Papers/Physics/Other/paper.pdf",
            solutionsPDFRelativePath: "Papers/Physics/Other/paper.pdf"
        )
        let question = FlaggedQuestion(
            paperID: paper.id,
            subjectID: subjectID,
            schoolID: paper.schoolID,
            year: paper.year,
            questionNumber: "1",
            category: .mistake,
            questionImageRelativePath: "Flagged Questions/Physics/Mistakes/q1.png"
        )
        let importRecord = THSCImportRecord(
            sourceIdentifier: "physics-paper",
            sourceTitle: "Physics Paper",
            sourcePageURL: "https://example.com",
            paperID: paper.id
        )
        try insertAndSave(in: context) {
            $0.insert(paper)
            $0.insert(otherPaper)
            $0.insert(question)
            $0.insert(importRecord)
        }
        try writeFile("paper", at: rootURL.appending(path: paper.questionPDFRelativePath))
        try writeFile("other", at: rootURL.appending(path: otherPaper.questionPDFRelativePath))
        try writeFile("question", at: rootURL.appending(path: question.questionImageRelativePath))

        try BinDeletionService(rootURL: rootURL, modelContext: context).permanentlyDelete(
            paper,
            flaggedQuestions: [question],
            importRecords: [importRecord]
        )

        #expect(try context.fetch(FetchDescriptor<Paper>()).map(\.id) == [otherPaper.id])
        #expect(try context.fetch(FetchDescriptor<FlaggedQuestion>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<THSCImportRecord>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: rootURL.appending(path: paper.questionPDFRelativePath).path))
        #expect(!FileManager.default.fileExists(atPath: rootURL.appending(path: question.questionImageRelativePath).path))
        #expect(FileManager.default.fileExists(atPath: rootURL.appending(path: otherPaper.questionPDFRelativePath).path))
    }

    @Test
    @MainActor
    func permanentlyDeletingQuestionRemovesOnlyThatQuestionAndFiles() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let container = try modelContainer()
        let context = container.mainContext
        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: "Papers/Physics/Example/paper.pdf",
            solutionsPDFRelativePath: "Papers/Physics/Example/paper.pdf"
        )
        let question = FlaggedQuestion(
            paperID: paper.id,
            subjectID: paper.subjectID,
            schoolID: paper.schoolID,
            year: paper.year,
            questionNumber: "1",
            category: .mistake,
            questionImageRelativePath: "Flagged Questions/Physics/Mistakes/q1.png",
            solutionImageRelativePath: "Flagged Questions/Physics/Mistakes/q1-solution.png"
        )
        try insertAndSave(in: context) {
            $0.insert(paper)
            $0.insert(question)
        }
        try writeFile("paper", at: rootURL.appending(path: paper.questionPDFRelativePath))
        try writeFile("question", at: rootURL.appending(path: question.questionImageRelativePath))
        try writeFile("solution", at: rootURL.appending(path: try #require(question.solutionImageRelativePath)))

        try BinDeletionService(rootURL: rootURL, modelContext: context).permanentlyDelete(question)

        #expect(try context.fetch(FetchDescriptor<Paper>()).map(\.id) == [paper.id])
        #expect(try context.fetch(FetchDescriptor<FlaggedQuestion>()).isEmpty)
        #expect(FileManager.default.fileExists(atPath: rootURL.appending(path: paper.questionPDFRelativePath).path))
        #expect(!FileManager.default.fileExists(atPath: rootURL.appending(path: question.questionImageRelativePath).path))
        #expect(!FileManager.default.fileExists(
            atPath: rootURL.appending(path: try #require(question.solutionImageRelativePath)).path
        ))
    }

    @Test
    @MainActor
    func restoresStagedFilesAndModelsWhenSaveFails() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let container = try modelContainer()
        let context = container.mainContext
        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: "Papers/Physics/Example/paper.pdf",
            solutionsPDFRelativePath: "Papers/Physics/Example/paper.pdf"
        )
        try insertAndSave(in: context) {
            $0.insert(paper)
        }
        let fileURL = rootURL.appending(path: paper.questionPDFRelativePath)
        try writeFile("paper", at: fileURL)

        let service = BinDeletionService(
            rootURL: rootURL,
            modelContext: context,
            save: { throw BinDeletionServiceTestError.saveFailed }
        )

        #expect(throws: BinDeletionServiceTestError.saveFailed) {
            try service.permanentlyDelete(paper, flaggedQuestions: [], importRecords: [])
        }

        #expect(try context.fetch(FetchDescriptor<Paper>()).map(\.id) == [paper.id])
        #expect(try Data(contentsOf: fileURL) == Data("paper".utf8))
    }

    @MainActor
    private func modelContainer() throws -> ModelContainer {
        let schema = Schema([
            Subject.self,
            School.self,
            Paper.self,
            FlaggedQuestion.self,
            THSCImportRecord.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return container
    }

    private func insertAndSave(
        in context: ModelContext,
        insert: (ModelContext) -> Void
    ) throws {
        insert(context)
        try context.save()
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "BinDeletionServiceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeFile(_ contents: String, at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
    }
}
