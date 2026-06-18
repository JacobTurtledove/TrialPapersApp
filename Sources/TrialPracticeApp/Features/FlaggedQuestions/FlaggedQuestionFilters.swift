import Foundation

enum CategoryFilter: String, CaseIterable, Identifiable {
    case all = "All Categories"
    case mistakes = "Mistakes"
    case unlearned = "Unlearned Content"

    var id: String { rawValue }
}

enum CompletionFilter: String, CaseIterable, Identifiable {
    case active = "Active"
    case needsReview = "Needs Review"
    case mastered = "Mastered"
    case all = "All Statuses"

    var id: String { rawValue }
}
