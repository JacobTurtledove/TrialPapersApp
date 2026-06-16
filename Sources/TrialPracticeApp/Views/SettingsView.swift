import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @State private var isChoosingFolder = false
    @State private var isShowingDeveloperTools = false
    @State private var isShowingResetConfirmation = false
    @State private var resetConfirmationText = ""
    @State private var resetErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data Folder")
                        .font(.title2.bold())

                    Label(
                        appState.rootFolderURL?.lastPathComponent ?? "Not selected",
                        systemImage: "folder"
                    )
                    .foregroundStyle(.secondary)

                    Button("Reconnect or Choose Another Folder") {
                        isChoosingFolder = true
                    }
                    .padding(.top, 4)

                    Button("Show Data Folder in Finder") {
                        if let rootURL = appState.rootFolderURL {
                            FinderRevealService.reveal(rootURL)
                        }
                    }
                    .disabled(appState.rootFolderURL == nil)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy")
                        .font(.title2.bold())

                    Label(
                        "No account is required. Your imported files remain in your chosen data folder.",
                        systemImage: "lock.shield"
                    )
                    .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    DisclosureGroup("Developer Tools", isExpanded: $isShowingDeveloperTools) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(
                                "Reset every app-owned record, preference, cache, and file inside the selected app data folder. This is for development testing only."
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
        .fileImporter(
            isPresented: $isChoosingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    appState.selectRootFolder(url)
                }
            case .failure(let error):
                appState.setupErrorMessage = error.localizedDescription
            }
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
