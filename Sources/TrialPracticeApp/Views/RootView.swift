import AppKit
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query private var schools: [School]
    @State private var storageError: String?

    var body: some View {
        MainNavigationView()
        .frame(minWidth: 820, minHeight: 560)
        .background(WindowTitleSetter(title: AppBuild.windowTitle))
        .task(id: appState.rootFolderURL) {
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
