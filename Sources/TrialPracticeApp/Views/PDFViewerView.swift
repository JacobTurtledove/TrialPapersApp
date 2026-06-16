import PDFKit
import SwiftUI

enum PDFPageSelection: Equatable {
    case all
    case questions(before: Int)
    case solutions(from: Int)
}

func loadPDFDocument(url: URL, selection: PDFPageSelection) -> PDFDocument? {
    guard let source = PDFDocument(url: url) else { return nil }
    let range: Range<Int>
    switch selection {
    case .all:
        return source
    case .questions(let startPage):
        range = 0..<max(0, min(source.pageCount, startPage - 1))
    case .solutions(let startPage):
        range = max(0, min(source.pageCount, startPage - 1))..<source.pageCount
    }
    guard !range.isEmpty else { return nil }
    let result = PDFDocument()
    for index in range {
        guard let page = source.page(at: index) else { return nil }
        result.insert(page, at: result.pageCount)
    }
    return result
}

@MainActor
final class PDFViewerController: ObservableObject {
    private weak var pdfView: PDFView?
    private var captureOverlay: PDFCaptureOverlayView?
    private var captureIsEnabled = false

    func attach(_ pdfView: PDFView) {
        self.pdfView = pdfView
        if captureIsEnabled {
            installCaptureOverlay(resetSelection: captureOverlay == nil)
        }
    }

    func zoomIn() {
        guard let pdfView else { return }
        pdfView.scaleFactor = min(pdfView.scaleFactor * 1.2, pdfView.maxScaleFactor)
    }

    func zoomOut() {
        guard let pdfView else { return }
        pdfView.scaleFactor = max(pdfView.scaleFactor / 1.2, pdfView.minScaleFactor)
    }

    func fitWidth() {
        pdfView?.autoScales = true
    }

    func beginCapture(resetSelection: Bool = true) {
        captureIsEnabled = true
        installCaptureOverlay(resetSelection: resetSelection)
    }

    func endCapture() {
        captureIsEnabled = false
        captureOverlay?.removeFromSuperview()
        captureOverlay = nil
    }

    func captureRange() -> PDFCaptureRange? {
        captureOverlay?.captureRange()
    }

    private func installCaptureOverlay(resetSelection: Bool) {
        guard let pdfView, let documentView = pdfView.documentView else { return }

        let overlay: PDFCaptureOverlayView
        if let captureOverlay, captureOverlay.superview === documentView {
            overlay = captureOverlay
        } else {
            captureOverlay?.removeFromSuperview()
            overlay = PDFCaptureOverlayView(pdfView: pdfView)
            overlay.frame = documentView.bounds
            overlay.autoresizingMask = [.width, .height]
            documentView.addSubview(overlay)
            captureOverlay = overlay
        }

        overlay.frame = documentView.bounds
        if resetSelection {
            overlay.resetToVisibleMiddleThird()
        }
    }
}

struct PDFViewerView: NSViewRepresentable {
    let url: URL
    var selection: PDFPageSelection = .all
    var pageSelectionEnabled = false
    var onPageSelected: ((Int) -> Void)?
    @ObservedObject var controller: PDFViewerController

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SelectablePDFView {
        let pdfView = SelectablePDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 5
        pdfView.autoScales = true
        pdfView.pageSelectionEnabled = pageSelectionEnabled
        pdfView.onPageSelected = onPageSelected
        controller.attach(pdfView)
        loadDocument(into: pdfView, context: context)
        return pdfView
    }

    func updateNSView(_ pdfView: SelectablePDFView, context: Context) {
        controller.attach(pdfView)
        pdfView.pageSelectionEnabled = pageSelectionEnabled
        pdfView.onPageSelected = onPageSelected
        if context.coordinator.loadedURL != url ||
            context.coordinator.loadedSelection != selection {
            loadDocument(into: pdfView, context: context)
        }
    }

    private func loadDocument(into pdfView: PDFView, context: Context) {
        pdfView.document = loadPDFDocument(url: url, selection: selection)
        pdfView.autoScales = true
        context.coordinator.loadedURL = url
        context.coordinator.loadedSelection = selection
        DispatchQueue.main.async {
            controller.attach(pdfView)
        }
    }

    final class Coordinator {
        var loadedURL: URL?
        var loadedSelection: PDFPageSelection?
    }
}

final class SelectablePDFView: PDFView {
    var pageSelectionEnabled = false
    var onPageSelected: ((Int) -> Void)?

    override func mouseDown(with event: NSEvent) {
        guard pageSelectionEnabled,
              let document,
              let page = page(for: convert(event.locationInWindow, from: nil), nearest: true)
        else {
            super.mouseDown(with: event)
            return
        }
        onPageSelected?(document.index(for: page) + 1)
    }
}

private final class PDFCaptureOverlayView: NSView {
    private weak var pdfView: PDFView?
    private var upperBoundaryY: CGFloat = 0
    private var lowerBoundaryY: CGFloat = 0
    private var draggedBoundary: DraggedBoundary?

    private enum DraggedBoundary {
        case upper
        case lower
    }

    init(pdfView: PDFView) {
        self.pdfView = pdfView
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        superview?.isFlipped ?? true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let tolerance: CGFloat = 14
        if abs(point.y - upperBoundaryY) <= tolerance ||
            abs(point.y - lowerBoundaryY) <= tolerance {
            return self
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        draggedBoundary = abs(point.y - upperBoundaryY) <= abs(point.y - lowerBoundaryY)
            ? .upper
            : .lower
        updateDraggedBoundary(to: point.y)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateDraggedBoundary(to: point.y)
    }

    override func mouseUp(with event: NSEvent) {
        draggedBoundary = nil
    }

    override func resetCursorRects() {
        let tolerance: CGFloat = 14
        addCursorRect(
            NSRect(
                x: bounds.minX,
                y: upperBoundaryY - tolerance,
                width: bounds.width,
                height: tolerance * 2
            ),
            cursor: .resizeUpDown
        )
        addCursorRect(
            NSRect(
                x: bounds.minX,
                y: lowerBoundaryY - tolerance,
                width: bounds.width,
                height: tolerance * 2
            ),
            cursor: .resizeUpDown
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let upper = visuallyUpperY
        let lower = visuallyLowerY
        let dimColor = NSColor.black.withAlphaComponent(0.32)
        dimColor.setFill()

        if isFlipped {
            NSRect(
                x: bounds.minX,
                y: bounds.minY,
                width: bounds.width,
                height: max(0, upper - bounds.minY)
            ).fill()
            NSRect(
                x: bounds.minX,
                y: lower,
                width: bounds.width,
                height: max(0, bounds.maxY - lower)
            ).fill()
        } else {
            NSRect(
                x: bounds.minX,
                y: bounds.minY,
                width: bounds.width,
                height: max(0, lower - bounds.minY)
            ).fill()
            NSRect(
                x: bounds.minX,
                y: upper,
                width: bounds.width,
                height: max(0, bounds.maxY - upper)
            ).fill()
        }

        drawBoundary(at: upperBoundaryY, label: "Top")
        drawBoundary(at: lowerBoundaryY, label: "Bottom")
    }

    func resetToVisibleMiddleThird() {
        guard let documentView = superview else { return }
        let visibleRect = documentView.visibleRect
        if isFlipped {
            upperBoundaryY = visibleRect.minY + visibleRect.height / 3
            lowerBoundaryY = visibleRect.minY + visibleRect.height * 2 / 3
        } else {
            upperBoundaryY = visibleRect.maxY - visibleRect.height / 3
            lowerBoundaryY = visibleRect.maxY - visibleRect.height * 2 / 3
        }
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    func captureRange() -> PDFCaptureRange? {
        guard
            let pdfView,
            let document = pdfView.document,
            let documentView = superview
        else {
            return nil
        }

        let x = documentView.visibleRect.midX
        guard
            let upperLocation = pageLocation(
                at: NSPoint(x: x, y: visuallyUpperY),
                pdfView: pdfView,
                documentView: documentView,
                document: document
            ),
            let lowerLocation = pageLocation(
                at: NSPoint(x: x, y: visuallyLowerY),
                pdfView: pdfView,
                documentView: documentView,
                document: document
            )
        else {
            return nil
        }

        guard upperLocation.pageIndex <= lowerLocation.pageIndex else {
            return nil
        }
        return PDFCaptureRange(
            startPage: upperLocation.pageIndex,
            endPage: lowerLocation.pageIndex,
            topBoundary: upperLocation.normalizedFromTop,
            bottomBoundary: lowerLocation.normalizedFromTop
        )
    }

    private var visuallyUpperY: CGFloat {
        isFlipped
            ? min(upperBoundaryY, lowerBoundaryY)
            : max(upperBoundaryY, lowerBoundaryY)
    }

    private var visuallyLowerY: CGFloat {
        isFlipped
            ? max(upperBoundaryY, lowerBoundaryY)
            : min(upperBoundaryY, lowerBoundaryY)
    }

    private func updateDraggedBoundary(to proposedY: CGFloat) {
        guard let draggedBoundary else { return }
        let spacing: CGFloat = 12
        let clampedY = max(bounds.minY, min(bounds.maxY, proposedY))

        switch draggedBoundary {
        case .upper:
            if isFlipped {
                upperBoundaryY = min(clampedY, lowerBoundaryY - spacing)
            } else {
                upperBoundaryY = max(clampedY, lowerBoundaryY + spacing)
            }
        case .lower:
            if isFlipped {
                lowerBoundaryY = max(clampedY, upperBoundaryY + spacing)
            } else {
                lowerBoundaryY = min(clampedY, upperBoundaryY - spacing)
            }
        }

        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    private func drawBoundary(at y: CGFloat, label: String) {
        let color = NSColor.controlAccentColor
        color.setFill()
        NSRect(x: bounds.minX, y: y - 1.5, width: bounds.width, height: 3).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let text = NSAttributedString(string: label, attributes: attributes)
        let textSize = text.size()
        let badgeRect = NSRect(
            x: bounds.minX + 12,
            y: y - textSize.height / 2 - 4,
            width: textSize.width + 14,
            height: textSize.height + 8
        )
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 7, yRadius: 7)
        color.setFill()
        badge.fill()
        text.draw(
            at: NSPoint(
                x: badgeRect.minX + 7,
                y: badgeRect.minY + 4
            )
        )
    }

    private func pageLocation(
        at documentPoint: NSPoint,
        pdfView: PDFView,
        documentView: NSView,
        document: PDFDocument
    ) -> (pageIndex: Int, normalizedFromTop: Double)? {
        let viewPoint = pdfView.convert(documentPoint, from: documentView)
        guard let page = pdfView.page(for: viewPoint, nearest: true) else {
            return nil
        }
        let pagePoint = pdfView.convert(viewPoint, to: page)
        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.height > 0 else { return nil }
        let normalized = Double(
            max(
                0,
                min(1, (pageBounds.maxY - pagePoint.y) / pageBounds.height)
            )
        )
        return (document.index(for: page), normalized)
    }
}
