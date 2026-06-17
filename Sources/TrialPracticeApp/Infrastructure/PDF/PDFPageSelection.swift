enum PDFPageSelection: Equatable {
    case all
    case questions(before: Int)
    case solutions(from: Int)
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
