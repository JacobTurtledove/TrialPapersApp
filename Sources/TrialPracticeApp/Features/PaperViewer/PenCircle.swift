import AppKit
import SwiftUI

struct PenCircle: View {
    let colorHex: String
    let lineWidth: Double

    private var diameter: CGFloat {
        CGFloat(min(24, max(8, lineWidth + 6)))
    }

    var body: some View {
        Circle()
            .fill(Color(nsColor: NSColor(hexRGB: colorHex) ?? .black))
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle()
                    .stroke(Color.primary.opacity(0.18), lineWidth: 1)
            }
            .frame(width: 28, height: 24)
    }
}
