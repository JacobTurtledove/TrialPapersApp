import Foundation

struct LibraryExportService {
    enum ExportError: LocalizedError {
        case noFiles
        case missingSource(String)

        var errorDescription: String? {
            switch self {
            case .noFiles:
                "There are no files to export."
            case .missingSource(let path):
                "The stored file could not be found: \(path)"
            }
        }
    }

    let rootURL: URL

    func exportLibrary(
        subjects: [Subject],
        papers: [Paper],
        flaggedQuestions: [FlaggedQuestion],
        to parentURL: URL
    ) throws -> URL {
        let destinationURL = try uniqueDirectory(
            named: "Trial Practice Library",
            in: parentURL
        )
        try export(
            relativePaths: activePaths(
                subjects: subjects,
                papers: papers,
                flaggedQuestions: flaggedQuestions
            ),
            to: destinationURL
        )
        return destinationURL
    }

    func exportSubject(
        _ subject: Subject,
        papers: [Paper],
        flaggedQuestions: [FlaggedQuestion],
        to parentURL: URL
    ) throws -> URL {
        let destinationURL = try uniqueDirectory(
            named: subject.filenameValue,
            in: parentURL
        )
        try export(
            relativePaths: activePaths(
                subjects: [subject],
                papers: papers.filter { $0.subjectID == subject.id },
                flaggedQuestions: flaggedQuestions.filter { $0.subjectID == subject.id }
            ),
            to: destinationURL
        )
        return destinationURL
    }

    func exportSchoolFolder(
        subject: Subject,
        school: School,
        papers: [Paper],
        flaggedQuestions: [FlaggedQuestion],
        to parentURL: URL
    ) throws -> URL {
        let destinationURL = try uniqueDirectory(
            named: "\(subject.filenameValue)_\(school.filenameValue)",
            in: parentURL
        )
        try export(
            relativePaths: activePaths(
                subjects: [subject],
                papers: papers.filter {
                    $0.subjectID == subject.id && $0.schoolID == school.id
                },
                flaggedQuestions: flaggedQuestions.filter {
                    $0.subjectID == subject.id && $0.schoolID == school.id
                }
            ),
            to: destinationURL
        )
        return destinationURL
    }

    func exportPaper(_ paper: Paper, to destinationURL: URL) throws -> URL {
        let relativePath = paper.combinedPDFRelativePath ?? paper.questionPDFRelativePath
        try copyStoredFile(relativePath: relativePath, to: destinationURL)
        return destinationURL
    }

    func exportFlaggedQuestion(
        _ question: FlaggedQuestion,
        subject: Subject?,
        school: School?,
        to parentURL: URL
    ) throws -> URL {
        let subjectName = subject?.filenameValue ?? "UnknownSubject"
        let schoolName = school?.filenameValue ?? "UnknownSchool"
        let destinationURL = try uniqueDirectory(
            named: "\(subjectName)_\(schoolName)_\(question.year)_Q\(question.questionNumber)",
            in: parentURL
        )
        try export(
            relativePaths: question.imageRelativePaths,
            to: destinationURL
        )
        return destinationURL
    }

    func activePaths(
        subjects: [Subject],
        papers: [Paper],
        flaggedQuestions: [FlaggedQuestion]
    ) -> [String] {
        let activeSubjectIDs = Set(subjects.filter { $0.deletedAt == nil }.map(\.id))
        let activePapers = papers.filter {
            $0.deletedAt == nil && activeSubjectIDs.contains($0.subjectID)
        }
        let activePaperIDs = Set(activePapers.map(\.id))

        var paths: [String] = []
        for paper in activePapers {
            paths.append(contentsOf: paper.pdfRelativePaths)
        }
        for question in flaggedQuestions where
            question.deletedAt == nil &&
            activeSubjectIDs.contains(question.subjectID) &&
            activePaperIDs.contains(question.paperID) {
            paths.append(contentsOf: question.imageRelativePaths)
        }

        return Array(Set(paths)).sorted()
    }

    private func export(relativePaths: [String], to destinationURL: URL) throws {
        guard !relativePaths.isEmpty else { throw ExportError.noFiles }
        for relativePath in relativePaths {
            let storedPath = try StoredFilePath(relativePath)
            let destination = destinationURL.appending(path: storedPath.rawValue)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try copyStoredFile(storedPath: storedPath, to: destination)
        }
    }

    private func copyStoredFile(relativePath: String, to destinationURL: URL) throws {
        try copyStoredFile(storedPath: StoredFilePath(relativePath), to: destinationURL)
    }

    private func copyStoredFile(storedPath: StoredFilePath, to destinationURL: URL) throws {
        let sourceURL = try containedURL(for: storedPath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ExportError.missingSource(storedPath.rawValue)
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    private func containedURL(for storedPath: StoredFilePath) throws -> URL {
        try storedPath.url(relativeTo: rootURL)
    }

    private func uniqueDirectory(named name: String, in parentURL: URL) throws -> URL {
        let baseName = safeFolderName(name)
        var candidate = parentURL.appending(path: baseName, directoryHint: .isDirectory)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = parentURL.appending(
                path: "\(baseName) \(index)",
                directoryHint: .isDirectory
            )
            index += 1
        }
        try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
        return candidate
    }

    private func safeFolderName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = name
            .components(separatedBy: invalid)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Export" : cleaned
    }
}

extension Paper {
    var pdfRelativePaths: [String] {
        Array(Set([
            questionPDFRelativePath,
            solutionsPDFRelativePath,
            combinedPDFRelativePath
        ].compactMap { $0 }))
    }
}

extension FlaggedQuestion {
    var imageRelativePaths: [String] {
        [
            questionImageRelativePath,
            solutionImageRelativePath
        ].compactMap { $0 }
    }
}
