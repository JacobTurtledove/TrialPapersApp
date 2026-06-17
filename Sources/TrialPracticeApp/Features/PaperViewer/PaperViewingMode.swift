enum PaperViewingMode: String, CaseIterable, Identifiable {
    case questions = "Questions"
    case solutions = "Solutions"
    case both = "Both"

    var id: String { rawValue }
}
