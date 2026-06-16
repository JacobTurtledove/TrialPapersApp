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
    func keepsLettersOnlyInFilename() {
        #expect(NameNormalizer.filenameValue(from: "Maths Advanced 2!") == "MathsAdvanced")
    }
}
