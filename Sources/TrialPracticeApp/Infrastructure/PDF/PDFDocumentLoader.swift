import PDFKit

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
        guard
            let page = source.page(at: index),
            let copiedPage = page.copy() as? PDFPage
        else {
            return nil
        }
        result.insert(copiedPage, at: result.pageCount)
    }
    return result
}
