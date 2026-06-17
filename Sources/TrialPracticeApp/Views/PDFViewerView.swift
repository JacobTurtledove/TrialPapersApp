import PDFKit
import SwiftUI

enum PDFPageSelection: Equatable {
    case all
    case questions(before: Int)
    case solutions(from: Int)
}

func loadPDFDocument(url: URL, selection: PDFPageSelection) -> PDFDocument? {
    guard let source = PDFDocument(url: url) else { return nil }
    return loadPDFDocument(from: source, selection: selection)
}

func loadPDFDocument(from source: PDFDocument, selection: PDFPageSelection) -> PDFDocument? {
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
final class PDFAnnotationSession: ObservableObject {
    @Published private(set) var document: PDFDocument?
    private(set) var url: URL?
    private var isDirty = false

    func load(url: URL?) {
        guard self.url != url else { return }
        self.url = url
        document = url.flatMap { PDFDocument(url: $0) }
        isDirty = false
    }

    func markDirty() {
        isDirty = true
    }

    func saveIfNeeded() throws {
        guard isDirty, let document, let url else { return }
        guard document.write(to: url) else {
            throw PDFAnnotationPersistenceError.couldNotWriteDocument
        }
        isDirty = false
    }
}

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

extension PDFPageSelection {
    func sourcePageIndex(forDisplayedPage displayedPageIndex: Int) -> Int? {
        guard displayedPageIndex >= 0 else { return nil }
        switch self {
        case .all, .questions:
            return displayedPageIndex
        case .solutions(let startPage):
            return displayedPageIndex + max(0, startPage - 1)
        }
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

struct PDFPagePreviewView: NSViewRepresentable {
    let url: URL
    let pageNumber: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePage
        pdfView.displaysPageBreaks = false
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.minScaleFactor = 0.1
        pdfView.maxScaleFactor = 3
        pdfView.autoScales = true
        loadDocument(into: pdfView, context: context)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if context.coordinator.loadedURL != url {
            loadDocument(into: pdfView, context: context)
        } else if context.coordinator.loadedPageNumber != pageNumber {
            goToSelectedPage(in: pdfView, context: context)
        }
    }

    private func loadDocument(into pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(url: url)
        context.coordinator.loadedURL = url
        context.coordinator.loadedPageNumber = nil
        goToSelectedPage(in: pdfView, context: context)
    }

    private func goToSelectedPage(in pdfView: PDFView, context: Context) {
        guard let document = pdfView.document else { return }
        let index = min(max(pageNumber - 1, 0), max(document.pageCount - 1, 0))
        guard let page = document.page(at: index) else { return }
        pdfView.go(to: page)
        pdfView.autoScales = true
        context.coordinator.loadedPageNumber = pageNumber
    }

    final class Coordinator {
        var loadedURL: URL?
        var loadedPageNumber: Int?
    }
}

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

    private func makeInkAnnotation(
        path: NSBezierPath,
        configuration: PDFPenConfiguration,
        identifier: String
    ) -> PDFAnnotation {
        let lineWidth = CGFloat(configuration.lineWidth)
        var bounds = path.controlPointBounds.insetBy(dx: -lineWidth * 1.5, dy: -lineWidth * 1.5)
        if bounds.isEmpty {
            let point = path.currentPoint
            bounds = NSRect(
                x: point.x - lineWidth,
                y: point.y - lineWidth,
                width: lineWidth * 2,
                height: lineWidth * 2
            )
        }
        let annotation = PDFAnnotation(
            bounds: bounds,
            forType: .ink,
            withProperties: nil
        )
        let border = PDFBorder()
        border.lineWidth = lineWidth
        annotation.border = border
        annotation.color = configuration.nsColor
        annotation.contents = identifier
        annotation.userName = "TrialPracticeApp"
        annotation.shouldPrint = true
        guard let localPath = path.copy() as? NSBezierPath else {
            return annotation
        }
        var transform = AffineTransform()
        transform.translate(x: -bounds.minX, y: -bounds.minY)
        localPath.transform(using: transform)
        annotation.add(localPath)
        return annotation
    }

    private func isInkAnnotation(_ annotation: PDFAnnotation) -> Bool {
        annotation.type == PDFAnnotationSubtype.ink.rawValue
    }

    func commitInkStroke(_ stroke: PDFInkStroke, toDisplayedPage displayedPage: PDFPage) {
        guard
            let sourceDocument,
            let document,
            document.index(for: displayedPage) >= 0,
            let sourcePageIndex = pageSelection.sourcePageIndex(
                forDisplayedPage: document.index(for: displayedPage)
            ),
            let sourcePage = sourceDocument.page(at: sourcePageIndex)
        else {
            onAnnotationError?(PDFAnnotationPersistenceError.couldNotOpenDocument.localizedDescription)
            return
        }

        let pagePath = smoothedPath(from: stroke.points)
        pagePath.lineWidth = stroke.lineWidth
        pagePath.lineCapStyle = .round
        pagePath.lineJoinStyle = .round

        let annotation = makeInkAnnotation(
            path: pagePath,
            configuration: PDFPenConfiguration(
                colorHex: stroke.colorHex,
                lineWidth: Double(stroke.lineWidth)
            ),
            identifier: stroke.id
        )
        sourcePage.addAnnotation(annotation)

        if displayedPage !== sourcePage {
            displayedPage.addAnnotation(annotation.copy() as? PDFAnnotation ?? annotation)
        }

        onAnnotationsChanged?()
        needsDisplay = true
    }

    func eraseInkAnnotation(onDisplayedPage displayedPage: PDFPage, at pagePoint: NSPoint) {
        guard
            let sourceDocument,
            let document,
            document.index(for: displayedPage) >= 0,
            let sourcePageIndex = pageSelection.sourcePageIndex(
                forDisplayedPage: document.index(for: displayedPage)
            ),
            let sourcePage = sourceDocument.page(at: sourcePageIndex)
        else {
            return
        }

        let eraserRadius: CGFloat = 8
        guard let displayedTarget = displayedPage.annotations.reversed().first(where: { annotation in
            isInkAnnotation(annotation) &&
                inkAnnotation(annotation, isNear: pagePoint, radius: eraserRadius)
        }) else {
            return
        }

        let marker = displayedTarget.contents
        displayedPage.removeAnnotation(displayedTarget)

        if let sourceTarget = sourcePage.annotations.reversed().first(where: { annotation in
            guard isInkAnnotation(annotation) else { return false }
            if let marker, !marker.isEmpty, annotation.contents == marker {
                return true
            }
            return inkAnnotation(annotation, isNear: pagePoint, radius: eraserRadius)
        }) {
            sourcePage.removeAnnotation(sourceTarget)
        }

        onAnnotationsChanged?()
        needsDisplay = true
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
private final class PDFInkOverlayProvider: NSObject, @preconcurrency PDFPageOverlayViewProvider {
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

private func smoothedPath(from points: [NSPoint]) -> NSBezierPath {
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

private func decimatedPoints(_ points: [NSPoint], minimumDistance: CGFloat) -> [NSPoint] {
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

private func inkAnnotation(_ annotation: PDFAnnotation, isNear point: NSPoint, radius: CGFloat) -> Bool {
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

private enum PDFAnnotationPersistenceError: LocalizedError {
    case couldNotOpenDocument
    case couldNotWriteDocument

    var errorDescription: String? {
        switch self {
        case .couldNotOpenDocument:
            "The PDF could not be opened for annotation."
        case .couldNotWriteDocument:
            "The PDF annotations could not be saved."
        }
    }
}

private extension NSRect {
    func distance(to other: NSRect) -> CGFloat {
        abs(minX - other.minX) +
            abs(minY - other.minY) +
            abs(width - other.width) +
            abs(height - other.height)
    }
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
