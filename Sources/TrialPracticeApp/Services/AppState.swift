import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    private enum FolderAccessError: LocalizedError {
        case accessDenied

        var errorDescription: String? {
            "The selected folder could not be opened for writing. Choose the folder again, or choose another dedicated folder."
        }
    }

    private enum Keys {
        static let rootFolderBookmark = "rootFolderBookmark"
        static let rootFolderPath = "rootFolderPath"
        static let rootFolderRelativePath = "rootFolderRelativePath"
    }

    @Published private(set) var rootFolderURL: URL?
    @Published var setupErrorMessage: String?

    private var securityScopedURL: URL?

    var needsSetup: Bool {
        rootFolderURL == nil
    }

    init() {
        restoreRootFolder()
    }

    @discardableResult
    func createRootFolder(named rawName: String, in parentURL: URL) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            setupErrorMessage = "Enter a name for the data folder."
            return false
        }
        guard name != ".", name != "..", !name.contains("/") else {
            setupErrorMessage = "Enter a valid folder name."
            return false
        }

        let didStartAccess = parentURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                parentURL.stopAccessingSecurityScopedResource()
            }
        }

        let folderURL = parentURL.appending(path: name, directoryHint: .isDirectory)
        do {
            if FileManager.default.fileExists(atPath: folderURL.path) {
                setupErrorMessage = "A folder named “\(name)” already exists in this location."
                return false
            }
            try FileManager.default.createDirectory(
                at: folderURL,
                withIntermediateDirectories: false
            )
            return configureRootFolder(
                securityScopedURL: parentURL,
                rootURL: folderURL,
                relativePath: name
            )
        } catch {
            setupErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func selectRootFolder(_ url: URL) -> Bool {
        guard Self.isDedicatedStorageFolderCandidate(url) else {
            setupErrorMessage = Self.dedicatedFolderMessage
            return false
        }
        return configureRootFolder(
            securityScopedURL: url,
            rootURL: url,
            relativePath: nil
        )
    }

    static var dedicatedFolderMessage: String {
        "Choose a dedicated folder instead of Desktop, Documents, Downloads, Library, a home folder, or an app container Data folder. The app creates its own folders inside the location you select."
    }

    static func isDedicatedStorageFolderCandidate(
        _ url: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        !isMacOSStandardFolder(url, fileManager: fileManager) &&
            !looksLikeHomeOrSandboxContainerDataFolder(url, fileManager: fileManager)
    }

    static func isMacOSStandardFolder(
        _ url: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let selectedURL = canonicalFileURL(url)
        let directories: [FileManager.SearchPathDirectory] = [
            .desktopDirectory,
            .documentDirectory,
            .downloadsDirectory,
            .moviesDirectory,
            .musicDirectory,
            .picturesDirectory,
            .sharedPublicDirectory,
            .userDirectory
        ]

        return directories
            .compactMap {
                fileManager.urls(for: $0, in: .userDomainMask).first
            }
            .map(canonicalFileURL)
            .contains(selectedURL)
    }

    static func looksLikeHomeOrSandboxContainerDataFolder(
        _ url: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let selectedURL = canonicalFileURL(url)
        let selectedName = selectedURL.lastPathComponent

        guard selectedName == NSUserName() ||
            selectedName == "Data" ||
            selectedName == "Home" ||
            selectedName == "Library" ||
            selectedName == "SystemData" else {
            return false
        }

        let suspiciousEntries = [
            "Desktop",
            "Documents",
            "Downloads",
            "Library",
            "Movies",
            "Music",
            "Pictures",
            "SystemData",
            "tmp"
        ]
        let matchingCount = suspiciousEntries.reduce(0) { count, entry in
            let entryURL = selectedURL.appending(path: entry)
            return count + (fileManager.fileExists(atPath: entryURL.path) ? 1 : 0)
        }

        return matchingCount >= 3
    }

    private static func canonicalFileURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func configureRootFolder(
        securityScopedURL selectedURL: URL,
        rootURL: URL,
        relativePath: String?
    ) -> Bool {
        guard Self.isDedicatedStorageFolderCandidate(rootURL) else {
            setupErrorMessage = Self.dedicatedFolderMessage
            return false
        }

        var startedSelectedAccess = false
        do {
            startedSelectedAccess = selectedURL.startAccessingSecurityScopedResource()

            let fileStore = LocalFileStore(rootURL: rootURL)
            try fileStore.verifyWriteAccess()
            try fileStore.prepareFolderStructure()

            let bookmark = try? selectedURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            stopAccessingCurrentFolder()
            securityScopedURL = startedSelectedAccess ? selectedURL : nil
            startedSelectedAccess = false
            if let bookmark {
                UserDefaults.standard.set(bookmark, forKey: Keys.rootFolderBookmark)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.rootFolderBookmark)
            }
            UserDefaults.standard.set(selectedURL.path, forKey: Keys.rootFolderPath)
            if let relativePath {
                UserDefaults.standard.set(relativePath, forKey: Keys.rootFolderRelativePath)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.rootFolderRelativePath)
            }
            rootFolderURL = rootURL
            setupErrorMessage = nil
            return true
        } catch {
            if startedSelectedAccess {
                selectedURL.stopAccessingSecurityScopedResource()
            }
            setupErrorMessage = error.localizedDescription
            return false
        }
    }

    func forgetRootFolder() {
        stopAccessingCurrentFolder()
        UserDefaults.standard.removeObject(forKey: Keys.rootFolderBookmark)
        UserDefaults.standard.removeObject(forKey: Keys.rootFolderPath)
        UserDefaults.standard.removeObject(forKey: Keys.rootFolderRelativePath)
        rootFolderURL = nil
    }

    func resetForDevelopment() throws {
        let dataFolderURL = rootFolderURL
        if let dataFolderURL {
            try removeContents(of: dataFolderURL)
        }

        stopAccessingCurrentFolder()
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
        UserDefaults.standard.removeObject(forKey: Keys.rootFolderBookmark)
        UserDefaults.standard.removeObject(forKey: Keys.rootFolderPath)
        UserDefaults.standard.removeObject(forKey: Keys.rootFolderRelativePath)
        UserDefaults.standard.synchronize()

        rootFolderURL = nil
        setupErrorMessage = nil
    }

    private func restoreRootFolder() {
        let storedPath = UserDefaults.standard.string(forKey: Keys.rootFolderPath)
        guard let bookmark = UserDefaults.standard.data(forKey: Keys.rootFolderBookmark) else {
            if let storedPath {
                restoreRootFolderFromPath(storedPath)
            }
            return
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                let relativePath = UserDefaults.standard.string(
                    forKey: Keys.rootFolderRelativePath
                )
                let rootURL = relativePath.map {
                    url.appending(path: $0, directoryHint: .isDirectory)
                } ?? url
                _ = configureRootFolder(
                    securityScopedURL: url,
                    rootURL: rootURL,
                    relativePath: relativePath
                )
                return
            }

            let didStartAccess = url.startAccessingSecurityScopedResource()
            securityScopedURL = didStartAccess ? url : nil
            let relativePath = UserDefaults.standard.string(
                forKey: Keys.rootFolderRelativePath
            )
            let restoredRootURL = relativePath.map {
                url.appending(path: $0, directoryHint: .isDirectory)
            } ?? url
            guard Self.isDedicatedStorageFolderCandidate(restoredRootURL) else {
                throw FolderAccessError.accessDenied
            }
            let fileStore = LocalFileStore(rootURL: restoredRootURL)
            try fileStore.prepareFolderStructure()
            try fileStore.verifyWriteAccess()
            rootFolderURL = restoredRootURL
        } catch {
            if let storedPath, restoreRootFolderFromPath(storedPath) {
                return
            }
            clearStoredRootFolderAfterRestoreFailure()
        }
    }

    @discardableResult
    private func restoreRootFolderFromPath(_ path: String) -> Bool {
        let selectedURL = URL(filePath: path, directoryHint: .isDirectory)
        let relativePath = UserDefaults.standard.string(forKey: Keys.rootFolderRelativePath)
        let restoredRootURL = relativePath.map {
            selectedURL.appending(path: $0, directoryHint: .isDirectory)
        } ?? selectedURL

        do {
            guard Self.isDedicatedStorageFolderCandidate(restoredRootURL) else {
                throw FolderAccessError.accessDenied
            }
            let didStartAccess = selectedURL.startAccessingSecurityScopedResource()
            securityScopedURL = didStartAccess ? selectedURL : nil
            let fileStore = LocalFileStore(rootURL: restoredRootURL)
            try fileStore.prepareFolderStructure()
            try fileStore.verifyWriteAccess()
            rootFolderURL = restoredRootURL
            return true
        } catch {
            clearStoredRootFolderAfterRestoreFailure()
            return false
        }
    }

    private func clearStoredRootFolderAfterRestoreFailure() {
        stopAccessingCurrentFolder()
        UserDefaults.standard.removeObject(forKey: Keys.rootFolderBookmark)
        UserDefaults.standard.removeObject(forKey: Keys.rootFolderPath)
        UserDefaults.standard.removeObject(forKey: Keys.rootFolderRelativePath)
        setupErrorMessage = "Please select the app data folder again."
    }

    private func stopAccessingCurrentFolder() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
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
