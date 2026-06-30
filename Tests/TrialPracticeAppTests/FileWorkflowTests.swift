import AppKit
import Foundation
import PDFKit
import SwiftData
import Testing
@testable import TrialPracticeApp

private enum FlaggedQuestionSaveServiceTestError: Error {
    case persistenceFailed
}

struct FileWorkflowTests {
    @Test
    func exportsSubjectPapersAsSpecificationCompliantCSV() throws {
        let rows = [
            SubjectPaperCSVRow(
                schoolName: "North Sydney Boys",
                year: "2025"
            ),
            SubjectPaperCSVRow(
                schoolName: "James Ruse, Senior Campus",
                year: "2024"
            ),
            SubjectPaperCSVRow(
                schoolName: "A \"Quoted\" School",
                year: "2023"
            )
        ]

        let data = try SubjectPaperCSVService().csvData(rows: rows)
        let csv = try #require(String(data: data, encoding: .utf8))

        #expect(csv.hasPrefix("School,Year\n"))
        #expect(csv.contains("\"James Ruse, Senior Campus\",2024\n"))
        #expect(csv.contains("\"A \"\"Quoted\"\" School\",2023\n"))
        #expect(csv.contains("North Sydney Boys,2025\n"))
    }

    @Test
    func libraryExportCopiesNormalStoredRelativePath() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let relativePath = "Papers/Physics/ExampleSchool/paper.pdf"
        let storedURL = rootURL.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: storedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("paper".utf8).write(to: storedURL)

        let exportFolderURL = rootURL.appending(path: "Exported", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: exportFolderURL, withIntermediateDirectories: true)
        let destinationURL = exportFolderURL.appending(path: "paper.pdf")
        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: relativePath,
            solutionsPDFRelativePath: relativePath
        )

        let exportedURL = try LibraryExportService(rootURL: rootURL).exportPaper(
            paper,
            to: destinationURL
        )

        #expect(exportedURL == destinationURL)
        #expect(try Data(contentsOf: destinationURL) == Data("paper".utf8))
    }

    @Test
    func libraryExportingToStoredSourceDoesNotDeleteIt() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let relativePath = "Papers/Physics/ExampleSchool/paper.pdf"
        let storedURL = rootURL.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: storedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("paper".utf8).write(to: storedURL)

        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: relativePath,
            solutionsPDFRelativePath: relativePath
        )

        let exportedURL = try LibraryExportService(rootURL: rootURL).exportPaper(
            paper,
            to: storedURL
        )

        #expect(exportedURL == storedURL)
        #expect(try Data(contentsOf: storedURL) == Data("paper".utf8))
    }

    @Test
    func libraryExportRejectsAbsoluteStoredPath() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let exportFolderURL = rootURL.appending(path: "Exported", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: exportFolderURL, withIntermediateDirectories: true)
        let destinationURL = exportFolderURL.appending(path: "paper.pdf")
        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: "/tmp/outside.pdf",
            solutionsPDFRelativePath: "/tmp/outside.pdf"
        )

        #expect(throws: StoredFilePath.ValidationError.absolute) {
            try LibraryExportService(rootURL: rootURL).exportPaper(paper, to: destinationURL)
        }
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @Test
    func folderExportRejectsTraversalWithoutCreatingEscapedDestinationFolder() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let subjectID = UUID()
        let schoolID = UUID()
        let subject = Subject(
            id: subjectID,
            displayName: "Physics",
            filenameValue: "Physics"
        )
        let paper = Paper(
            subjectID: subjectID,
            schoolID: schoolID,
            year: "2025",
            questionPDFRelativePath: "../Escaped/paper.pdf",
            solutionsPDFRelativePath: "../Escaped/paper.pdf"
        )
        let exportParentURL = rootURL.appending(path: "Exports", directoryHint: .isDirectory)

        #expect(throws: StoredFilePath.ValidationError.parentDirectoryComponent) {
            try LibraryExportService(rootURL: rootURL).exportLibrary(
                subjects: [subject],
                papers: [paper],
                flaggedQuestions: [],
                to: exportParentURL
            )
        }
        #expect(!directoryExists(exportParentURL.appending(path: "Escaped")))
    }

    @Test
    func preparesExpectedFolderStructure() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let store = LocalFileStore(rootURL: rootURL)
        try store.prepareFolderStructure()

        #expect(directoryExists(rootURL.appending(path: "Papers")))
        #expect(directoryExists(rootURL.appending(path: "Flagged Questions")))
        #expect(!directoryExists(rootURL.appending(path: "School Crests")))
    }

    @Test
    func convertsSchoolCrestToBackendPNGData() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let sourceURL = rootURL.appending(path: "crest-source.png")
        try makePNG(label: "Crest", at: sourceURL)
        let pngData = try SchoolCrestService().pngData(from: sourceURL)

        #expect(NSImage(data: pngData) != nil)
        #expect(!directoryExists(rootURL.appending(path: "School Crests")))
    }

    @Test
    func storageMigrationEmbedsLegacyCrestsWithoutDeletingFiles() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let suiteName = "StorageMigrationServiceTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let legacyDirectory = rootURL.appending(
            path: "School Crests",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: legacyDirectory,
            withIntermediateDirectories: true
        )
        let crestURL = legacyDirectory.appending(path: "Example.png")
        try makePNG(label: "Example", at: crestURL)

        let school = School(
            displayName: "Example School",
            filenameValue: "ExampleSchool",
            crestImageRelativePath: "School Crests/Example.png"
        )
        let service = StorageMigrationService(userDefaults: userDefaults)

        let result = try service.migrateIfNeeded(rootURL: rootURL, schools: [school])

        #expect(result.didChangeModels)
        #expect(result.latestCompletedVersion == .legacySchoolCrestsEmbeddedData)
        #expect(school.crestImageData != nil)
        #expect(school.crestImageRelativePath == nil)
        #expect(FileManager.default.fileExists(atPath: crestURL.path))
        #expect(directoryExists(legacyDirectory))
        #expect(userDefaults.integer(
            forKey: StorageMigrationService.completedMigrationVersionKey
        ) == 0)

        service.markCompleted(upThrough: try #require(result.latestCompletedVersion))
        #expect(userDefaults.integer(
            forKey: StorageMigrationService.completedMigrationVersionKey
        ) == StorageMigrationService.MigrationVersion.legacySchoolCrestsEmbeddedData.rawValue)

        let secondResult = try service.migrateIfNeeded(rootURL: rootURL, schools: [school])
        #expect(!secondResult.didChangeModels)
        #expect(secondResult.latestCompletedVersion == nil)
    }

    @Test
    func storageMigrationIgnoresLegacyCrestPathsOutsideRoot() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let outsideURL = rootURL
            .deletingLastPathComponent()
            .appending(path: "\(rootURL.lastPathComponent)-outside.png")
        defer { try? FileManager.default.removeItem(at: outsideURL) }
        try makePNG(label: "Outside", at: outsideURL)

        let suiteName = "StorageMigrationServiceTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let school = School(
            displayName: "Example School",
            filenameValue: "ExampleSchool",
            crestImageRelativePath: "../\(outsideURL.lastPathComponent)"
        )
        let service = StorageMigrationService(userDefaults: userDefaults)

        let result = try service.migrateIfNeeded(rootURL: rootURL, schools: [school])

        #expect(result.didChangeModels)
        #expect(result.latestCompletedVersion == .legacySchoolCrestsEmbeddedData)
        #expect(school.crestImageData == nil)
        #expect(school.crestImageRelativePath == nil)
        #expect(FileManager.default.fileExists(atPath: outsideURL.path))
    }

    @MainActor
    @Test
    func pdfViewportStorePersistsAndClearsPaperPositions() throws {
        let suiteName = "PDFViewerViewportStoreTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let paperID = UUID()
        let questionPosition = PDFViewportPosition(
            pageIndex: 9,
            pointX: 42,
            pointY: 320
        )
        let solutionPosition = PDFViewportPosition(
            pageIndex: 3,
            pointX: 10,
            pointY: 90
        )

        let store = PDFViewerViewportStore(userDefaults: userDefaults)
        store.setPosition(questionPosition, for: paperID, role: .questions)
        store.setPosition(solutionPosition, for: paperID, role: .solutions)
        store.flushPendingPersistence()

        let reloadedStore = PDFViewerViewportStore(userDefaults: userDefaults)
        #expect(reloadedStore.position(for: paperID, role: .questions) == questionPosition)
        #expect(reloadedStore.position(for: paperID, role: .solutions) == solutionPosition)

        reloadedStore.clearPositions(for: paperID)

        let clearedStore = PDFViewerViewportStore(userDefaults: userDefaults)
        #expect(clearedStore.position(for: paperID, role: .questions) == nil)
        #expect(clearedStore.position(for: paperID, role: .solutions) == nil)
    }

    @MainActor
    @Test
    func pdfAnnotationSessionCreatesDeferredSaveRequestForDirtyDocument() async throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let pdfURL = rootURL.appending(path: "annotated.pdf")
        try makePDF(pageCount: 1, at: pdfURL)

        let session = PDFAnnotationSession()
        session.load(url: pdfURL)

        let document = try await loadedDocument(from: session)
        let page = try #require(document.page(at: 0))
        page.addAnnotation(makeInkAnnotation(
            bounds: NSRect(x: 20, y: 20, width: 80, height: 20),
            start: NSPoint(x: 0, y: 10),
            end: NSPoint(x: 70, y: 10)
        ))
        session.markDirty()

        let saveRequest = try #require(session.makeDeferredSaveRequestIfNeeded())
        #expect(session.makeDeferredSaveRequestIfNeeded() == nil)

        try saveRequest.save()

        let reloadedDocument = try #require(PDFDocument(url: pdfURL))
        let reloadedPage = try #require(reloadedDocument.page(at: 0))
        #expect(reloadedPage.annotations.count == 1)
    }

    @MainActor
    private func loadedDocument(from session: PDFAnnotationSession) async throws -> PDFDocument {
        for _ in 0..<20 {
            if let document = session.document {
                return document
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        return try #require(session.document)
    }

    @Test
    func pdfPageSubsetLoaderCopiesPagesFromSourceDocument() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let pdfURL = rootURL.appending(path: "combined.pdf")
        try makePDF(pageCount: 5, at: pdfURL)
        let sourceDocument = try #require(PDFDocument(url: pdfURL))

        let questionDocument = try #require(loadPDFDocument(
            from: sourceDocument,
            selection: .questions(before: 4)
        ))
        let solutionDocument = try #require(loadPDFDocument(
            from: sourceDocument,
            selection: .solutions(from: 4)
        ))

        #expect(sourceDocument.pageCount == 5)
        #expect(questionDocument.pageCount == 3)
        #expect(solutionDocument.pageCount == 2)
        #expect(questionDocument.page(at: 0) !== sourceDocument.page(at: 0))
        #expect(solutionDocument.page(at: 0) !== sourceDocument.page(at: 3))
    }

    @Test
    func preparesAndRenamesSubjectFolders() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let subject = Subject(displayName: "Maths Advanced", filenameValue: "MathsAdvanced")
        let store = LocalFileStore(rootURL: rootURL)
        try store.prepareFolderStructure()
        try store.prepareSubjectFolders(subject)
        try store.renameSubjectFolders(from: "MathsAdvanced", to: "MathsExtension")

        #expect(!directoryExists(rootURL.appending(path: "Papers/MathsAdvanced")))
        #expect(directoryExists(rootURL.appending(path: "Papers/MathsExtension")))
        #expect(directoryExists(
            rootURL.appending(path: "Flagged Questions/MathsExtension/Mistakes")
        ))
        #expect(directoryExists(
            rootURL.appending(path: "Flagged Questions/MathsExtension/Unlearned Content")
        ))
    }

    @Test
    func mergesSeparatePDFsIntoOneStoredPaper() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let sourceURL = rootURL.appending(path: "Sources", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: sourceURL,
            withIntermediateDirectories: true
        )
        let questionsURL = sourceURL.appending(path: "questions.pdf")
        let solutionsURL = sourceURL.appending(path: "solutions.pdf")
        try makePDF(pageCount: 2, at: questionsURL)
        try makePDF(pageCount: 3, at: solutionsURL)

        let subject = Subject(displayName: "Maths Advanced", filenameValue: "MathsAdvanced")
        let school = School(displayName: "Example School", filenameValue: "ExampleSchool")
        let files = try PaperImportService(rootURL: rootURL).importPaper(
            PaperImportRequest(
                subject: subject,
                school: school,
                year: "2025",
                mode: .separate,
                questionPDFURL: questionsURL,
                solutionsPDFURL: solutionsURL
            )
        )

        #expect(
            files.combinedRelativePath ==
                "Papers/MathsAdvanced/ExampleSchool/MathsAdvanced_ExampleSchool_2025.pdf"
        )
        #expect(PDFDocument(url: rootURL.appending(path: files.combinedRelativePath))?.pageCount == 5)
    }

    @Test
    func discardsImportedFilesAfterMetadataFailure() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let questionsURL = rootURL.appending(path: "questions.pdf")
        let solutionsURL = rootURL.appending(path: "solutions.pdf")
        try makePDF(pageCount: 1, at: questionsURL)
        try makePDF(pageCount: 1, at: solutionsURL)

        let subject = Subject(displayName: "Physics", filenameValue: "Physics")
        let school = School(displayName: "Example School", filenameValue: "ExampleSchool")
        let service = PaperImportService(rootURL: rootURL)
        let files = try service.importPaper(
            PaperImportRequest(
                subject: subject,
                school: school,
                year: "2025",
                mode: .separate,
                questionPDFURL: questionsURL,
                solutionsPDFURL: solutionsURL
            )
        )

        service.discardImportedFiles(files)

        #expect(!FileManager.default.fileExists(
            atPath: rootURL.appending(path: files.combinedRelativePath).path
        ))
        let schoolDirectory = rootURL.appending(
            path: "Papers/Physics/ExampleSchool",
            directoryHint: .isDirectory
        )
        #expect(!directoryExists(schoolDirectory))
    }

    @Test
    func storesCombinedPDFWithoutSplitting() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let combinedURL = rootURL.appending(path: "combined.pdf")
        try makePDF(pageCount: 5, at: combinedURL)

        let subject = Subject(displayName: "English Advanced", filenameValue: "EnglishAdvanced")
        let school = School(displayName: "Example School", filenameValue: "ExampleSchool")
        let files = try PaperImportService(rootURL: rootURL).importPaper(
            PaperImportRequest(
                subject: subject,
                school: school,
                year: "2024",
                mode: .combined,
                questionPDFURL: combinedURL,
                solutionsPDFURL: nil
            )
        )

        #expect(PDFDocument(url: rootURL.appending(path: files.combinedRelativePath))?.pageCount == 5)
    }

    @Test
    func rejectsDuplicateDestinationWithoutOverwriting() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let questionsURL = rootURL.appending(path: "questions.pdf")
        let solutionsURL = rootURL.appending(path: "solutions.pdf")
        try makePDF(pageCount: 1, at: questionsURL)
        try makePDF(pageCount: 1, at: solutionsURL)

        let subject = Subject(displayName: "Chemistry", filenameValue: "Chemistry")
        let school = School(displayName: "Example School", filenameValue: "ExampleSchool")
        let request = PaperImportRequest(
            subject: subject,
            school: school,
            year: "2025",
            mode: .separate,
            questionPDFURL: questionsURL,
            solutionsPDFURL: solutionsURL
        )
        _ = try PaperImportService(rootURL: rootURL).importPaper(request)

        #expect(throws: PaperImportService.ImportError.self) {
            _ = try PaperImportService(rootURL: rootURL).importPaper(request)
        }
    }

    @Test
    func deletingPaperRemovesOnlyItsFiles() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let paperDirectory = rootURL.appending(
            path: "Papers/MathsAdvanced/ExampleSchool",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: paperDirectory,
            withIntermediateDirectories: true
        )
        let questionPath = "Papers/MathsAdvanced/ExampleSchool/questions.pdf"
        let solutionsPath = "Papers/MathsAdvanced/ExampleSchool/solutions.pdf"
        try Data("question".utf8).write(to: rootURL.appending(path: questionPath))
        try Data("solution".utf8).write(to: rootURL.appending(path: solutionsPath))

        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: questionPath,
            solutionsPDFRelativePath: solutionsPath
        )
        let transaction = try LocalFileStore(rootURL: rootURL).stageDeletion(
            for: paper,
            flaggedQuestions: []
        )

        #expect(!FileManager.default.fileExists(atPath: rootURL.appending(path: questionPath).path))
        #expect(!FileManager.default.fileExists(atPath: rootURL.appending(path: solutionsPath).path))
        try transaction.commit()
        #expect(directoryExists(rootURL.appending(path: "Papers/MathsAdvanced")))
    }

    @Test
    func deletingPaperAlsoStagesCombinedPDFPath() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let paperDirectory = rootURL.appending(
            path: "Papers/MathsAdvanced/ExampleSchool",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: paperDirectory,
            withIntermediateDirectories: true
        )
        let questionPath = "Papers/MathsAdvanced/ExampleSchool/questions.pdf"
        let solutionsPath = "Papers/MathsAdvanced/ExampleSchool/solutions.pdf"
        let combinedPath = "Papers/MathsAdvanced/ExampleSchool/combined.pdf"
        try Data("question".utf8).write(to: rootURL.appending(path: questionPath))
        try Data("solution".utf8).write(to: rootURL.appending(path: solutionsPath))
        try Data("combined".utf8).write(to: rootURL.appending(path: combinedPath))

        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: questionPath,
            solutionsPDFRelativePath: solutionsPath,
            combinedPDFRelativePath: combinedPath
        )
        let transaction = try LocalFileStore(rootURL: rootURL).stageDeletion(
            for: paper,
            flaggedQuestions: []
        )

        #expect(!FileManager.default.fileExists(atPath: rootURL.appending(path: questionPath).path))
        #expect(!FileManager.default.fileExists(atPath: rootURL.appending(path: solutionsPath).path))
        #expect(!FileManager.default.fileExists(atPath: rootURL.appending(path: combinedPath).path))

        try transaction.rollback()
        #expect(try Data(contentsOf: rootURL.appending(path: combinedPath)) == Data("combined".utf8))
    }

    @Test
    func stagedDeletionCanRestoreFilesAfterMetadataFailure() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let relativePath = "Papers/Physics/ExampleSchool/paper.pdf"
        let fileURL = rootURL.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("paper".utf8).write(to: fileURL)
        let paper = Paper(
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionPDFRelativePath: relativePath,
            solutionsPDFRelativePath: relativePath
        )

        let transaction = try LocalFileStore(rootURL: rootURL).stageDeletion(
            for: paper,
            flaggedQuestions: []
        )
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))

        try transaction.rollback()
        #expect(try Data(contentsOf: fileURL) == Data("paper".utf8))
    }

    @Test
    func capturesAndStitchesFullWidthPDFSections() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let pdfURL = rootURL.appending(path: "capture.pdf")
        try makePDF(pageCount: 3, at: pdfURL)
        let document = try #require(PDFDocument(url: pdfURL))
        let data = try FlaggedQuestionCaptureService(rootURL: rootURL).capturePNG(
            from: document,
            range: PDFCaptureRange(
                startPage: 0,
                endPage: 2,
                topBoundary: 0.25,
                bottomBoundary: 0.75
            ),
            targetWidth: 400
        )
        let image = try #require(NSImage(data: data))

        #expect(image.size.width == 400)
        #expect(image.size.height > 900)
    }

    @Test
    func capturesFromBottomOfOnePageToTopOfNextPage() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let pdfURL = rootURL.appending(path: "cross-page-capture.pdf")
        try makePDF(pageCount: 2, at: pdfURL)
        let document = try #require(PDFDocument(url: pdfURL))
        let data = try FlaggedQuestionCaptureService(rootURL: rootURL).capturePNG(
            from: document,
            range: PDFCaptureRange(
                startPage: 0,
                endPage: 1,
                topBoundary: 0.8,
                bottomBoundary: 0.2
            ),
            targetWidth: 400
        )
        let image = try #require(NSImage(data: data))

        #expect(image.size.width == 400)
        #expect(image.size.height > 200)
        #expect(image.size.height < 400)
    }

    @Test
    func savesDuplicateFlaggedQuestionsWithoutOverwriting() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let service = FlaggedQuestionCaptureService(rootURL: rootURL)
        let subject = Subject(displayName: "Maths Advanced", filenameValue: "MathsAdvanced")
        let school = School(displayName: "Example School", filenameValue: "ExampleSchool")
        let first = try service.saveImages(
            questionPNG: Data("question-one".utf8),
            solutionPNG: Data("solution-one".utf8),
            subject: subject,
            school: school,
            year: "2025",
            questionNumber: "14a",
            category: .mistake
        )
        let second = try service.saveImages(
            questionPNG: Data("question-two".utf8),
            solutionPNG: Data("solution-two".utf8),
            subject: subject,
            school: school,
            year: "2025",
            questionNumber: "Q14a",
            category: .mistake
        )

        #expect(first.questionRelativePath.hasSuffix("_Q14a.png"))
        #expect(first.solutionRelativePath?.hasSuffix("_Q14a_sol.png") == true)
        #expect(second.questionRelativePath.hasSuffix("_Q14a_2.png"))
        #expect(second.solutionRelativePath?.hasSuffix("_Q14a_2_sol.png") == true)
        #expect(first.questionRelativePath.contains("/Mistakes/2025/"))
        #expect(
            try Data(contentsOf: rootURL.appending(path: first.questionRelativePath)) ==
                Data("question-one".utf8)
        )
    }

    @Test
    func savingFlaggedQuestionAvoidsExistingSolutionFilename() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let service = FlaggedQuestionCaptureService(rootURL: rootURL)
        let subject = Subject(displayName: "Maths Advanced", filenameValue: "MathsAdvanced")
        let school = School(displayName: "Example School", filenameValue: "ExampleSchool")
        let directoryPath = "Flagged Questions/MathsAdvanced/Mistakes/2025"
        let directoryURL = rootURL.appending(path: directoryPath, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let orphanSolutionURL = directoryURL.appending(
            path: "MathsAdvanced_ExampleSchool_2025_Q14a_sol.png"
        )
        try Data("orphan-solution".utf8).write(to: orphanSolutionURL)

        let saved = try service.saveImages(
            questionPNG: Data("question".utf8),
            solutionPNG: Data("solution".utf8),
            subject: subject,
            school: school,
            year: "2025",
            questionNumber: "14a",
            category: .mistake
        )

        #expect(saved.questionRelativePath.hasSuffix("_Q14a_2.png"))
        #expect(saved.solutionRelativePath?.hasSuffix("_Q14a_2_sol.png") == true)
        #expect(try Data(contentsOf: orphanSolutionURL) == Data("orphan-solution".utf8))
    }

    @Test
    func deletingFlaggedQuestionImagesRejectsEscapingPaths() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let outsideURL = rootURL
            .deletingLastPathComponent()
            .appending(path: "\(rootURL.lastPathComponent)-outside.png")
        defer { try? FileManager.default.removeItem(at: outsideURL) }
        try Data("outside".utf8).write(to: outsideURL)

        let question = FlaggedQuestion(
            paperID: UUID(),
            subjectID: UUID(),
            schoolID: UUID(),
            year: "2025",
            questionNumber: "1",
            category: .mistake,
            questionImageRelativePath: "../\(outsideURL.lastPathComponent)"
        )

        #expect(throws: StoredFilePath.ValidationError.parentDirectoryComponent) {
            try FlaggedQuestionCaptureService(rootURL: rootURL).deleteImages(for: question)
        }
        #expect(try Data(contentsOf: outsideURL) == Data("outside".utf8))
    }

    @Test
    @MainActor
    func flaggedQuestionSaveServiceSavesModelAndImages() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let container = try ModelContainer(
            for: FlaggedQuestion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let questionURL = rootURL.appending(path: "paper.pdf")
        try makePDF(pageCount: 1, at: questionURL)
        let document = try #require(PDFDocument(url: questionURL))
        let subject = Subject(displayName: "Maths Advanced", filenameValue: "MathsAdvanced")
        let school = School(displayName: "Example School", filenameValue: "ExampleSchool")
        let paper = Paper(
            subjectID: subject.id,
            schoolID: school.id,
            year: "2025",
            questionPDFRelativePath: "paper.pdf",
            solutionsPDFRelativePath: "paper.pdf"
        )
        let request = FlaggedQuestionSaveRequest(
            paper: paper,
            subject: subject,
            school: school,
            questionDocument: document,
            questionRange: PDFCaptureRange(
                startPage: 0,
                endPage: 0,
                topBoundary: 0,
                bottomBoundary: 1
            ),
            solutionDocument: nil,
            solutionRange: nil,
            questionNumber: " 12a ",
            category: .unlearnedContent,
            studyStatus: .needsReview,
            priority: .high,
            marksAvailable: 5,
            topic: "Calculus",
            studyNotes: "  revisit bounds  ",
            nextReviewAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let question = try FlaggedQuestionSaveService(rootURL: rootURL).save(
            request,
            modelContext: container.mainContext
        )
        let savedQuestions = try container.mainContext.fetch(FetchDescriptor<FlaggedQuestion>())

        #expect(question.paperID == paper.id)
        #expect(question.subjectID == subject.id)
        #expect(question.schoolID == school.id)
        #expect(question.year == "2025")
        #expect(question.questionNumber == "12a")
        #expect(question.category == .unlearnedContent)
        #expect(question.studyStatus == .needsReview)
        #expect(question.priority == .high)
        #expect(question.marksAvailable == 5)
        #expect(question.topic == "Calculus")
        #expect(question.studyNotes == "revisit bounds")
        #expect(question.nextReviewAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(question.questionImageRelativePath.contains("/Unlearned Content/2025/"))
        #expect(FileManager.default.fileExists(
            atPath: rootURL.appending(path: question.questionImageRelativePath).path
        ))
        #expect(question.solutionImageRelativePath == nil)
        #expect(savedQuestions.map(\.id) == [question.id])
    }

    @Test
    @MainActor
    func flaggedQuestionSaveServiceRemovesImagesAfterPersistenceFailure() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let container = try ModelContainer(
            for: FlaggedQuestion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let questionURL = rootURL.appending(path: "paper.pdf")
        try makePDF(pageCount: 1, at: questionURL)
        let document = try #require(PDFDocument(url: questionURL))
        let subject = Subject(displayName: "Maths Advanced", filenameValue: "MathsAdvanced")
        let school = School(displayName: "Example School", filenameValue: "ExampleSchool")
        let paper = Paper(
            subjectID: subject.id,
            schoolID: school.id,
            year: "2025",
            questionPDFRelativePath: "paper.pdf",
            solutionsPDFRelativePath: "paper.pdf"
        )
        let request = FlaggedQuestionSaveRequest(
            paper: paper,
            subject: subject,
            school: school,
            questionDocument: document,
            questionRange: PDFCaptureRange(
                startPage: 0,
                endPage: 0,
                topBoundary: 0,
                bottomBoundary: 1
            ),
            solutionDocument: document,
            solutionRange: PDFCaptureRange(
                startPage: 0,
                endPage: 0,
                topBoundary: 0,
                bottomBoundary: 1
            ),
            questionNumber: "12a",
            category: .mistake
        )
        var createdQuestion: FlaggedQuestion?
        let service = FlaggedQuestionSaveService(rootURL: rootURL) {
            flaggedQuestion,
            modelContext in
            createdQuestion = flaggedQuestion
            modelContext.insert(flaggedQuestion)
            throw FlaggedQuestionSaveServiceTestError.persistenceFailed
        }

        #expect(throws: FlaggedQuestionSaveServiceTestError.self) {
            _ = try service.save(request, modelContext: container.mainContext)
        }

        let question = try #require(createdQuestion)
        #expect(!FileManager.default.fileExists(
            atPath: rootURL.appending(path: question.questionImageRelativePath).path
        ))
        if let solutionImageRelativePath = question.solutionImageRelativePath {
            #expect(!FileManager.default.fileExists(
                atPath: rootURL.appending(path: solutionImageRelativePath).path
            ))
        }
        let savedQuestions = try container.mainContext.fetch(FetchDescriptor<FlaggedQuestion>())
        #expect(savedQuestions.isEmpty)
    }

    @Test
    func exportsRevisionBookletWithQuestionAndSolutionPages() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let questionOneURL = rootURL.appending(path: "question-one.png")
        let solutionOneURL = rootURL.appending(path: "solution-one.png")
        let questionTwoURL = rootURL.appending(path: "question-two.png")
        try makePNG(label: "Question 1", at: questionOneURL)
        try makePNG(label: "Solution 1", at: solutionOneURL)
        try makePNG(label: "Question 2", at: questionTwoURL)

        let destinationURL = rootURL.appending(path: "booklet.pdf")
        try RevisionBookletService().export(
            subjectName: "Maths Advanced",
            entries: [
                RevisionBookletEntry(
                    schoolName: "Example School",
                    year: "2025",
                    questionNumber: "14a",
                    category: .mistake,
                    questionImageURL: questionOneURL,
                    solutionImageURL: solutionOneURL
                ),
                RevisionBookletEntry(
                    schoolName: "Other School",
                    year: "2024",
                    questionNumber: "7",
                    category: .unlearnedContent,
                    questionImageURL: questionTwoURL,
                    solutionImageURL: nil
                )
            ],
            generatedAt: Date(timeIntervalSince1970: 0),
            to: destinationURL
        )

        let booklet = try #require(PDFDocument(url: destinationURL))
        #expect(booklet.pageCount == 5)
        #expect(booklet.page(at: 0)?.string?.contains("Revision Booklet") == true)
        #expect(booklet.page(at: 4)?.string?.contains("No solution provided") == true)
    }

    @Test
    func exportsRevisionBookletWithAnswersAtEndAndWorkingPages() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let questionOneURL = rootURL.appending(path: "question-one.png")
        let solutionOneURL = rootURL.appending(path: "solution-one.png")
        let questionTwoURL = rootURL.appending(path: "question-two.png")
        try makePNG(label: "Question 1", at: questionOneURL)
        try makePNG(label: "Solution 1", at: solutionOneURL)
        try makePNG(label: "Question 2", at: questionTwoURL)

        let destinationURL = rootURL.appending(path: "booklet-answers-end.pdf")
        try RevisionBookletService().export(
            subjectName: "Maths Advanced",
            entries: [
                RevisionBookletEntry(
                    schoolName: "Example School",
                    year: "2025",
                    questionNumber: "14a",
                    category: .mistake,
                    status: .needsReview,
                    priority: .high,
                    topic: "Calculus",
                    marksAvailable: 5,
                    questionImageURL: questionOneURL,
                    solutionImageURL: solutionOneURL
                ),
                RevisionBookletEntry(
                    schoolName: "Other School",
                    year: "2024",
                    questionNumber: "7",
                    category: .unlearnedContent,
                    questionImageURL: questionTwoURL,
                    solutionImageURL: nil
                )
            ],
            answerPlacement: .answersAtEnd,
            workingPageCount: 1,
            generatedAt: Date(timeIntervalSince1970: 0),
            to: destinationURL
        )

        let booklet = try #require(PDFDocument(url: destinationURL))
        #expect(booklet.pageCount == 7)
        #expect(booklet.page(at: 2)?.string?.contains("Working") == true)
        #expect(booklet.page(at: 5)?.string?.contains("Solution") == true)
        #expect(booklet.page(at: 6)?.string?.contains("No solution provided") == true)
    }

    @Test
    func inkEraserHitTestingMatchesLocalAnnotationPathCoordinates() {
        let annotation = makeInkAnnotation(
            bounds: NSRect(x: 100, y: 100, width: 60, height: 40),
            start: NSPoint(x: 0, y: 20),
            end: NSPoint(x: 50, y: 20)
        )

        #expect(inkAnnotation(annotation, isNear: NSPoint(x: 125, y: 120), radius: 6))
        #expect(!inkAnnotation(annotation, isNear: NSPoint(x: 125, y: 150), radius: 6))
    }

    @Test
    func inkEraserHitTestingMatchesPageAnnotationPathCoordinates() {
        let annotation = makeInkAnnotation(
            bounds: NSRect(x: 100, y: 100, width: 60, height: 40),
            start: NSPoint(x: 100, y: 120),
            end: NSPoint(x: 150, y: 120)
        )

        #expect(inkAnnotation(annotation, isNear: NSPoint(x: 125, y: 120), radius: 6))
        #expect(!inkAnnotation(annotation, isNear: NSPoint(x: 125, y: 150), radius: 6))
    }

    @Test
    func inkEraserHitTestingMatchesSweptSegmentBetweenMousePoints() {
        let annotation = makeInkAnnotation(
            bounds: NSRect(x: 100, y: 100, width: 60, height: 40),
            start: NSPoint(x: 0, y: 20),
            end: NSPoint(x: 50, y: 20)
        )

        let startPoint = NSPoint(x: 125, y: 70)
        let endPoint = NSPoint(x: 125, y: 170)

        #expect(!inkAnnotation(annotation, isNear: startPoint, radius: 6))
        #expect(!inkAnnotation(annotation, isNear: endPoint, radius: 6))
        #expect(inkAnnotation(annotation, intersectsSegmentFrom: startPoint, to: endPoint, radius: 6))
    }

    @Test
    @MainActor
    func eraserRemovesPDFKitInkAnnotation() throws {
        let document = PDFDocument()
        let image = NSImage(size: NSSize(width: 200, height: 200))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 200, height: 200).fill()
        image.unlockFocus()

        let page = try #require(PDFPage(image: image))
        let annotation = makeInkAnnotation(
            bounds: NSRect(x: 100, y: 100, width: 60, height: 40),
            start: NSPoint(x: 0, y: 20),
            end: NSPoint(x: 50, y: 20)
        )
        page.addAnnotation(annotation)
        document.insert(page, at: 0)

        let pdfView = SelectablePDFView()
        pdfView.document = document
        pdfView.sourceDocument = document
        pdfView.pageSelection = .all
        var didChangeAnnotations = false
        pdfView.onAnnotationsChanged = {
            didChangeAnnotations = true
        }

        pdfView.eraseInkAnnotation(onDisplayedPage: page, at: NSPoint(x: 125, y: 120))

        #expect(page.annotations.isEmpty)
        #expect(didChangeAnnotations)
    }

    @Test
    @MainActor
    func eraserRemovesPDFKitInkAnnotationAlongSweptSegment() throws {
        let document = PDFDocument()
        let image = NSImage(size: NSSize(width: 200, height: 200))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 200, height: 200).fill()
        image.unlockFocus()

        let page = try #require(PDFPage(image: image))
        let annotation = makeInkAnnotation(
            bounds: NSRect(x: 100, y: 100, width: 60, height: 40),
            start: NSPoint(x: 0, y: 20),
            end: NSPoint(x: 50, y: 20)
        )
        page.addAnnotation(annotation)
        document.insert(page, at: 0)

        let pdfView = SelectablePDFView()
        pdfView.document = document
        pdfView.sourceDocument = document
        pdfView.pageSelection = .all
        var didChangeAnnotations = false
        pdfView.onAnnotationsChanged = {
            didChangeAnnotations = true
        }

        pdfView.eraseInkAnnotation(
            onDisplayedPage: page,
            from: NSPoint(x: 125, y: 70),
            to: NSPoint(x: 125, y: 170)
        )

        #expect(page.annotations.isEmpty)
        #expect(didChangeAnnotations)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "TrialPracticeAppTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private func makePDF(pageCount: Int, at url: URL) throws {
        let document = PDFDocument()
        for index in 0..<pageCount {
            let image = NSImage(size: NSSize(width: 200, height: 300))
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 200, height: 300).fill()
            NSString(string: "Page \(index + 1)").draw(at: NSPoint(x: 20, y: 20))
            image.unlockFocus()

            guard let page = PDFPage(image: image) else {
                throw CocoaError(.fileWriteUnknown)
            }
            document.insert(page, at: document.pageCount)
        }
        guard document.write(to: url) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private func makePNG(label: String, at url: URL) throws {
        let image = NSImage(size: NSSize(width: 600, height: 300))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 600, height: 300).fill()
        NSString(string: label).draw(at: NSPoint(x: 30, y: 140))
        image.unlockFocus()

        guard
            let data = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: data),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: url)
    }

    private func makeInkAnnotation(bounds: NSRect, start: NSPoint, end: NSPoint) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        let border = PDFBorder()
        border.lineWidth = 4
        annotation.border = border

        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        annotation.add(path)
        return annotation
    }
}
