import AppKit

enum PDFDrawingTool: Equatable {
    case none
    case pen(Int)
    case eraser
}

struct PDFPenConfiguration: Equatable {
    var colorHex: String
    var lineWidth: Double

    var nsColor: NSColor {
        NSColor(hexRGB: colorHex) ?? .black
    }
}

struct PDFInkStroke: Identifiable, Equatable {
    let id: String
    var points: [NSPoint]
    var colorHex: String
    var lineWidth: CGFloat

    init(points: [NSPoint], colorHex: String, lineWidth: CGFloat) {
        id = "TrialPracticeAppInk:\(UUID().uuidString)"
        self.points = points
        self.colorHex = colorHex
        self.lineWidth = lineWidth
    }
}
