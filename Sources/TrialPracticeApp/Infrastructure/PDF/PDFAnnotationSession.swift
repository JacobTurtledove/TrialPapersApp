import Combine
import Foundation
import PDFKit

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

enum PDFAnnotationPersistenceError: LocalizedError {
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
