import SwiftUI
import UniformTypeIdentifiers

struct SetupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isChoosingFolder = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 54))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("HSC Trial Paper Revision")
                    .font(.largeTitle.bold())
                Text("Choose where to store your exam papers.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Papers stay organised by subject and school", systemImage: "folder")
                Label("Flagged questions are stored alongside your papers", systemImage: "flag")
                Label("You remain in control of the files", systemImage: "folder.badge.gearshape")
            }
            .font(.body)

            Text(
                "First choose a dedicated folder where your real papers and flagged-question images will be stored. The app remembers this folder and uses it later for imports, PDF captures, and revision booklets."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 440)

            Text("Do not choose Desktop, Downloads, Library, or a macOS container Data folder. A folder named something like “HSC Trial Papers” is best.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 480)

            Button("Choose Exam Papers Folder") {
                isChoosingFolder = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let errorMessage = appState.setupErrorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }
        }
        .padding(48)
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
}
