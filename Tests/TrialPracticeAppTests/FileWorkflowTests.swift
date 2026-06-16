import AppKit
import Foundation
import PDFKit
import Testing
@testable import TrialPracticeApp

struct FileWorkflowTests {
    @Test
    func exportsSubjectPapersAsSpecificationCompliantCSV() throws {
        let rows = [
            SubjectPaperCSVRow(
                schoolName: "North Sydney Boys",
                year: "2025",
                mark: 84.5
            ),
            SubjectPaperCSVRow(
                schoolName: "James Ruse, Senior Campus",
                year: "2024",
                mark: nil
            ),
            SubjectPaperCSVRow(
                schoolName: "A \"Quoted\" School",
                year: "2023",
                mark: 79
            )
        ]

        let data = try SubjectPaperCSVService().csvData(rows: rows)
        let csv = try #require(String(data: data, encoding: .utf8))

        #expect(csv.hasPrefix("School,Year,Mark\n"))
        #expect(csv.contains("\"James Ruse, Senior Campus\",2024,\n"))
        #expect(csv.contains("\"A \"\"Quoted\"\" School\",2023,79.0\n"))
        #expect(csv.contains("North Sydney Boys,2025,84.5\n"))
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
                mark: 80,
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
                mark: nil,
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
                mark: nil,
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
            mark: nil,
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
}
