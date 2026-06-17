import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var rootFolderURL: URL?
    @Published private(set) var setupErrorMessage: String?

    private let fileStorageURLProvider: () throws -> URL

    init(fileStorageURLProvider: @escaping () throws -> URL = { try AppDirectories.fileStorageURL }) {
        self.fileStorageURLProvider = fileStorageURLProvider
        configureApplicationSupportRoot()
    }

    func resetForDevelopment() throws {
        let dataFolderURL = rootFolderURL
        if let dataFolderURL {
            try removeContents(of: dataFolderURL)
        }

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
        UserDefaults.standard.synchronize()

        rootFolderURL = nil
        setupErrorMessage = nil
        configureApplicationSupportRoot()
    }

    private func configureApplicationSupportRoot() {
        do {
            let rootURL = try fileStorageURLProvider()
            let fileStore = LocalFileStore(rootURL: rootURL)
            try fileStore.prepareFolderStructure()
            try fileStore.verifyWriteAccess()
            rootFolderURL = rootURL
            setupErrorMessage = nil
        } catch {
            rootFolderURL = nil
            setupErrorMessage = error.localizedDescription
        }
    }

    private func removeContents(of directoryURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}
