import Foundation
import Testing
@testable import TrialPracticeApp

struct AppStateTests {
    @Test
    @MainActor
    func configuresApplicationSupportFileStorageRoot() throws {
        let rootURL = try temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let appState = AppState(fileStorageURLProvider: { rootURL })

        #expect(appState.rootFolderURL == rootURL)
        #expect(appState.setupErrorMessage == nil)
        #expect(directoryExists(rootURL.appending(path: "Papers", directoryHint: .isDirectory)))
        #expect(directoryExists(
            rootURL.appending(path: "Flagged Questions", directoryHint: .isDirectory)
        ))
    }

    @Test
    @MainActor
    func developerResetRemovesFilesAndRestoresFolderStructure() throws {
        let rootURL = try temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let appState = AppState(fileStorageURLProvider: { rootURL })
        let paperURL = rootURL.appending(path: "Papers/Example.pdf")
        try Data("paper".utf8).write(to: paperURL)
        let looseFileURL = rootURL.appending(path: "loose.txt")
        try Data("loose".utf8).write(to: looseFileURL)

        try appState.resetForDevelopment()

        #expect(appState.rootFolderURL == rootURL)
        #expect(appState.setupErrorMessage == nil)
        #expect(!FileManager.default.fileExists(atPath: paperURL.path))
        #expect(!FileManager.default.fileExists(atPath: looseFileURL.path))
        #expect(directoryExists(rootURL.appending(path: "Papers", directoryHint: .isDirectory)))
        #expect(directoryExists(
            rootURL.appending(path: "Flagged Questions", directoryHint: .isDirectory)
        ))
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

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "AppStateTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) &&
            isDirectory.boolValue
    }
}
