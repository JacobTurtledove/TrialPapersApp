import Foundation
import Testing
@testable import TrialPracticeApp

struct NESAPastPaperCatalogueTests {
    @Test
    func courseLinksAreUniqueOfficialNESAPages() {
        let courses = NESAPastPaperCatalogue.courses

        #expect(courses.count >= 30)
        #expect(Set(courses.map(\.id)).count == courses.count)
        #expect(Set(courses.map(\.slug)).count == courses.count)
        #expect(courses.allSatisfy {
            $0.url.scheme == "https" &&
            $0.url.host == "www.nsw.gov.au" &&
            $0.url.path.hasPrefix(
                "/education-and-training/nesa/curriculum/hsc-exam-papers/"
            )
        })
    }

    @Test
    func majorLearningAreasAreRepresented() {
        #expect(
            Set(NESAPastPaperCatalogue.learningAreas) == [
                "Creative Arts",
                "English",
                "HSIE",
                "Mathematics",
                "PDHPE",
                "Science",
                "Technology"
            ]
        )
    }
}
