import Combine
import Foundation
import PDFKit

enum PDFViewportDocumentRole: String, CaseIterable, Codable {
    case questions
    case solutions
}

struct PDFViewportPosition: Codable, Equatable {
    var pageIndex: Int
    var pointX: Double
    var pointY: Double
}

@MainActor
final class PDFViewerViewportStore: ObservableObject {
    private let userDefaults: UserDefaults
    private let storageKey = "pdfViewer.viewportPositions.v1"
    private var positions: [String: PDFViewportPosition]
    private var pendingPersistenceTask: Task<Void, Never>?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(
               [String: PDFViewportPosition].self,
               from: data
           ) {
            positions = decoded
        } else {
            positions = [:]
        }
    }

    func position(
        for paperID: UUID,
        role: PDFViewportDocumentRole
    ) -> PDFViewportPosition? {
        positions[key(for: paperID, role: role)]
    }

    func setPosition(
        _ position: PDFViewportPosition,
        for paperID: UUID,
        role: PDFViewportDocumentRole
    ) {
        positions[key(for: paperID, role: role)] = position
        schedulePersistence()
    }

    func clearPositions(for paperID: UUID) {
        PDFViewportDocumentRole.allCases.forEach {
            positions.removeValue(forKey: key(for: paperID, role: $0))
        }
        persistImmediately()
    }

    func flushPendingPersistence() {
        persistImmediately()
    }

    private func key(for paperID: UUID, role: PDFViewportDocumentRole) -> String {
        "\(paperID.uuidString).\(role.rawValue)"
    }

    private func schedulePersistence() {
        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.persistImmediately()
        }
    }

    private func persistImmediately() {
        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = nil
        guard let data = try? JSONEncoder().encode(positions) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
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
