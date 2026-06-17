import Foundation
import SwiftData

struct LibraryMutationService {
    let rootURL: URL?
    let modelContext: ModelContext

    init(rootURL: URL? = nil, modelContext: ModelContext) {
        self.rootURL = rootURL
        self.modelContext = modelContext
    }

    func createSubject(
        _ input: String,
        colorHex: String,
        allSubjects: [Subject]
    ) -> String? {
        let displayName = NameNormalizer.displayName(from: input)
        let filenameValue = NameNormalizer.filenameValue(from: displayName)
        guard !displayName.isEmpty else { return "Enter a subject name." }
        guard !filenameValue.isEmpty else {
            return "A subject name must contain at least one letter."
        }
        guard !allSubjects.contains(where: {
            $0.displayName.localizedCaseInsensitiveCompare(displayName) == .orderedSame ||
            $0.filenameValue.localizedCaseInsensitiveCompare(filenameValue) == .orderedSame
        }) else {
            return "A subject with this name already exists."
        }
        guard let rootURL else {
            return "The app storage folder is unavailable."
        }

        let subject = Subject(
            displayName: displayName,
            filenameValue: filenameValue,
            colorHex: colorHex
        )
        do {
            try LocalFileStore(rootURL: rootURL).prepareSubjectFolders(subject)
            modelContext.insert(subject)
            try modelContext.save()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func renameSubject(
        _ subject: Subject,
        to input: String,
        colorHex: String,
        allSubjects: [Subject],
        papers: [Paper],
        flaggedQuestions: [FlaggedQuestion]
    ) -> String? {
        let displayName = NameNormalizer.displayName(from: input)
        let filenameValue = NameNormalizer.filenameValue(from: displayName)
        guard !displayName.isEmpty else { return "Enter a subject name." }
        guard !filenameValue.isEmpty else {
            return "A subject name must contain at least one letter."
        }
        guard !allSubjects.contains(where: {
            $0.id != subject.id &&
            (
                $0.displayName.localizedCaseInsensitiveCompare(displayName) == .orderedSame ||
                $0.filenameValue.localizedCaseInsensitiveCompare(filenameValue) == .orderedSame
            )
        }) else {
            return "A subject with this name already exists."
        }
        guard let rootURL else {
            return "The app storage folder is unavailable."
        }

        let oldDisplayName = subject.displayName
        let oldFilename = subject.filenameValue
        let oldColorHex = subject.colorHex
        let affectedPapers = papers.filter { $0.subjectID == subject.id }
        let affectedQuestions = flaggedQuestions.filter { $0.subjectID == subject.id }
        let paperSnapshots = affectedPapers.map {
            (
                $0,
                $0.questionPDFRelativePath,
                $0.solutionsPDFRelativePath,
                $0.combinedPDFRelativePath
            )
        }
        let questionSnapshots = affectedQuestions.map {
            ($0, $0.questionImageRelativePath, $0.solutionImageRelativePath)
        }

        do {
            try LocalFileStore(rootURL: rootURL).renameSubjectFolders(
                from: oldFilename,
                to: filenameValue
            )
            subject.displayName = displayName
            subject.filenameValue = filenameValue
            subject.colorHex = colorHex

            for paper in affectedPapers {
                paper.questionPDFRelativePath = Self.replaceSubjectFolder(
                    in: paper.questionPDFRelativePath,
                    topLevel: "Papers",
                    from: oldFilename,
                    to: filenameValue
                )
                paper.solutionsPDFRelativePath = Self.replaceSubjectFolder(
                    in: paper.solutionsPDFRelativePath,
                    topLevel: "Papers",
                    from: oldFilename,
                    to: filenameValue
                )
                if let path = paper.combinedPDFRelativePath {
                    paper.combinedPDFRelativePath = Self.replaceSubjectFolder(
                        in: path,
                        topLevel: "Papers",
                        from: oldFilename,
                        to: filenameValue
                    )
                }
            }
            for question in affectedQuestions {
                question.questionImageRelativePath = Self.replaceSubjectFolder(
                    in: question.questionImageRelativePath,
                    topLevel: "Flagged Questions",
                    from: oldFilename,
                    to: filenameValue
                )
                if let path = question.solutionImageRelativePath {
                    question.solutionImageRelativePath = Self.replaceSubjectFolder(
                        in: path,
                        topLevel: "Flagged Questions",
                        from: oldFilename,
                        to: filenameValue
                    )
                }
            }
            try modelContext.save()
            return nil
        } catch {
            subject.displayName = oldDisplayName
            subject.filenameValue = oldFilename
            subject.colorHex = oldColorHex
            for snapshot in paperSnapshots {
                snapshot.0.questionPDFRelativePath = snapshot.1
                snapshot.0.solutionsPDFRelativePath = snapshot.2
                snapshot.0.combinedPDFRelativePath = snapshot.3
            }
            for snapshot in questionSnapshots {
                snapshot.0.questionImageRelativePath = snapshot.1
                snapshot.0.solutionImageRelativePath = snapshot.2
            }
            try? LocalFileStore(rootURL: rootURL).renameSubjectFolders(
                from: filenameValue,
                to: oldFilename
            )
            return error.localizedDescription
        }
    }

    func moveSubjectToBin(_ subject: Subject) -> String? {
        subject.deletedAt = .now
        do {
            try modelContext.save()
            return nil
        } catch {
            subject.deletedAt = nil
            return error.localizedDescription
        }
    }

    static func replaceSubjectFolder(
        in relativePath: String,
        topLevel: String,
        from oldFilename: String,
        to newFilename: String
    ) -> String {
        let prefix = "\(topLevel)/\(oldFilename)/"
        guard relativePath.hasPrefix(prefix) else { return relativePath }
        return "\(topLevel)/\(newFilename)/" + relativePath.dropFirst(prefix.count)
    }
}
