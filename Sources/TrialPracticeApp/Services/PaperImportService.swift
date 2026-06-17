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
    let mark: Double?
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
        do {
            switch request.mode {
            case .separate:
                guard let questionDocument = PDFDocument(url: request.questionPDFURL) else {
                    throw ImportError.unreadablePDF("The question paper")
                }
                guard let solutionsURL = request.solutionsPDFURL else {
                    throw ImportError.missingSolutionsPDF
                }
                guard let solutionsDocument = PDFDocument(url: solutionsURL) else {
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
                guard PDFDocument(url: request.questionPDFURL) != nil else {
                    throw ImportError.unreadablePDF("The combined paper")
                }
                try FileManager.default.copyItem(
                    at: request.questionPDFURL,
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

    private func isContainedInRoot(_ url: URL) -> Bool {
        let rootPath = rootURL.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }
}
