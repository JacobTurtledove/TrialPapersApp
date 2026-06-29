import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SchoolLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationCoordinator: AppNavigationCoordinator
    @Query(sort: \Paper.year, order: .reverse) private var allPapers: [Paper]
    @Query private var flaggedQuestions: [FlaggedQuestion]
    @Query private var importRecords: [THSCImportRecord]

    let subject: Subject
    let school: School

    @State private var isAddingPaper = false
    @State private var paperToDelete: Paper?
    @State private var deletionError: String?
    @State private var exportMessage: String?
    @State private var exportedURL: URL?
    @State private var expandedNotePaperIDs: Set<UUID> = []

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 290), spacing: 20)
    ]

    private var papers: [Paper] {
        allPapers.filter {
            $0.subjectID == subject.id && $0.schoolID == school.id && $0.deletedAt == nil
        }
    }

    private var activeFlaggedQuestions: [FlaggedQuestion] {
        let paperIDs = Set(papers.map(\.id))
        return flaggedQuestions.filter {
            $0.deletedAt == nil && paperIDs.contains($0.paperID)
        }
    }

    var body: some View {
        Group {
            if papers.isEmpty {
                ContentUnavailableView {
                    Label("No Papers", systemImage: "doc")
                } description: {
                    Text("Add a paper for \(school.displayName).")
                } actions: {
                    HStack {
                        Button("Add Paper") {
                            isAddingPaper = true
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            navigationCoordinator.showTHSCImport()
                        } label: {
                            Label("Import from THSC instead", systemImage: "arrow.down.doc.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(papers) { paper in
                            VStack(alignment: .leading, spacing: 8) {
                                NavigationLink {
                                    PaperViewerScreen(
                                        paper: paper,
                                        subject: subject,
                                        school: school
                                    )
                                } label: {
                                    PaperLibraryCard(
                                        paper: paper,
                                        flaggedCount: flaggedQuestions.filter {
                                            $0.paperID == paper.id && $0.deletedAt == nil
                                        }.count
                                    )
                                }
                                .buttonStyle(.plain)

                                HStack(spacing: 12) {
                                    Toggle(
                                        "Completed",
                                        isOn: completionBinding(for: paper)
                                    )
                                    .toggleStyle(.checkbox)

                                    Spacer(minLength: 0)

                                    PaperScoreEditor(
                                        paper: paper,
                                        errorMessage: $deletionError,
                                        style: .compact
                                    )
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 4)

                                VStack(alignment: .leading, spacing: 10) {
                                    Button {
                                        toggleNotes(for: paper)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(
                                                systemName: isNotesExpanded(for: paper)
                                                    ? "chevron.down"
                                                    : "chevron.right"
                                            )
                                            .font(.caption.weight(.semibold))
                                            .frame(width: 12)
                                            .foregroundStyle(.secondary)

                                            Label("Notes", systemImage: "note.text")
                                                .font(.callout)

                                            Spacer(minLength: 0)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if isNotesExpanded(for: paper) {
                                        TextEditor(text: notesBinding(for: paper))
                                            .font(.body)
                                            .scrollContentBackground(.hidden)
                                            .frame(minHeight: 82)
                                            .padding(8)
                                            .background(.background, in: RoundedRectangle(cornerRadius: 8))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(.separator.opacity(0.7), lineWidth: 1)
                                            }
                                            .accessibilityLabel("Paper notes")
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.separator.opacity(0.5), lineWidth: 1)
                                }
                            }
                            .contextMenu {
                                Button("Show in Finder") {
                                    reveal(paper)
                                }
                                Button("Export PDF") {
                                    exportPaper(paper)
                                }
                                Button("Delete Paper", role: .destructive) {
                                    paperToDelete = paper
                                }
                            }
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle(school.displayName)
        .toolbar {
            HStack {
                Button {
                    exportSchoolFolder()
                } label: {
                    Label("Export School Folder", systemImage: "square.and.arrow.up")
                }
                .disabled(papers.isEmpty && activeFlaggedQuestions.isEmpty)

                Button {
                    isAddingPaper = true
                } label: {
                    Label("Add Paper", systemImage: "doc.badge.plus")
                }

                Button {
                    navigationCoordinator.showTHSCImport()
                } label: {
                    Label("Import from THSC instead", systemImage: "arrow.down.doc.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $isAddingPaper) {
            AddPaperView(
                initialSubjectID: subject.id,
                initialSchoolName: school.displayName
            )
        }
        .confirmationDialog(
            "Delete this paper?",
            isPresented: Binding(
                get: { paperToDelete != nil },
                set: { if !$0 { paperToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Paper", role: .destructive) {
                deletePaper()
            }
        } message: {
            Text("The paper and its flagged questions will move to the Bin. Stored files will remain in Application Support.")
        }
        .alert(
            "Paper Error",
            isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "")
        }
        .alert(
            "Export",
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

    private func reveal(_ paper: Paper) {
        guard let rootURL = appState.rootFolderURL else {
            deletionError = "The app storage folder is unavailable."
            return
        }
        do {
            try FinderRevealService.revealStoredItem(
                relativePath: paper.primaryPDFRelativePath,
                rootURL: rootURL
            )
        } catch {
            deletionError = error.localizedDescription
        }
    }

    private func isNotesExpanded(for paper: Paper) -> Bool {
        expandedNotePaperIDs.contains(paper.id)
    }

    private func toggleNotes(for paper: Paper) {
        if expandedNotePaperIDs.contains(paper.id) {
            expandedNotePaperIDs.remove(paper.id)
        } else {
            expandedNotePaperIDs.insert(paper.id)
        }
    }

    private func notesBinding(for paper: Paper) -> Binding<String> {
        Binding(
            get: { paper.notes ?? "" },
            set: { newValue in
                let oldValue = paper.notes
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                paper.notes = trimmed.isEmpty ? nil : newValue
                do {
                    try modelContext.save()
                } catch {
                    paper.notes = oldValue
                    modelContext.rollback()
                    deletionError = error.localizedDescription
                }
            }
        )
    }

    private func completionBinding(for paper: Paper) -> Binding<Bool> {
        Binding(
            get: { paper.isCompleted },
            set: { isCompleted in
                let oldValue = paper.isCompleted
                paper.isCompleted = isCompleted
                do {
                    try modelContext.save()
                } catch {
                    paper.isCompleted = oldValue
                    modelContext.rollback()
                    deletionError = error.localizedDescription
                }
            }
        )
    }

    private func deletePaper() {
        guard let paper = paperToDelete else {
            return
        }
        let relatedQuestions = flaggedQuestions.filter {
            $0.paperID == paper.id && $0.deletedAt == nil
        }
        let oldPaperDeletedAt = paper.deletedAt
        let questionSnapshots = relatedQuestions.map { ($0, $0.deletedAt) }
        let deletedAt = Date.now
        do {
            paper.deletedAt = deletedAt
            relatedQuestions.forEach { $0.deletedAt = deletedAt }
            try modelContext.save()
            paperToDelete = nil
        } catch {
            paper.deletedAt = oldPaperDeletedAt
            questionSnapshots.forEach { $0.0.deletedAt = $0.1 }
            modelContext.rollback()
            deletionError = error.localizedDescription
        }
    }

    private func exportSchoolFolder() {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        guard let destinationURL = chooseLibraryExportFolder() else { return }
        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportSchoolFolder(
                subject: subject,
                school: school,
                papers: papers,
                flaggedQuestions: activeFlaggedQuestions,
                to: destinationURL
            )
            exportMessage = "School folder exported successfully."
        } catch {
            exportedURL = nil
            exportMessage = error.localizedDescription
        }
    }

    private func exportPaper(_ paper: Paper) {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        let storedPath = paper.primaryPDFRelativePath
        savePanel.nameFieldStringValue = (storedPath as NSString).lastPathComponent

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportPaper(
                paper,
                to: destinationURL
            )
            exportMessage = "PDF exported successfully."
        } catch {
            exportedURL = nil
            exportMessage = error.localizedDescription
        }
    }
}
