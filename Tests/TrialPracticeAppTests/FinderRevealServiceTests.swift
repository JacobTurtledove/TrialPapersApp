import Foundation
import Testing
@testable import TrialPracticeApp

struct FinderRevealServiceTests {
    @Test
    func resolvesExistingItemsInsideRoot() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(
            at: rootURL.appending(path: "Papers"),
            withIntermediateDirectories: true
        )
        let fileURL = rootURL.appending(path: "Papers/paper.pdf")
        try Data().write(to: fileURL)

        let resolved = try FinderRevealService.storedURL(
            relativePath: "Papers/paper.pdf",
            rootURL: rootURL
        )

        #expect(resolved == fileURL.standardizedFileURL)
    }

    @Test
    func rejectsMissingAndEscapingItems() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        #expect(throws: FinderRevealService.RevealError.self) {
            try FinderRevealService.storedURL(
                relativePath: "missing.pdf",
                rootURL: rootURL
            )
        }
        #expect(throws: FinderRevealService.RevealError.self) {
            try FinderRevealService.storedURL(
                relativePath: "../outside.pdf",
                rootURL: rootURL
            )
        }
    }

    @Test
    func rejectsItemsEscapingThroughSymlink() throws {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let rootURL = temporaryURL.appending(path: "Root", directoryHint: .isDirectory)
        let outsideURL = temporaryURL.appending(path: "Outside", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideURL, withIntermediateDirectories: true)
        try Data().write(to: outsideURL.appending(path: "paper.pdf"))
        try FileManager.default.createSymbolicLink(
            at: rootURL.appending(path: "Linked"),
            withDestinationURL: outsideURL
        )

        #expect(throws: FinderRevealService.RevealError.self) {
            try FinderRevealService.storedURL(
                relativePath: "Linked/paper.pdf",
                rootURL: rootURL
            )
        }
    }
}
