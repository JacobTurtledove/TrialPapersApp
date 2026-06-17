import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Subject.displayName) private var allSubjects: [Subject]
    @Query private var papers: [Paper]
    @Query private var flaggedQuestions: [FlaggedQuestion]

    @State private var isAddingSubject = false
    @State private var subjectToRename: Subject?
    @State private var errorMessage: String?
    @State private var exportMessage: String?
    @State private var exportedURL: URL?

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 20)
    ]

    private var activeSubjects: [Subject] {
        allSubjects.filter { $0.deletedAt == nil }
    }

    private var activePapers: [Paper] {
        let subjectIDs = Set(activeSubjects.map(\.id))
        return papers.filter { $0.deletedAt == nil && subjectIDs.contains($0.subjectID) }
    }

    private var activeFlaggedQuestions: [FlaggedQuestion] {
        let paperIDs = Set(activePapers.map(\.id))
        return flaggedQuestions.filter {
            $0.deletedAt == nil && paperIDs.contains($0.paperID)
        }
    }

    var body: some View {
        Group {
            if activeSubjects.isEmpty {
                ContentUnavailableView {
                    Label("Library is Empty", systemImage: "folder")
                } description: {
                    Text("Create a subject folder to begin organising trial papers.")
                } actions: {
                    Button("New Subject") {
                        isAddingSubject = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(activeSubjects) { subject in
                            NavigationLink {
                                SubjectLibraryView(subject: subject)
                            } label: {
                                LibraryFolderCard(
                                    title: subject.displayName,
                                    subtitle: paperCountDescription(for: subject),
                                    icon: "folder.fill",
                                    color: subject.folderColor
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Show Papers in Finder") {
                                    revealFolder("Papers/\(subject.filenameValue)")
                                }
                                Button("Export Subject") {
                                    exportSubject(subject)
                                }
                                Button("Rename Subject") {
                                    subjectToRename = subject
                                }
                                Button("Move to Bin", role: .destructive) {
                                    moveToBin(subject)
                                }
                            }
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            HStack {
                Button {
                    exportLibrary()
                } label: {
                    Label("Export Library", systemImage: "square.and.arrow.up")
                }
                .disabled(activePapers.isEmpty && activeFlaggedQuestions.isEmpty)

                Button {
                    isAddingSubject = true
                } label: {
                    Label("New Subject", systemImage: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $isAddingSubject) {
            SubjectEditor(title: "New Subject") {
                createSubject($0, colorHex: $1)
            }
        }
        .sheet(item: $subjectToRename) { subject in
            SubjectEditor(
                title: "Edit Subject",
                initialName: subject.displayName,
                initialColorHex: subject.colorHex
            ) {
                rename(subject, to: $0, colorHex: $1)
            }
        }
        .alert(
            "Library Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            "Library Export",
            isPresented: Binding(
                get: { exportMessage != nil },
                set: { if !$0 { exportMessage = nil } }
            )
        ) {
            if let exportedURL {
                Button("Show in Finder") {
                    FinderRevealService.reveal(exportedURL)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private func revealFolder(_ relativePath: String) {
        guard let rootURL = appState.rootFolderURL else {
            errorMessage = "The app storage folder is unavailable."
            return
        }
        do {
            try FinderRevealService.revealStoredItem(
                relativePath: relativePath,
                rootURL: rootURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func paperCountDescription(for subject: Subject) -> String {
        let count = activePapers.filter { $0.subjectID == subject.id }.count
        return "\(count) paper\(count == 1 ? "" : "s")"
    }

    private func createSubject(_ input: String, colorHex: String) -> String? {
        guard let rootURL = appState.rootFolderURL else {
            return "The app storage folder is unavailable."
        }

        return LibraryMutationService(
            rootURL: rootURL,
            modelContext: modelContext
        ).createSubject(
            input,
            colorHex: colorHex,
            allSubjects: allSubjects
        )
    }

    private func rename(_ subject: Subject, to input: String, colorHex: String) -> String? {
        guard let rootURL = appState.rootFolderURL else {
            return "The app storage folder is unavailable."
        }

        return LibraryMutationService(
            rootURL: rootURL,
            modelContext: modelContext
        ).renameSubject(
            subject,
            to: input,
            colorHex: colorHex,
            allSubjects: allSubjects,
            papers: papers,
            flaggedQuestions: flaggedQuestions
        )
    }

    private func moveToBin(_ subject: Subject) {
        if let message = LibraryMutationService(
            modelContext: modelContext
        ).moveSubjectToBin(subject) {
            errorMessage = message
        }
    }

    private func exportLibrary() {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        guard let destinationURL = chooseLibraryExportFolder() else { return }
        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportLibrary(
                subjects: activeSubjects,
                papers: activePapers,
                flaggedQuestions: activeFlaggedQuestions,
                to: destinationURL
            )
            exportMessage = "Library exported successfully."
        } catch {
            exportedURL = nil
            exportMessage = error.localizedDescription
        }
    }

    private func exportSubject(_ subject: Subject) {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        guard let destinationURL = chooseLibraryExportFolder() else { return }
        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportSubject(
                subject,
                papers: activePapers,
                flaggedQuestions: activeFlaggedQuestions,
                to: destinationURL
            )
            exportMessage = "Subject exported successfully."
        } catch {
            exportedURL = nil
            exportMessage = error.localizedDescription
        }
    }

}
