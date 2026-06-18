import Foundation

enum PaperValidation {
    static func year(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber) else {
            return nil
        }
        return trimmed
    }
}
