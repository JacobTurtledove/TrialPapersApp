import PDFKit
import SwiftUI

struct PDFViewerView: NSViewRepresentable {
    let url: URL
    var sourceDocument: PDFDocument?
    var selection: PDFPageSelection = .all
    var viewportPosition: PDFViewportPosition?
    var drawingTool: PDFDrawingTool = .none
    var penConfigurations: [PDFPenConfiguration] = []
    var pageSelectionEnabled = false
    var onPageSelected: ((Int) -> Void)?
    var onViewportChanged: ((PDFViewportPosition) -> Void)?
    var onAnnotationsChanged: (() -> Void)?
    var onAnnotationError: ((String) -> Void)?
    @ObservedObject var controller: PDFViewerController

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SelectablePDFView {
        let pdfView = SelectablePDFView()
        context.coordinator.isActive = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 5
        pdfView.autoScales = true
        pdfView.sourceURL = url
        pdfView.sourceDocument = sourceDocument
        pdfView.pageSelection = selection
        context.coordinator.viewportPosition = viewportPosition
        context.coordinator.onViewportChanged = onViewportChanged
        pdfView.drawingTool = drawingTool
        pdfView.penConfigurations = penConfigurations
        pdfView.pageSelectionEnabled = pageSelectionEnabled
        pdfView.onPageSelected = onPageSelected
        pdfView.onAnnotationsChanged = onAnnotationsChanged
        pdfView.onAnnotationError = onAnnotationError
        pdfView.configureForCurrentDrawingTool()
        pdfView.installInkOverlayProviderIfNeeded()
        controller.attach(pdfView)
        loadDocument(into: pdfView, context: context)
        return pdfView
    }

    func updateNSView(_ pdfView: SelectablePDFView, context: Context) {
        context.coordinator.isActive = true
        controller.attach(pdfView)
        pdfView.sourceURL = url
        pdfView.sourceDocument = sourceDocument
        pdfView.pageSelection = selection
        context.coordinator.viewportPosition = viewportPosition
        context.coordinator.onViewportChanged = onViewportChanged
        pdfView.drawingTool = drawingTool
        pdfView.penConfigurations = penConfigurations
        pdfView.pageSelectionEnabled = pageSelectionEnabled
        pdfView.onPageSelected = onPageSelected
        pdfView.onAnnotationsChanged = onAnnotationsChanged
        pdfView.onAnnotationError = onAnnotationError
        pdfView.configureForCurrentDrawingTool()
        pdfView.updateInkOverlayConfiguration()
        if context.coordinator.loadedURL != url ||
            context.coordinator.loadedSelection != selection ||
            context.coordinator.loadedSourceDocument !== sourceDocument {
            loadDocument(into: pdfView, context: context)
        }
    }

    static func dismantleNSView(_ pdfView: SelectablePDFView, coordinator: Coordinator) {
        coordinator.isActive = false
        coordinator.cancelPendingViewportSave()
        coordinator.stopObserving()
        coordinator.onViewportChanged = nil
    }

    private func loadDocument(into pdfView: SelectablePDFView, context: Context) {
        if context.coordinator.loadedURL != nil {
            context.coordinator.captureViewport(from: pdfView)
        }

        if let sourceDocument {
            pdfView.document = loadPDFDocument(from: sourceDocument, selection: selection)
        } else {
            pdfView.document = loadPDFDocument(url: url, selection: selection)
        }
        pdfView.autoScales = true
        context.coordinator.loadedURL = url
        context.coordinator.loadedSelection = selection
        context.coordinator.loadedSourceDocument = sourceDocument
        DispatchQueue.main.async {
            guard context.coordinator.isActive else { return }
            controller.attach(pdfView)
            context.coordinator.startObserving(pdfView)
            context.coordinator.restoreViewportIfNeeded(in: pdfView)
        }
    }

    @MainActor
    final class Coordinator {
        var loadedURL: URL?
        var loadedSelection: PDFPageSelection?
        weak var loadedSourceDocument: PDFDocument?
        var isActive = true
        var viewportPosition: PDFViewportPosition?
        var onViewportChanged: ((PDFViewportPosition) -> Void)?
        private var observedClipView: NSClipView?
        private var observerTokens: [NSObjectProtocol] = []
        private var pendingViewportSave: DispatchWorkItem?
        private var isRestoringViewport = false

        func startObserving(_ pdfView: PDFView) {
            guard isActive else { return }
            let clipView = pdfView.documentView?.enclosingScrollView?.contentView
            guard observedClipView !== clipView else { return }

            stopObserving()
            observedClipView = clipView
            clipView?.postsBoundsChangedNotifications = true

            if let clipView {
                observerTokens.append(
                    NotificationCenter.default.addObserver(
                        forName: NSView.boundsDidChangeNotification,
                        object: clipView,
                        queue: .main
                    ) { [weak self, weak pdfView] _ in
                        Task { @MainActor [weak self, weak pdfView] in
                            guard let pdfView else { return }
                            self?.scheduleViewportSave(from: pdfView)
                        }
                    }
                )
            }
        }

        func stopObserving() {
            pendingViewportSave?.cancel()
            pendingViewportSave = nil
            observerTokens.forEach(NotificationCenter.default.removeObserver)
            observerTokens = []
            observedClipView = nil
        }

        func restoreViewportIfNeeded(in pdfView: PDFView) {
            guard isActive,
                  let viewportPosition,
                  let document = pdfView.document,
                  document.pageCount > 0
            else { return }

            let pageIndex = min(
                max(0, viewportPosition.pageIndex),
                document.pageCount - 1
            )
            guard let page = document.page(at: pageIndex) else { return }

            isRestoringViewport = true
            let destination = PDFDestination(
                page: page,
                at: CGPoint(
                    x: viewportPosition.pointX,
                    y: viewportPosition.pointY
                )
            )
            pdfView.go(to: destination)

            DispatchQueue.main.async { [weak self] in
                self?.isRestoringViewport = false
            }
        }

        func captureViewport(from pdfView: PDFView) {
            pendingViewportSave?.cancel()
            pendingViewportSave = nil
            guard isActive,
                  !isRestoringViewport,
                  let position = currentPosition(in: pdfView)
            else { return }
            onViewportChanged?(position)
        }

        private func scheduleViewportSave(from pdfView: PDFView) {
            guard isActive,
                  observedClipView != nil,
                  !isRestoringViewport
            else { return }
            pendingViewportSave?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak pdfView] in
                guard let pdfView else { return }
                self?.captureViewport(from: pdfView)
            }
            pendingViewportSave = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
        }

        func cancelPendingViewportSave() {
            pendingViewportSave?.cancel()
            pendingViewportSave = nil
        }

        private func currentPosition(in pdfView: PDFView) -> PDFViewportPosition? {
            guard let document = pdfView.document else { return nil }
            let destination = pdfView.currentDestination
            guard let page = destination?.page ?? pdfView.currentPage else {
                return nil
            }

            let pageIndex = document.index(for: page)
            guard pageIndex >= 0 else { return nil }

            let point = destination?.point ?? .zero
            return PDFViewportPosition(
                pageIndex: pageIndex,
                pointX: Double(point.x),
                pointY: Double(point.y)
            )
        }
    }
}
