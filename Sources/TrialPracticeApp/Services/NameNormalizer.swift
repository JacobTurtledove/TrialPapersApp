import Foundation

enum NameNormalizer {
    static func displayName(from input: String) -> String {
        input
            .split(whereSeparator: \.isWhitespace)
            .map { word in
                let lowered = word.lowercased()
                return lowered.prefix(1).uppercased() + lowered.dropFirst()
            }
            .joined(separator: " ")
    }

    static func filenameValue(from displayName: String) -> String {
        displayName.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }
}
