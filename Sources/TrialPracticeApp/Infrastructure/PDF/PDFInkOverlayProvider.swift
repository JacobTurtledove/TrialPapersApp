import AppKit
import PDFKit

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
        overlay.onEraseAlongPageSegment = { [weak owner] page, startPoint, endPoint in
            owner?.eraseInkAnnotation(onDisplayedPage: page, from: startPoint, to: endPoint)
        }
    }
}
