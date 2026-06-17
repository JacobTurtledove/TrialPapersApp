import Foundation

enum CategoryFilter: String, CaseIterable, Identifiable {
    case all = "All Categories"
    case mistakes = "Mistakes"
    case unlearned = "Unlearned Content"

    var id: String { rawValue }
}

enum CompletionFilter: String, CaseIterable, Identifiable {
    case incomplete = "Incomplete"
    case completed = "Completed"
    case both = "Both"

    var id: String { rawValue }
}
