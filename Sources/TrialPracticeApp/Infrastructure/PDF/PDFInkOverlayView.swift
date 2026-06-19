import AppKit
import PDFKit

final class PDFInkOverlayView: NSView {
    weak var pdfView: PDFView?
    weak var page: PDFPage?
    var drawingTool: PDFDrawingTool = .none {
        didSet {
            if drawingTool == .none {
                currentStroke = nil
                previousEraserPoint = nil
            }
            needsDisplay = true
        }
    }
    var penConfigurations: [PDFPenConfiguration] = []
    var onStrokeFinished: ((PDFPage, PDFInkStroke) -> Void)?
    var onEraseAlongPageSegment: ((PDFPage, NSPoint, NSPoint) -> Void)?
    private var currentStroke: PDFInkStroke?
    private var previousEraserPoint: NSPoint?

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
            previousEraserPoint = pagePoint
            onEraseAlongPageSegment?(page, pagePoint, pagePoint)
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
            let startPoint = previousEraserPoint ?? pagePoint
            onEraseAlongPageSegment?(page, startPoint, pagePoint)
            previousEraserPoint = pagePoint
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            currentStroke = nil
            previousEraserPoint = nil
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
