import PDFKit
import SwiftUI

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
