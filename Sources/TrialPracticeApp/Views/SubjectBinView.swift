import SwiftData
import SwiftUI

struct SubjectBinView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Subject.displayName) private var allSubjects: [Subject]
    @Query private var papers: [Paper]
    @Query private var questions: [FlaggedQuestion]
    @Query private var importRecords: [THSCImportRecord]

    @State private var subjectToDelete: Subject?
    @State private var errorMessage: String?

    private var deletedSubjects: [Subject] {
        allSubjects.filter { $0.deletedAt != nil }
    }

    var body: some View {
        Group {
            if deletedSubjects.isEmpty {
                ContentUnavailableView(
                    "Bin is Empty",
                    systemImage: "trash",
                    description: Text("Deleted subjects can be restored from here.")
                )
            } else {
                List {
                    ForEach(deletedSubjects) { subject in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(subject.displayName)
                                if let deletedAt = subject.deletedAt {
                                    Text("Deleted \(deletedAt, format: .relative(presentation: .named))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Restore") {
                                restore(subject)
                            }
                            Button("Delete Permanently", role: .destructive) {
                                subjectToDelete = subject
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
            Text("This removes all associated metadata, papers, and captured images. It cannot be undone.")
        }
        .alert(
            "Deletion Failed",
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

    private func permanentlyDelete(_ subject: Subject) {
        guard let rootURL = appState.rootFolderURL else { return }

        let subjectPapers = papers.filter { $0.subjectID == subject.id }
        let paperIDs = Set(subjectPapers.map(\.id))
        var transaction: LocalFileStore.DeletionTransaction?
        do {
            transaction = try LocalFileStore(rootURL: rootURL).stageDeletion(for: subject)
            for paper in subjectPapers {
                modelContext.delete(paper)
            }
            for question in questions where question.subjectID == subject.id {
                modelContext.delete(question)
            }
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
}
