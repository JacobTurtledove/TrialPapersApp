import Foundation

struct LocalFileStore {
    struct DeletionTransaction {
        fileprivate let stagingURL: URL
        fileprivate let movedItems: [(original: URL, staged: URL)]

        func commit() throws {
            if FileManager.default.fileExists(atPath: stagingURL.path) {
                try FileManager.default.removeItem(at: stagingURL)
            }
        }

        func rollback() throws {
            let fileManager = FileManager.default
            for item in movedItems.reversed() {
                guard fileManager.fileExists(atPath: item.staged.path) else { continue }
                try fileManager.createDirectory(
                    at: item.original.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if fileManager.fileExists(atPath: item.original.path) {
                    try fileManager.removeItem(at: item.original)
                }
                try fileManager.moveItem(at: item.staged, to: item.original)
            }
            if fileManager.fileExists(atPath: stagingURL.path) {
                try fileManager.removeItem(at: stagingURL)
            }
        }
    }

    enum StoreError: LocalizedError {
        case missingRootFolder
        case destinationAlreadyExists(String)

        var errorDescription: String? {
            switch self {
            case .missingRootFolder:
                "The app data folder is not available."
            case .destinationAlreadyExists(let name):
                "A folder for \(name) already exists."
            }
        }
    }

    let rootURL: URL

    func prepareFolderStructure() throws {
        try createDirectory(relativePath: "Papers")
        try createDirectory(relativePath: "Flagged Questions")
    }

    func verifyWriteAccess() throws {
        let probeURL = rootURL.appending(
            path: ".trial-practice-write-check-\(UUID().uuidString)"
        )
        try Data().write(to: probeURL, options: .atomic)
        try FileManager.default.removeItem(at: probeURL)
    }

    func prepareSubjectFolders(_ subject: Subject) throws {
        try createDirectory(relativePath: "Papers/\(subject.filenameValue)")
        try createDirectory(relativePath: "Flagged Questions/\(subject.filenameValue)/Mistakes")
        try createDirectory(
            relativePath: "Flagged Questions/\(subject.filenameValue)/Unlearned Content"
        )
    }

    func renameSubjectFolders(from oldFilename: String, to newFilename: String) throws {
        guard oldFilename != newFilename else { return }

        let fileManager = FileManager.default
        let paperSource = rootURL.appending(
            path: "Papers/\(oldFilename)",
            directoryHint: .isDirectory
        )
        let paperDestination = rootURL.appending(
            path: "Papers/\(newFilename)",
            directoryHint: .isDirectory
        )
        let questionSource = rootURL.appending(
            path: "Flagged Questions/\(oldFilename)",
            directoryHint: .isDirectory
        )
        let questionDestination = rootURL.appending(
            path: "Flagged Questions/\(newFilename)",
            directoryHint: .isDirectory
        )

        if fileManager.fileExists(atPath: paperDestination.path) ||
            fileManager.fileExists(atPath: questionDestination.path) {
            throw StoreError.destinationAlreadyExists(newFilename)
        }

        var movedPaperFolder = false
        do {
            if fileManager.fileExists(atPath: paperSource.path) {
                try fileManager.moveItem(at: paperSource, to: paperDestination)
                movedPaperFolder = true
            }
            if fileManager.fileExists(atPath: questionSource.path) {
                try fileManager.moveItem(at: questionSource, to: questionDestination)
            }
        } catch {
            if movedPaperFolder,
               !fileManager.fileExists(atPath: paperSource.path),
               fileManager.fileExists(atPath: paperDestination.path) {
                try? fileManager.moveItem(at: paperDestination, to: paperSource)
            }
            throw error
        }
    }

    func stageDeletion(for subject: Subject) throws -> DeletionTransaction {
        let paths = [
            "Papers/\(subject.filenameValue)",
            "Flagged Questions/\(subject.filenameValue)"
        ]
        return try stageDeletion(relativePaths: paths)
    }

    func stageDeletion(
        for paper: Paper,
        flaggedQuestions: [FlaggedQuestion]
    ) throws -> DeletionTransaction {
        var relativePaths = [
            paper.questionPDFRelativePath,
            paper.solutionsPDFRelativePath
        ]
        for question in flaggedQuestions {
            relativePaths.append(question.questionImageRelativePath)
            if let solutionPath = question.solutionImageRelativePath {
                relativePaths.append(solutionPath)
            }
        }
        return try stageDeletion(relativePaths: Array(Set(relativePaths)))
    }

    func stageDeletion(for question: FlaggedQuestion) throws -> DeletionTransaction {
        let paths = [
            question.questionImageRelativePath,
            question.solutionImageRelativePath
        ].compactMap { $0 }
        return try stageDeletion(relativePaths: paths)
    }

    private func stageDeletion(relativePaths: [String]) throws -> DeletionTransaction {
        let fileManager = FileManager.default
        let stagingURL = rootURL.appending(
            path: ".Pending Deletions/\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        var movedItems: [(original: URL, staged: URL)] = []

        do {
            for (index, relativePath) in relativePaths.enumerated() {
                let originalURL = try containedURL(for: relativePath)
                guard fileManager.fileExists(atPath: originalURL.path) else { continue }
                let stagedURL = stagingURL.appending(
                    path: "\(index)-\(originalURL.lastPathComponent)"
                )
                try fileManager.createDirectory(
                    at: stagingURL,
                    withIntermediateDirectories: true
                )
                try fileManager.moveItem(at: originalURL, to: stagedURL)
                movedItems.append((originalURL, stagedURL))
            }
            return DeletionTransaction(
                stagingURL: stagingURL,
                movedItems: movedItems
            )
        } catch {
            let transaction = DeletionTransaction(
                stagingURL: stagingURL,
                movedItems: movedItems
            )
            try? transaction.rollback()
            throw error
        }
    }

    private func containedURL(for relativePath: String) throws -> URL {
        let candidate = rootURL
            .appending(path: relativePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let rootPath = rootURL.standardizedFileURL.resolvingSymlinksInPath().path
        let candidatePath = candidate.path

        guard candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/") else {
            throw CocoaError(.fileReadNoPermission)
        }

        return candidate
    }

    private func createDirectory(relativePath: String) throws {
        let url = rootURL.appending(path: relativePath, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}
