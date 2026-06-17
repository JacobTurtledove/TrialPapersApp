enum PaperFileNames {
    static func base(subject: Subject, school: School, year: String) -> String {
        "\(subject.filenameValue)_\(school.filenameValue)_\(year)"
    }

    static func question(subject: Subject, school: School, year: String) -> String {
        "\(base(subject: subject, school: school, year: year)).pdf"
    }

    static func combined(subject: Subject, school: School, year: String) -> String {
        question(subject: subject, school: school, year: year)
    }

    static func solutions(subject: Subject, school: School, year: String) -> String {
        "\(base(subject: subject, school: school, year: year))_sols.pdf"
    }
}
