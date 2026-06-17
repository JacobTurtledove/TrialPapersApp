import Foundation
import SwiftData

struct BinDeletionService {
    let rootURL: URL?
    let modelContext: ModelContext
    private let save: () throws -> Void

    init(
        rootURL: URL?,
        modelContext: ModelContext,
        save: (() throws -> Void)? = nil
    ) {
        self.rootURL = rootURL
        self.modelContext = modelContext
        self.save = save ?? { try modelContext.save() }
    }

    func permanentlyDelete(
        _ subject: Subject,
        papers: [Paper],
        flaggedQuestions: [FlaggedQuestion],
        importRecords: [THSCImportRecord]
    ) throws {
        guard let rootURL else { return }

        let subjectPapers = papers.filter { $0.subjectID == subject.id }
        let subjectQuestions = flaggedQuestions.filter { $0.subjectID == subject.id }
        let paperIDs = Set(subjectPapers.map(\.id))
        var transaction: LocalFileStore.DeletionTransaction?

        do {
            transaction = try LocalFileStore(rootURL: rootURL).stageDeletion(for: subject)
            subjectPapers.forEach(modelContext.delete)
            subjectQuestions.forEach(modelContext.delete)
            for record in importRecords where record.paperID.map(paperIDs.contains) == true {
                modelContext.delete(record)
            }
            modelContext.delete(subject)
            try save()
            try? transaction?.commit()
        } catch {
            modelContext.rollback()
            try? transaction?.rollback()
            throw error
        }
    }

    func permanentlyDelete(
        _ paper: Paper,
        flaggedQuestions: [FlaggedQuestion],
        importRecords: [THSCImportRecord]
    ) throws {
        guard let rootURL else { return }

        let relatedQuestions = flaggedQuestions.filter { $0.paperID == paper.id }
        let relatedImportRecords = importRecords.filter { $0.paperID == paper.id }
        var transaction: LocalFileStore.DeletionTransaction?

        do {
            transaction = try LocalFileStore(rootURL: rootURL).stageDeletion(
                for: paper,
                flaggedQuestions: relatedQuestions
            )
            relatedQuestions.forEach(modelContext.delete)
            relatedImportRecords.forEach(modelContext.delete)
            modelContext.delete(paper)
            try save()
            try? transaction?.commit()
        } catch {
            modelContext.rollback()
            try? transaction?.rollback()
            throw error
        }
    }

    func permanentlyDelete(_ question: FlaggedQuestion) throws {
        guard let rootURL else { return }

        var transaction: LocalFileStore.DeletionTransaction?

        do {
            transaction = try LocalFileStore(rootURL: rootURL).stageDeletion(for: question)
            modelContext.delete(question)
            try save()
            try? transaction?.commit()
        } catch {
            modelContext.rollback()
            try? transaction?.rollback()
            throw error
        }
    }
}
