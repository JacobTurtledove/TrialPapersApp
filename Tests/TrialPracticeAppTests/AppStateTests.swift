import Foundation
import Testing
@testable import TrialPracticeApp

struct AppStateTests {
    @Test
    @MainActor
    func rejectsTheActualDesktopButNotAnotherFolderNamedDesktop() throws {
        let fileManager = FileManager.default
        let desktopURL = try #require(
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
        )
        let unrelatedDesktop = FileManager.default.temporaryDirectory
            .appending(path: "Desktop", directoryHint: .isDirectory)

        #expect(AppState.isMacOSStandardFolder(desktopURL))
        #expect(!AppState.isMacOSStandardFolder(unrelatedDesktop))
    }

    @Test
    @MainActor
    func rejectsSandboxContainerDataFolderShape() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: "Container-\(UUID().uuidString)", directoryHint: .isDirectory)
        let dataURL = rootURL.appending(path: "Data", directoryHint: .isDirectory)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        for entry in ["Desktop", "Documents", "Downloads", "Library", "SystemData", "tmp"] {
            try FileManager.default.createDirectory(
                at: dataURL.appending(path: entry, directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
        }

        #expect(AppState.looksLikeHomeOrSandboxContainerDataFolder(dataURL))
        #expect(!AppState.isDedicatedStorageFolderCandidate(dataURL))
    }

    @Test
    @MainActor
    func acceptsNormalDedicatedDataFolder() throws {
        let dataURL = FileManager.default.temporaryDirectory
            .appending(path: "HSC Papers Data-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            try? FileManager.default.removeItem(at: dataURL)
        }
        try FileManager.default.createDirectory(
            at: dataURL,
            withIntermediateDirectories: true
        )

        #expect(!AppState.looksLikeHomeOrSandboxContainerDataFolder(dataURL))
        #expect(AppState.isDedicatedStorageFolderCandidate(dataURL))
    }

    @Test
    func appDirectoriesCreateBundleScopedFolders() throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appending(path: "TrialPracticeAppDirectories-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            try? FileManager.default.removeItem(at: baseURL)
        }

        let appURL = try AppDirectories.appDirectory(
            in: baseURL,
            bundleIdentifier: "au.edu.moriah.hsc-trial-revision"
        )

        #expect(appURL.lastPathComponent == "au.edu.moriah.hsc-trial-revision")
        #expect(FileManager.default.fileExists(atPath: appURL.path))
        #expect(appURL.deletingLastPathComponent() == baseURL)
    }
}
