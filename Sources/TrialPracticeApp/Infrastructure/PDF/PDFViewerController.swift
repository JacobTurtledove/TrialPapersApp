import Combine
import PDFKit

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
