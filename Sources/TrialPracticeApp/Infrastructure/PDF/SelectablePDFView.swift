import AppKit
import PDFKit

final class SelectablePDFView: PDFView {
    var sourceURL: URL?
    weak var sourceDocument: PDFDocument?
    var pageSelection: PDFPageSelection = .all
    var drawingTool: PDFDrawingTool = .none {
        didSet {
            configureForCurrentDrawingTool()
            updateInkOverlayConfiguration()
        }
    }
    var penConfigurations: [PDFPenConfiguration] = [] {
        didSet {
            updateInkOverlayConfiguration()
        }
    }
    var pageSelectionEnabled = false
    var onPageSelected: ((Int) -> Void)?
    var onAnnotationsChanged: (() -> Void)?
    var onAnnotationError: ((String) -> Void)?
    private var inkOverlayProvider: PDFInkOverlayProvider?

    private var isDrawingMode: Bool {
        drawingTool != .none
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    func configureForCurrentDrawingTool() {
        setCurrentSelection(nil, animate: false)
        highlightedSelections = nil
        if isDrawingMode {
            window?.makeFirstResponder(self)
        }
    }

    override func selectAll(_ sender: Any?) {
        configureForCurrentDrawingTool()
    }

    override func copy(_ sender: Any?) {
        configureForCurrentDrawingTool()
    }

    func installInkOverlayProviderIfNeeded() {
        if inkOverlayProvider == nil {
            let provider = PDFInkOverlayProvider(pdfView: self)
            inkOverlayProvider = provider
            pageOverlayViewProvider = provider
        }
    }

    func updateInkOverlayConfiguration() {
        inkOverlayProvider?.updateVisibleOverlays()
    }

    override func mouseDown(with event: NSEvent) {
        if isDrawingMode {
            configureForCurrentDrawingTool()
            return
        }

        guard pageSelectionEnabled,
              let document,
              let page = page(for: convert(event.locationInWindow, from: nil), nearest: true)
        else {
            configureForCurrentDrawingTool()
            return
        }
        onPageSelected?(document.index(for: page) + 1)
    }

    override func mouseDragged(with event: NSEvent) {
        configureForCurrentDrawingTool()
    }

    override func mouseUp(with event: NSEvent) {
        configureForCurrentDrawingTool()
    }
}
