import AppKit
import PDFKit

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

@MainActor
final class PDFInkOverlayProvider: NSObject, @preconcurrency PDFPageOverlayViewProvider {
    private weak var pdfView: SelectablePDFView?
    private var overlays: [PDFPage: PDFInkOverlayView] = [:]

    init(pdfView: SelectablePDFView) {
        self.pdfView = pdfView
    }

    func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> NSView? {
        if let existing = overlays[page] {
            configure(existing, page: page, pdfView: view)
            return existing
        }

        let overlay = PDFInkOverlayView()
        configure(overlay, page: page, pdfView: view)
        overlays[page] = overlay
        return overlay
    }

    func pdfView(_ pdfView: PDFView, willEndDisplayingOverlayView overlayView: NSView, for page: PDFPage) {
        overlays[page] = nil
    }

    func updateVisibleOverlays() {
        for (page, overlay) in overlays {
            configure(overlay, page: page, pdfView: overlay.pdfView)
            overlay.needsDisplay = true
        }
    }

    private func configure(_ overlay: PDFInkOverlayView, page: PDFPage, pdfView view: PDFView?) {
        guard let owner = pdfView else { return }
        overlay.pdfView = view ?? owner
        overlay.page = page
        overlay.drawingTool = owner.drawingTool
        overlay.penConfigurations = owner.penConfigurations
        overlay.onStrokeFinished = { [weak owner] page, stroke in
            owner?.commitInkStroke(stroke, toDisplayedPage: page)
        }
        overlay.onEraseAtPagePoint = { [weak owner] page, point in
            owner?.eraseInkAnnotation(onDisplayedPage: page, at: point)
        }
    }
}

private final class PDFInkOverlayView: NSView {
    weak var pdfView: PDFView?
    weak var page: PDFPage?
    var drawingTool: PDFDrawingTool = .none {
        didSet {
            if drawingTool == .none {
                currentStroke = nil
            }
            needsDisplay = true
        }
    }
    var penConfigurations: [PDFPenConfiguration] = []
    var onStrokeFinished: ((PDFPage, PDFInkStroke) -> Void)?
    var onEraseAtPagePoint: ((PDFPage, NSPoint) -> Void)?
    private var currentStroke: PDFInkStroke?

    override var isFlipped: Bool {
        false
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        drawingTool == .none ? nil : self
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let page, let pagePoint = pagePoint(from: event) else { return }

        switch drawingTool {
        case .none:
            break
        case .pen(let index):
            guard penConfigurations.indices.contains(index) else { return }
            let config = penConfigurations[index]
            currentStroke = PDFInkStroke(
                points: [pagePoint],
                colorHex: config.colorHex,
                lineWidth: CGFloat(config.lineWidth)
            )
            needsDisplay = true
        case .eraser:
            onEraseAtPagePoint?(page, pagePoint)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let page, let pagePoint = pagePoint(from: event) else { return }

        switch drawingTool {
        case .none:
            break
        case .pen:
            currentStroke?.points.append(pagePoint)
            needsDisplay = true
        case .eraser:
            onEraseAtPagePoint?(page, pagePoint)
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            currentStroke = nil
            needsDisplay = true
        }

        guard let page else { return }
        guard case .pen = drawingTool, var stroke = currentStroke else { return }

        if let pagePoint = pagePoint(from: event) {
            stroke.points.append(pagePoint)
        }
        stroke.points = decimatedPoints(stroke.points, minimumDistance: 1.5)

        if stroke.points.count > 1 {
            onStrokeFinished?(page, stroke)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let stroke = currentStroke else { return }

        (NSColor(hexRGB: stroke.colorHex) ?? .black).setStroke()
        let path = smoothedPath(from: stroke.points)
        path.lineWidth = stroke.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private func pagePoint(from event: NSEvent) -> NSPoint? {
        guard let pdfView, let page else { return nil }
        let viewPoint = pdfView.convert(event.locationInWindow, from: nil)
        return pdfView.convert(viewPoint, to: page)
    }
}

func smoothedPath(from points: [NSPoint]) -> NSBezierPath {
    let path = NSBezierPath()
    guard let first = points.first else { return path }
    path.move(to: first)

    guard points.count > 2 else {
        for point in points.dropFirst() {
            path.line(to: point)
        }
        return path
    }

    for index in 1..<(points.count - 1) {
        let current = points[index]
        let next = points[index + 1]
        let mid = NSPoint(
            x: (current.x + next.x) / 2,
            y: (current.y + next.y) / 2
        )
        path.curve(to: mid, controlPoint1: current, controlPoint2: current)
    }

    if let last = points.last {
        path.line(to: last)
    }
    return path
}

func decimatedPoints(_ points: [NSPoint], minimumDistance: CGFloat) -> [NSPoint] {
    guard points.count > 2 else { return points }

    var result: [NSPoint] = []
    var previous: NSPoint?

    for point in points {
        if let previous {
            let distance = hypot(point.x - previous.x, point.y - previous.y)
            if distance < minimumDistance { continue }
        }
        result.append(point)
        previous = point
    }

    if result.last != points.last, let last = points.last {
        result.append(last)
    }
    return result
}

func inkAnnotation(_ annotation: PDFAnnotation, isNear point: NSPoint, radius: CGFloat) -> Bool {
    guard annotation.bounds.insetBy(dx: -radius, dy: -radius).contains(point) else {
        return false
    }

    guard let paths = annotation.paths, !paths.isEmpty else {
        return true
    }

    for path in paths {
        let pagePoints = approximatePoints(from: path).map {
            NSPoint(
                x: $0.x + annotation.bounds.minX,
                y: $0.y + annotation.bounds.minY
            )
        }
        guard pagePoints.count > 1 else { continue }

        for index in 0..<(pagePoints.count - 1) {
            if distanceFromPointToSegment(
                point: point,
                start: pagePoints[index],
                end: pagePoints[index + 1]
            ) <= radius {
                return true
            }
        }
    }

    return false
}

private func approximatePoints(from path: NSBezierPath) -> [NSPoint] {
    var result: [NSPoint] = []
    var current = NSPoint.zero
    var points = [NSPoint](repeating: .zero, count: 3)

    for index in 0..<path.elementCount {
        let element = path.element(at: index, associatedPoints: &points)
        switch element {
        case .moveTo:
            current = points[0]
            result.append(current)
        case .lineTo:
            current = points[0]
            result.append(current)
        case .curveTo, .cubicCurveTo:
            let start = current
            let control1 = points[0]
            let control2 = points[1]
            let end = points[2]
            for step in 1...8 {
                result.append(
                    cubicBezierPoint(
                        start: start,
                        control1: control1,
                        control2: control2,
                        end: end,
                        t: CGFloat(step) / 8
                    )
                )
            }
            current = end
        case .quadraticCurveTo:
            let start = current
            let control = points[0]
            let end = points[1]
            for step in 1...8 {
                let t = CGFloat(step) / 8
                let oneMinusT = 1 - t
                result.append(
                    NSPoint(
                        x: pow(oneMinusT, 2) * start.x +
                            2 * oneMinusT * t * control.x +
                            pow(t, 2) * end.x,
                        y: pow(oneMinusT, 2) * start.y +
                            2 * oneMinusT * t * control.y +
                            pow(t, 2) * end.y
                    )
                )
            }
            current = end
        case .closePath:
            break
        @unknown default:
            break
        }
    }

    return result
}

private func cubicBezierPoint(
    start: NSPoint,
    control1: NSPoint,
    control2: NSPoint,
    end: NSPoint,
    t: CGFloat
) -> NSPoint {
    let oneMinusT = 1 - t
    let x = pow(oneMinusT, 3) * start.x +
        3 * pow(oneMinusT, 2) * t * control1.x +
        3 * oneMinusT * pow(t, 2) * control2.x +
        pow(t, 3) * end.x
    let y = pow(oneMinusT, 3) * start.y +
        3 * pow(oneMinusT, 2) * t * control1.y +
        3 * oneMinusT * pow(t, 2) * control2.y +
        pow(t, 3) * end.y
    return NSPoint(x: x, y: y)
}

private func distanceFromPointToSegment(point p: NSPoint, start a: NSPoint, end b: NSPoint) -> CGFloat {
    let dx = b.x - a.x
    let dy = b.y - a.y

    if dx == 0 && dy == 0 {
        return hypot(p.x - a.x, p.y - a.y)
    }

    let t = max(
        0,
        min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy))
    )
    let projection = NSPoint(x: a.x + t * dx, y: a.y + t * dy)
    return hypot(p.x - projection.x, p.y - projection.y)
}

extension NSColor {
    convenience init?(hexRGB: String) {
        let trimmed = hexRGB.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return nil
        }
        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexRGBString: String {
        let color = usingColorSpace(.deviceRGB) ?? self
        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }
}
