import Foundation
import Testing
@testable import TrialPracticeApp

struct StoredFilePathTests {
    @Test
    func acceptsNormalRelativePaths() throws {
        let path = try StoredFilePath("Papers/Maths Advanced/Example School/paper.pdf")

        #expect(path.rawValue == "Papers/Maths Advanced/Example School/paper.pdf")
        #expect(path.description == path.rawValue)
    }

    @Test
    func rejectsEmptyAndAbsolutePaths() {
        #expect(throws: StoredFilePath.ValidationError.empty) {
            _ = try StoredFilePath("")
        }
        #expect(throws: StoredFilePath.ValidationError.absolute) {
            _ = try StoredFilePath("/Users/example/paper.pdf")
        }
    }

    @Test
    func rejectsTraversalAndAmbiguousComponents() {
        #expect(throws: StoredFilePath.ValidationError.parentDirectoryComponent) {
            _ = try StoredFilePath("../paper.pdf")
        }
        #expect(throws: StoredFilePath.ValidationError.parentDirectoryComponent) {
            _ = try StoredFilePath("Papers/../paper.pdf")
        }
        #expect(throws: StoredFilePath.ValidationError.currentDirectoryComponent) {
            _ = try StoredFilePath("Papers/./paper.pdf")
        }
        #expect(throws: StoredFilePath.ValidationError.emptyComponent) {
            _ = try StoredFilePath("Papers//paper.pdf")
        }
    }

    @Test
    func resolvesURLsInsideRoot() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storedPath = try StoredFilePath("Papers/paper.pdf")
        let resolvedURL = try storedPath.url(relativeTo: rootURL)

        #expect(resolvedURL == rootURL.appending(path: "Papers/paper.pdf").standardizedFileURL)
    }

    @Test
    func rejectsURLsEscapingThroughSymlink() throws {
        let temporaryURL = try temporaryDirectory()
        let rootURL = temporaryURL.appending(path: "Root", directoryHint: .isDirectory)
        let outsideURL = temporaryURL.appending(path: "Outside", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideURL, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: rootURL.appending(path: "Linked"),
            withDestinationURL: outsideURL
        )

        let storedPath = try StoredFilePath("Linked/paper.pdf")

        #expect(throws: StoredFilePath.ValidationError.outsideRoot) {
            _ = try storedPath.url(relativeTo: rootURL)
        }
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "StoredFilePathTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
