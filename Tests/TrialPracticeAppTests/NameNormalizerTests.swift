import Testing
@testable import TrialPracticeApp

struct NameNormalizerTests {
    @Test
    func normalizesDisplayNameCasingAndWhitespace() {
        #expect(NameNormalizer.displayName(from: "  noRTH   SyDNey boys ") == "North Sydney Boys")
    }

    @Test
    func removesSpacesAndSymbolsFromFilename() {
        let displayName = NameNormalizer.displayName(from: "St Aloysius' College")
        #expect(NameNormalizer.filenameValue(from: displayName) == "StAloysiusCollege")
    }

    @Test
    func keepsLettersAndDigitsInFilename() {
        #expect(NameNormalizer.filenameValue(from: "Maths Advanced 2!") == "MathsAdvanced2")
    }

    @Test
    func preservesDigitsInExtensionSubjects() {
        let extension1 = NameNormalizer.filenameValue(from: "Mathematics Extension 1")
        let extension2 = NameNormalizer.filenameValue(from: "Mathematics Extension 2")

        #expect(extension1.contains("1"))
        #expect(extension2.contains("2"))
        #expect(extension1 != extension2)
    }

    @Test
    func numberedMusicSubjectsRemainDistinct() {
        #expect(NameNormalizer.filenameValue(from: "Music 1") != NameNormalizer.filenameValue(from: "Music 2"))
    }

    @Test
    func removesUnsafePathSeparatorsAndPunctuation() {
        #expect(NameNormalizer.filenameValue(from: "North/South: College? 2") == "NorthSouthCollege2")
    }

    @Test
    func blankOrPunctuationOnlyNamesProduceEmptyFilenameToken() {
        #expect(NameNormalizer.filenameValue(from: "   ") == "")
        #expect(NameNormalizer.filenameValue(from: "./-_'") == "")
    }
}
