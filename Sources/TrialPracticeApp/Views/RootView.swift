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
            runStorageMigrations()
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

    private func runStorageMigrations() {
        guard let rootURL = appState.rootFolderURL else { return }
        let migrationService = StorageMigrationService()

        do {
            let result = try migrationService.migrateIfNeeded(
                rootURL: rootURL,
                schools: schools
            )
            if result.didChangeModels {
                try modelContext.save()
            }
            if let latestCompletedVersion = result.latestCompletedVersion {
                migrationService.markCompleted(upThrough: latestCompletedVersion)
            }
        } catch {
            modelContext.rollback()
            storageError = error.localizedDescription
        }
    }
}
