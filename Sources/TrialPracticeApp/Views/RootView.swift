import AppKit
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query private var schools: [School]
    @State private var storageError: String?
    @AppStorage("didInitializeApplicationSupportFileStorage")
    private var didInitializeApplicationSupportFileStorage = false

    var body: some View {
        MainNavigationView()
        .frame(minWidth: 820, minHeight: 560)
        .background(WindowTitleSetter(title: AppBuild.windowTitle))
        .task(id: appState.rootFolderURL) {
            do {
                try initializeApplicationSupportStorageIfNeeded()
            } catch {
                storageError = error.localizedDescription
                return
            }
            migrateLegacyCrests()
        }
        .alert(
            "Storage Error",
            isPresented: Binding(
                get: { storageError != nil },
                set: { if !$0 { storageError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(storageError ?? "")
        }
    }

    private func initializeApplicationSupportStorageIfNeeded() throws {
        guard !didInitializeApplicationSupportFileStorage else { return }

        if let rootURL = appState.rootFolderURL {
            let contents = try FileManager.default.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: nil
            )
            for url in contents {
                try FileManager.default.removeItem(at: url)
            }
            try LocalFileStore(rootURL: rootURL).prepareFolderStructure()
        }

        let importRecords = try modelContext.fetch(FetchDescriptor<THSCImportRecord>())
        importRecords.forEach(modelContext.delete)

        let flaggedQuestions = try modelContext.fetch(FetchDescriptor<FlaggedQuestion>())
        flaggedQuestions.forEach(modelContext.delete)

        let papers = try modelContext.fetch(FetchDescriptor<Paper>())
        papers.forEach(modelContext.delete)

        let storedSchools = try modelContext.fetch(FetchDescriptor<School>())
        storedSchools.forEach(modelContext.delete)

        let subjects = try modelContext.fetch(FetchDescriptor<Subject>())
        subjects.forEach(modelContext.delete)

        try modelContext.save()
        didInitializeApplicationSupportFileStorage = true
    }

    private func migrateLegacyCrests() {
        guard let rootURL = appState.rootFolderURL else { return }
        var migratedFiles: [URL] = []
        var changed = false

        do {
            for school in schools {
                guard let path = school.crestImageRelativePath else { continue }
                let fileURL = rootURL.appending(path: path).standardizedFileURL
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    if school.crestImageData == nil, school.crestSourcePageURL == nil {
                        school.crestImageData = try SchoolCrestService().pngData(
                            from: Data(contentsOf: fileURL)
                        )
                    }
                    migratedFiles.append(fileURL)
                }
                school.crestImageRelativePath = nil
                changed = true
            }
            if changed {
                try modelContext.save()
                migratedFiles.forEach { try? FileManager.default.removeItem(at: $0) }
            }

            let legacyDirectory = rootURL.appending(
                path: "School Crests",
                directoryHint: .isDirectory
            )
            if FileManager.default.fileExists(atPath: legacyDirectory.path) {
                try FileManager.default.removeItem(at: legacyDirectory)
            }
        } catch {
            modelContext.rollback()
            storageError = error.localizedDescription
        }
    }
}
