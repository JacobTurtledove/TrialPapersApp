import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Subject.displayName) private var subjects: [Subject]
    @Query private var papers: [Paper]
    @Query private var flaggedQuestions: [FlaggedQuestion]

    @State private var isShowingDeveloperTools = false
    @State private var isShowingResetConfirmation = false
    @State private var resetConfirmationText = ""
    @State private var resetErrorMessage: String?
    @State private var exportMessage: String?
    @State private var exportedURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Storage")
                        .font(.title2.bold())

                    Label(
                        appState.rootFolderURL?.path ?? "Application Support folder unavailable",
                        systemImage: "folder"
                    )
                    .foregroundStyle(.secondary)

                    Button("Show Application Support Folder") {
                        if let rootURL = appState.rootFolderURL {
                            FinderRevealService.reveal(rootURL)
                        }
                    }
                    .padding(.top, 4)
                    .disabled(appState.rootFolderURL == nil)

                    Button {
                        exportLibrary()
                    } label: {
                        Label("Export Library", systemImage: "square.and.arrow.up")
                    }
                    .disabled(activePapers.isEmpty && activeFlaggedQuestions.isEmpty)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy")
                        .font(.title2.bold())

                    Label(
                        "No account is required. Imported files are stored locally in Application Support.",
                        systemImage: "lock.shield"
                    )
                    .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    DisclosureGroup("Developer Tools", isExpanded: $isShowingDeveloperTools) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(
                                "Reset every app-owned record, preference, cache, and file inside Application Support. This is for development testing only."
                            )
                            .font(.callout)
                            .foregroundStyle(.secondary)

                            Button("Initialise All App Data", role: .destructive) {
                                resetConfirmationText = ""
                                isShowingResetConfirmation = true
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Settings")
        .confirmationDialog(
            "Initialise absolutely all app data?",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            TextField("Type INITIALISE", text: $resetConfirmationText)
            Button("Initialise All App Data", role: .destructive) {
                initialiseAllAppData()
            }
            .disabled(resetConfirmationText != "INITIALISE")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This deletes SwiftData records, imported papers, flagged question files, bookmarks, THSC history, preferences, and caches. It cannot be undone."
            )
        }
        .alert(
            "Developer Reset Failed",
            isPresented: Binding(
                get: { resetErrorMessage != nil },
                set: { if !$0 { resetErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetErrorMessage ?? "")
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

    private var activeSubjects: [Subject] {
        subjects.filter { $0.deletedAt == nil }
    }

    private var activePapers: [Paper] {
        let activeSubjectIDs = Set(activeSubjects.map(\.id))
        return papers.filter { $0.deletedAt == nil && activeSubjectIDs.contains($0.subjectID) }
    }

    private var activeFlaggedQuestions: [FlaggedQuestion] {
        let activePaperIDs = Set(activePapers.map(\.id))
        return flaggedQuestions.filter {
            $0.deletedAt == nil && activePaperIDs.contains($0.paperID)
        }
    }

    private func exportLibrary() {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.folder]
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

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

    private func initialiseAllAppData() {
        do {
            try deleteAllSwiftDataRecords()
            try AppDirectories.removeCaches()
            try AppDirectories.removeLegacyDefaultSwiftDataStore()
            try appState.resetForDevelopment()
            resetConfirmationText = ""
        } catch {
            modelContext.rollback()
            resetErrorMessage = error.localizedDescription
        }
    }

    private func deleteAllSwiftDataRecords() throws {
        let importRecords = try modelContext.fetch(FetchDescriptor<THSCImportRecord>())
        importRecords.forEach(modelContext.delete)

        let flaggedQuestions = try modelContext.fetch(FetchDescriptor<FlaggedQuestion>())
        flaggedQuestions.forEach(modelContext.delete)

        let papers = try modelContext.fetch(FetchDescriptor<Paper>())
        papers.forEach(modelContext.delete)

        let schools = try modelContext.fetch(FetchDescriptor<School>())
        schools.forEach(modelContext.delete)

        let subjects = try modelContext.fetch(FetchDescriptor<Subject>())
        subjects.forEach(modelContext.delete)

        try modelContext.save()
    }
}
