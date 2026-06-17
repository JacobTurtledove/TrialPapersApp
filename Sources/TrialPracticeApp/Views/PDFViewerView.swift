import PDFKit
import SwiftUI

struct PDFViewerView: NSViewRepresentable {
    let url: URL
    var sourceDocument: PDFDocument?
    var selection: PDFPageSelection = .all
    var drawingTool: PDFDrawingTool = .none
    var penConfigurations: [PDFPenConfiguration] = []
    var pageSelectionEnabled = false
    var onPageSelected: ((Int) -> Void)?
    var onAnnotationsChanged: (() -> Void)?
    var onAnnotationError: ((String) -> Void)?
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
        pdfView.sourceURL = url
        pdfView.sourceDocument = sourceDocument
        pdfView.pageSelection = selection
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
        controller.attach(pdfView)
        pdfView.sourceURL = url
        pdfView.sourceDocument = sourceDocument
        pdfView.pageSelection = selection
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

    private func loadDocument(into pdfView: PDFView, context: Context) {
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
            controller.attach(pdfView)
        }
    }

    final class Coordinator {
        var loadedURL: URL?
        var loadedSelection: PDFPageSelection?
        weak var loadedSourceDocument: PDFDocument?
    }
}
