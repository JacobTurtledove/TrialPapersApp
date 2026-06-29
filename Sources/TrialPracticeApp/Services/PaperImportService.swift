import Foundation
import PDFKit

enum PaperImportMode: String, CaseIterable, Identifiable {
    case separate = "Separate PDFs"
    case combined = "Combined PDF"

    var id: String { rawValue }
}

struct PaperImportRequest {
    let subject: Subject
    let school: School
    let year: String
    let mode: PaperImportMode
    let questionPDFURL: URL
    let solutionsPDFURL: URL?
}

struct ImportedPaperFiles {
    let combinedRelativePath: String
}

struct PaperImportService {
    enum ImportError: LocalizedError {
        case unreadablePDF(String)
        case missingSolutionsPDF
        case destinationAlreadyExists

        var errorDescription: String? {
            switch self {
            case .unreadablePDF(let name):
                "\(name) could not be opened as a PDF."
            case .missingSolutionsPDF:
                "Select a solutions PDF."
            case .destinationAlreadyExists:
                "Files for this paper already exist in the data folder."
            }
        }
    }

    let rootURL: URL

    func importPaper(_ request: PaperImportRequest) throws -> ImportedPaperFiles {
        let relativeDirectory = [
            "Papers",
            request.subject.filenameValue,
            request.school.filenameValue
        ].joined(separator: "/")
        let directory = rootURL.appending(path: relativeDirectory, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let combinedName = PaperFileNames.combined(
            subject: request.subject,
            school: request.school,
            year: request.year
        )
        let combinedDestination = directory.appending(path: combinedName)

        guard !FileManager.default.fileExists(atPath: combinedDestination.path) else {
            throw ImportError.destinationAlreadyExists
        }

        var createdURLs: [URL] = []
        var temporaryDirectories: [URL] = []
        defer {
            for url in temporaryDirectories {
                try? FileManager.default.removeItem(at: url)
            }
        }

        do {
            switch request.mode {
            case .separate:
                let localQuestionURL = try readableLocalCopy(
                    of: request.questionPDFURL,
                    filename: "questions.pdf"
                )
                temporaryDirectories.append(localQuestionURL.deletingLastPathComponent())
                guard let questionDocument = PDFDocument(url: localQuestionURL) else {
                    throw ImportError.unreadablePDF("The question paper")
                }
                guard let solutionsURL = request.solutionsPDFURL else {
                    throw ImportError.missingSolutionsPDF
                }
                let localSolutionsURL = try readableLocalCopy(
                    of: solutionsURL,
                    filename: "solutions.pdf"
                )
                temporaryDirectories.append(localSolutionsURL.deletingLastPathComponent())
                guard let solutionsDocument = PDFDocument(url: localSolutionsURL) else {
                    throw ImportError.unreadablePDF("The solutions paper")
                }
                let output = PDFDocument()
                try appendPages(from: questionDocument, to: output)
                try appendPages(from: solutionsDocument, to: output)
                guard output.write(to: combinedDestination) else {
                    throw ImportError.unreadablePDF("The combined paper")
                }
                createdURLs.append(combinedDestination)

            case .combined:
                let localCombinedURL = try readableLocalCopy(
                    of: request.questionPDFURL,
                    filename: "combined.pdf"
                )
                temporaryDirectories.append(localCombinedURL.deletingLastPathComponent())
                guard PDFDocument(url: localCombinedURL) != nil else {
                    throw ImportError.unreadablePDF("The combined paper")
                }
                try FileManager.default.copyItem(
                    at: localCombinedURL,
                    to: combinedDestination
                )
                createdURLs.append(combinedDestination)
            }

            return ImportedPaperFiles(
                combinedRelativePath: "\(relativeDirectory)/\(combinedName)"
            )
        } catch {
            for url in createdURLs {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
    }

    func discardImportedFiles(_ files: ImportedPaperFiles) {
        let fileManager = FileManager.default
        let relativePaths = [files.combinedRelativePath]

        for relativePath in relativePaths {
            let fileURL = rootURL.appending(path: relativePath).standardizedFileURL
            guard isContainedInRoot(fileURL) else { continue }
            try? fileManager.removeItem(at: fileURL)
        }

        guard let firstPath = relativePaths.first else { return }
        let directoryPath = (firstPath as NSString).deletingLastPathComponent
        let directoryURL = rootURL.appending(path: directoryPath).standardizedFileURL
        guard
            isContainedInRoot(directoryURL),
            let contents = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            ),
            contents.isEmpty
        else {
            return
        }
        try? fileManager.removeItem(at: directoryURL)
    }

    private func appendPages(from source: PDFDocument, to output: PDFDocument) throws {
        for index in 0..<source.pageCount {
            guard let page = source.page(at: index) else {
                throw ImportError.unreadablePDF("The source paper")
            }
            output.insert(page, at: output.pageCount)
        }
    }

    private func readableLocalCopy(of sourceURL: URL, filename: String) throws -> URL {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory.appending(
            path: "TrialPracticeAppImport-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let temporaryURL = temporaryDirectory.appending(path: filename)

        do {
            try fileManager.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true
            )
            try coordinatedCopy(from: sourceURL, to: temporaryURL)
            return temporaryURL
        } catch {
            try? fileManager.removeItem(at: temporaryDirectory)
            throw error
        }
    }

    private func coordinatedCopy(from sourceURL: URL, to destinationURL: URL) throws {
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var copyResult: Result<Void, Error>?

        coordinator.coordinate(
            readingItemAt: sourceURL,
            options: [],
            error: &coordinationError
        ) { readableURL in
            do {
                try FileManager.default.copyItem(at: readableURL, to: destinationURL)
                copyResult = .success(())
            } catch {
                copyResult = .failure(error)
            }
        }

        if let copyResult {
            try copyResult.get()
        } else if let coordinationError {
            throw coordinationError
        } else {
            throw CocoaError(.fileReadUnknown)
        }
    }

    private func isContainedInRoot(_ url: URL) -> Bool {
        let rootPath = rootURL.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }
}
