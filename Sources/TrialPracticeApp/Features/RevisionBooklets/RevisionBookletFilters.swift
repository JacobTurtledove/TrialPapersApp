enum BookletCategoryFilter: String, CaseIterable, Identifiable {
    case both = "Both Categories"
    case mistakes = "Mistakes Only"
    case unlearned = "Unlearned Only"

    var id: String { rawValue }
}

enum BookletCompletionFilter: String, CaseIterable, Identifiable {
    case incomplete = "Incomplete Only"
    case completed = "Completed Only"
    case both = "Both"

    var id: String { rawValue }
}
