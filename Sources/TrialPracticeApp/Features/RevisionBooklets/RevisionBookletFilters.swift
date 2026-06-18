enum BookletCategoryFilter: String, CaseIterable, Identifiable {
    case both = "Both Categories"
    case mistakes = "Mistakes Only"
    case unlearned = "Unlearned Only"

    var id: String { rawValue }
}

enum BookletCompletionFilter: String, CaseIterable, Identifiable {
    case active = "Active Only"
    case needsReview = "Needs Review Only"
    case mastered = "Mastered Only"
    case all = "All Statuses"

    var id: String { rawValue }
}

enum BookletPriorityFilter: String, CaseIterable, Identifiable {
    case all = "All Priorities"
    case high = "High Only"
    case normal = "Normal Only"
    case low = "Low Only"

    var id: String { rawValue }
}

enum BookletDueFilter: String, CaseIterable, Identifiable {
    case all = "All Due Dates"
    case dueNow = "Due Now"
    case noDueDate = "No Due Date"

    var id: String { rawValue }
}

enum RevisionBookletAnswerPlacement: String, CaseIterable, Identifiable {
    case afterEachQuestion = "After Each Question"
    case answersAtEnd = "Answers At End"

    var id: String { rawValue }
}
