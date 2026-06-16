import Foundation
import SwiftData
import SwiftUI

@Model
final class Subject {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var filenameValue: String
    var colorHex: String = "#4A90E2"
    var createdAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        displayName: String,
        filenameValue: String,
        colorHex: String = "#4A90E2",
        createdAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.filenameValue = filenameValue
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }

    var folderColor: Color {
        Color(subjectHex: colorHex)
    }
}

extension Color {
    init(subjectHex: String) {
        let cleaned = subjectHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard
            cleaned.count == 6,
            let value = UInt64(cleaned, radix: 16)
        else {
            self = Color(red: 74 / 255, green: 144 / 255, blue: 226 / 255)
            return
        }

        self = Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var subjectHex: String {
        guard
            let color = NSColor(self).usingColorSpace(.sRGB)
        else {
            return "#4A90E2"
        }

        return String(
            format: "#%02X%02X%02X",
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
    }
}
