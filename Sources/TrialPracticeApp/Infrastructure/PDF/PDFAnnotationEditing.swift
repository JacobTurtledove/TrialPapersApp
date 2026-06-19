import AppKit
import PDFKit

extension SelectablePDFView {
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
        guard let type = annotation.type else { return false }
        let normalizedType = type.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalizedType.caseInsensitiveCompare("Ink") == .orderedSame
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
        eraseInkAnnotation(onDisplayedPage: displayedPage, from: pagePoint, to: pagePoint)
    }

    func eraseInkAnnotation(onDisplayedPage displayedPage: PDFPage, from startPoint: NSPoint, to endPoint: NSPoint) {
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
                inkAnnotation(annotation, intersectsSegmentFrom: startPoint, to: endPoint, radius: eraserRadius)
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
            return inkAnnotation(annotation, intersectsSegmentFrom: startPoint, to: endPoint, radius: eraserRadius)
        }) {
            sourcePage.removeAnnotation(sourceTarget)
        }

        onAnnotationsChanged?()
        needsDisplay = true
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
