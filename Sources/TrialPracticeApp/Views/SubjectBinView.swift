 import SwiftData
import SwiftUI

struct SubjectBinView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Subject.displayName) private var subjects: [Subject]
    @Query(sort: \School.displayName) private var schools: [School]
    @Query(sort: \Paper.year, order: .reverse) private var papers: [Paper]
    @Query(sort: \FlaggedQuestion.createdAt, order: .reverse) private var questions: [FlaggedQuestion]
    @Query private var importRecords: [THSCImportRecord]

    @State private var subjectToDelete: Subject?
    @State private var paperToDelete: Paper?
    @State private var questionToDelete: FlaggedQuestion?
    @State private var errorMessage: String?

    private var deletedSubjects: [Subject] {
        subjects.filter { $0.deletedAt != nil }
    }

    private var deletedPapers: [Paper] {
        papers.filter { paper in
            paper.deletedAt != nil &&
            subject(for: paper)?.deletedAt == nil
        }
    }

    private var deletedQuestions: [FlaggedQuestion] {
        questions.filter { question in
            question.deletedAt != nil &&
            paper(for: question)?.deletedAt == nil &&
            subject(for: question)?.deletedAt == nil
        }
    }

    var body: some View {
        Group {
            if deletedSubjects.isEmpty && deletedPapers.isEmpty && deletedQuestions.isEmpty {
                ContentUnavailableView(
                    "Bin is Empty",
                    systemImage: "trash",
                    description: Text("Deleted items can be restored from here.")
                )
            } else {
                List {
                    if !deletedSubjects.isEmpty {
                        Section("Subjects") {
                            ForEach(deletedSubjects) { subject in
                                binRow(
                                    title: subject.displayName,
                                    detail: deletedDetail(subject.deletedAt),
                                    icon: "folder",
                                    restore: { restore(subject) },
                                    delete: { subjectToDelete = subject }
                                )
                            }
                        }
                    }

                    if !deletedPapers.isEmpty {
                        Section("Papers") {
                            ForEach(deletedPapers) { paper in
                                binRow(
                                    title: paperTitle(paper),
                                    detail: deletedDetail(paper.deletedAt),
                                    icon: "doc",
                                    restore: { restore(paper) },
                                    delete: { paperToDelete = paper }
                                )
                            }
                        }
                    }

                    if !deletedQuestions.isEmpty {
                        Section("Flagged Questions") {
                            ForEach(deletedQuestions) { question in
                                binRow(
                                    title: questionTitle(question),
                                    detail: deletedDetail(question.deletedAt),
                                    icon: "flag",
                                    restore: { restore(question) },
                                    delete: { questionToDelete = question }
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Bin")
        .confirmationDialog(
            "Permanently delete this subject?",
            isPresented: Binding(
                get: { subjectToDelete != nil },
                set: { if !$0 { subjectToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Subject and All Files", role: .destructive) {
                if let subject = subjectToDelete {
                    permanentlyDelete(subject)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the subject, its papers, flagged questions, and stored files from Application Support. It cannot be undone.")
        }
        .confirmationDialog(
            "Permanently delete this paper?",
            isPresented: Binding(
                get: { paperToDelete != nil },
                set: { if !$0 { paperToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Paper and Files", role: .destructive) {
                if let paper = paperToDelete {
                    permanentlyDelete(paper)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the paper, its flagged questions, and stored files from Application Support. It cannot be undone.")
        }
        .confirmationDialog(
            "Permanently delete this flagged question?",
            isPresented: Binding(
                get: { questionToDelete != nil },
                set: { if !$0 { questionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Flagged Question and Files", role: .destructive) {
                if let question = questionToDelete {
                    permanentlyDelete(question)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the captured question and solution images from Application Support. It cannot be undone.")
        }
        .alert(
            "Bin Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func binRow(
        title: String,
        detail: String,
        icon: String,
        restore: @escaping () -> Void,
        delete: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restore", action: restore)
            Button("Delete Permanently", role: .destructive, action: delete)
        }
    }

    private func restore(_ subject: Subject) {
        let deletedAt = subject.deletedAt
        subject.deletedAt = nil
        do {
            try modelContext.save()
        } catch {
            subject.deletedAt = deletedAt
            errorMessage = "The subject could not be restored: \(error.localizedDescription)"
        }
    }

    private func restore(_ paper: Paper) {
        guard subject(for: paper)?.deletedAt == nil else {
            errorMessage = "Restore the subject before restoring this paper."
            return
        }

        let relatedQuestions = questions.filter { $0.paperID == paper.id }
        let oldPaperDeletedAt = paper.deletedAt
        let questionSnapshots = relatedQuestions.map { ($0, $0.deletedAt) }
        paper.deletedAt = nil
        relatedQuestions.forEach { $0.deletedAt = nil }

        do {
            try modelContext.save()
        } catch {
            paper.deletedAt = oldPaperDeletedAt
            questionSnapshots.forEach { $0.0.deletedAt = $0.1 }
            modelContext.rollback()
            errorMessage = "The paper could not be restored: \(error.localizedDescription)"
        }
    }

    private func restore(_ question: FlaggedQuestion) {
        guard subject(for: question)?.deletedAt == nil else {
            errorMessage = "Restore the subject before restoring this flagged question."
            return
        }
        guard paper(for: question)?.deletedAt == nil else {
            errorMessage = "Restore the paper before restoring this flagged question."
            return
        }

        let deletedAt = question.deletedAt
        question.deletedAt = nil
        do {
            try modelContext.save()
        } catch {
            question.deletedAt = deletedAt
            modelContext.rollback()
            errorMessage = "The flagged question could not be restored: \(error.localizedDescription)"
        }
    }

    private func permanentlyDelete(_ subject: Subject) {
        guard let rootURL = appState.rootFolderURL else { return }

        let subjectPapers = papers.filter { $0.subjectID == subject.id }
        let subjectQuestions = questions.filter { $0.subjectID == subject.id }
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
            try modelContext.save()
            try? transaction?.commit()
            subjectToDelete = nil
        } catch {
            modelContext.rollback()
            try? transaction?.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func permanentlyDelete(_ paper: Paper) {
        guard let rootURL = appState.rootFolderURL else { return }

        let relatedQuestions = questions.filter { $0.paperID == paper.id }
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
            try modelContext.save()
            try? transaction?.commit()
            paperToDelete = nil
        } catch {
            modelContext.rollback()
            try? transaction?.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func permanentlyDelete(_ question: FlaggedQuestion) {
        guard let rootURL = appState.rootFolderURL else { return }

        var transaction: LocalFileStore.DeletionTransaction?
        do {
            transaction = try LocalFileStore(rootURL: rootURL).stageDeletion(for: question)
            modelContext.delete(question)
            try modelContext.save()
            try? transaction?.commit()
            questionToDelete = nil
        } catch {
            modelContext.rollback()
            try? transaction?.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func subject(for paper: Paper) -> Subject? {
        subjects.first { $0.id == paper.subjectID }
    }

    private func subject(for question: FlaggedQuestion) -> Subject? {
        subjects.first { $0.id == question.subjectID }
    }

    private func school(for paper: Paper) -> School? {
        schools.first { $0.id == paper.schoolID }
    }

    private func school(for question: FlaggedQuestion) -> School? {
        schools.first { $0.id == question.schoolID }
    }

    private func paper(for question: FlaggedQuestion) -> Paper? {
        papers.first { $0.id == question.paperID }
    }

    private func paperTitle(_ paper: Paper) -> String {
        [
            subject(for: paper)?.displayName,
            school(for: paper)?.displayName,
            paper.year
        ]
        .compactMap { $0 }
        .joined(separator: " - ")
    }

    private func questionTitle(_ question: FlaggedQuestion) -> String {
        [
            subject(for: question)?.displayName,
            school(for: question)?.displayName,
            question.year,
            "Question \(question.questionNumber)"
        ]
        .compactMap { $0 }
        .joined(separator: " - ")
    }

    private func deletedDetail(_ deletedAt: Date?) -> String {
        guard let deletedAt else { return "Deleted" }
        return "Deleted \(deletedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
