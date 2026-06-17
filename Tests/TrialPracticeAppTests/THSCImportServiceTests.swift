import Foundation
import Testing
@testable import TrialPracticeApp

struct THSCImportServiceTests {
    @Test
    func exposesExpandedUniqueTrialCollections() {
        #expect(!THSCSource.presets.isEmpty)
        #expect(THSCSource.presets.count == 26)
        #expect(Set(THSCSource.presets.map(\.id)).count == 26)
        #expect(THSCSource.presets.contains { $0.name == "Business Studies Trials" })
        #expect(THSCSource.presets.contains { $0.name == "Legal Studies Trials" })
        #expect(THSCSource.presets.contains { $0.name == "Visual Arts Trials" })
    }

    @Test
    func parsesTHSCListingTitlesAndMetadata() throws {
        let html = """
        <!-- BEGIN CONTENT 1828 --->
        <a href="#v" onClick="pdf(this, 1828)">James Ruse 2025 w. sol</a>
        <a href="#v" onClick="pdf(this, 1828)">North Sydney Boys 2022</a>
        """

        let papers = THSCImportService.parseListingHTML(html)

        #expect(papers.count == 2)
        #expect(papers[0].viewID == 1828)
        #expect(papers[0].schoolName == "James Ruse")
        #expect(papers[0].year == "2025")
        #expect(papers[0].hasSolutions)
        #expect(papers[0].id == "thsc:1828:james ruse 2025 w. sol")
        #expect(papers[1].schoolName == "North Sydney Boys")
        #expect(papers[1].year == "2022")
    }

    @Test
    func identifiesListingsWithoutSolutionsFromTheirTitles() throws {
        let html = """
        <a onClick="pdf(this, 1828)">James Ruse 2025 w. sol</a>
        <a onClick="pdf(this, 1829)">North Sydney Boys 2024</a>
        <a onClick="pdf(this, 1830)">Sydney Grammar 2023 w. solutions</a>
        """

        let papers = THSCImportService.parseListingHTML(html)

        #expect(papers.count == 3)
        #expect(papers[0].hasSolutions)
        #expect(!papers[1].hasSolutions)
        #expect(papers[2].hasSolutions)
        #expect(papers[2].schoolName == "Sydney Grammar")
    }

    @Test
    func sourceScopedIdentifiersAllowDifferentCollectionsToUseTheSameTHSCView() {
        let maths = THSCPaperListing(
            viewID: 1828,
            title: "James Ruse 2025 w. sol",
            schoolName: "James Ruse",
            year: "2025",
            sourcePageURL: "https://thsconline.github.io/s/yr12/Maths/trialpapers_extension2.html"
        )
        let physics = THSCPaperListing(
            viewID: 1828,
            title: "James Ruse 2025 w. sol",
            schoolName: "James Ruse",
            year: "2025",
            sourcePageURL: "https://thsconline.github.io/s/yr12/Physics/trialpapers.html"
        )

        #expect(maths.legacyIdentifier == "thsc:1828:james ruse 2025 w. sol")
        #expect(physics.legacyIdentifier == maths.legacyIdentifier)
        #expect(physics.id != maths.id)
    }

    @Test
    func filtersListingsBySolutionAvailability() {
        let withSolutions = THSCPaperListing(
            viewID: 1,
            title: "James Ruse 2025 w. sol",
            schoolName: "James Ruse",
            year: "2025"
        )
        let withoutSolutions = THSCPaperListing(
            viewID: 2,
            title: "North Sydney Boys 2024",
            schoolName: "North Sydney Boys",
            year: "2024"
        )

        #expect(THSCSolutionsFilter.all.includes(withSolutions))
        #expect(THSCSolutionsFilter.all.includes(withoutSolutions))
        #expect(THSCSolutionsFilter.withSolutions.includes(withSolutions))
        #expect(!THSCSolutionsFilter.withSolutions.includes(withoutSolutions))
        #expect(!THSCSolutionsFilter.withoutSolutions.includes(withSolutions))
        #expect(THSCSolutionsFilter.withoutSolutions.includes(withoutSolutions))
    }

    @Test
    func ignoresLinksWithoutARecognizableYear() {
        let html = """
        <a href="#v" onClick="pdf(this, 1828)">Course notes</a>
        """

        #expect(THSCImportService.parseListingHTML(html).isEmpty)
    }

    @Test
    @MainActor
    func reusesNewSchoolAcrossOneImportBatch() {
        var schoolsByName: [String: School] = [:]

        let first = THSCImportCoordinator.resolveSchool(
            named: "James Ruse",
            schoolsByName: &schoolsByName
        )
        let second = THSCImportCoordinator.resolveSchool(
            named: "james ruse",
            schoolsByName: &schoolsByName
        )

        #expect(first === second)
        #expect(schoolsByName.count == 1)
    }
}
