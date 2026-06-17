import Testing
@testable import TrialPracticeApp

struct LibraryMutationServiceTests {
    @Test
    func rewritesSubjectFolderInPaperPath() {
        let path = LibraryMutationService.replaceSubjectFolder(
            in: "Papers/MathsAdvanced/ExampleSchool/MathsAdvanced_ExampleSchool_2025.pdf",
            topLevel: "Papers",
            from: "MathsAdvanced",
            to: "MathsExtension"
        )

        #expect(
            path ==
                "Papers/MathsExtension/ExampleSchool/MathsAdvanced_ExampleSchool_2025.pdf"
        )
    }

    @Test
    func rewritesSubjectFolderInFlaggedQuestionPath() {
        let path = LibraryMutationService.replaceSubjectFolder(
            in: "Flagged Questions/Physics/Mistakes/Physics_2025_Q1.png",
            topLevel: "Flagged Questions",
            from: "Physics",
            to: "Chemistry"
        )

        #expect(path == "Flagged Questions/Chemistry/Mistakes/Physics_2025_Q1.png")
    }

    @Test
    func leavesPathOutsideSubjectFolderUnchanged() {
        let path = LibraryMutationService.replaceSubjectFolder(
            in: "Papers/MathsAdvancedExtension/ExampleSchool/paper.pdf",
            topLevel: "Papers",
            from: "MathsAdvanced",
            to: "MathsExtension"
        )

        #expect(path == "Papers/MathsAdvancedExtension/ExampleSchool/paper.pdf")
    }
}
