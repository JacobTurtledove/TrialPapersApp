import AppKit
import Foundation
import Testing
@testable import TrialPracticeApp

struct SchoolCrestLookupServiceTests {
    @Test
    func matchesCanonicalOfficialAndAliasNames() throws {
        let entries = [
            SchoolCrestLookupService.Entry(
                name: "James Ruse",
                file: "images/James Ruse.png",
                officialName: "James Ruse Agricultural High School",
                sourceURL: nil,
                aliases: ["JRAHS"]
            )
        ]

        #expect(
            SchoolCrestLookupService.bestEntry(
                for: "James Ruse",
                in: entries
            )?.name == "James Ruse"
        )
        #expect(
            SchoolCrestLookupService.bestEntry(
                for: "James Ruse Agricultural High School",
                in: entries
            )?.name == "James Ruse"
        )
        #expect(
            SchoolCrestLookupService.bestEntry(
                for: "jrahs",
                in: entries
            )?.name == "James Ruse"
        )
    }

    @Test
    func rejectsAmbiguousAliases() {
        let entries = [
            SchoolCrestLookupService.Entry(
                name: "Killara",
                file: "images/Killara.png",
                officialName: "Killara High School",
                sourceURL: nil,
                aliases: ["KHS"]
            ),
            SchoolCrestLookupService.Entry(
                name: "Kirrawee",
                file: "images/Kirrawee.png",
                officialName: "Kirrawee High School",
                sourceURL: nil,
                aliases: ["KHS"]
            )
        ]

        #expect(
            SchoolCrestLookupService.bestEntry(for: "KHS", in: entries) == nil
        )
    }

    @Test
    func productionPackContainsSeventyReadableImages() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packURL = repositoryURL.appending(
            path: "School Crest Pack",
            directoryHint: .isDirectory
        )
        let manifestData = try Data(
            contentsOf: packURL.appending(path: "manifest.json")
        )
        let manifest = try JSONDecoder().decode(
            SchoolCrestLookupService.Manifest.self,
            from: manifestData
        )

        #expect(manifest.version == 1)
        #expect(manifest.schools.count == 70)
        #expect(Set(manifest.schools.map(\.name)).count == 70)

        for entry in manifest.schools {
            let match = try SchoolCrestLookupService(packURL: packURL).findCrest(
                for: entry.name
            )
            let result = try #require(match)
            #expect(NSImage(contentsOf: result.imageURL) != nil)
        }
    }
}
