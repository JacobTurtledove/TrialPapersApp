enum PaperFileNames {
    static func base(subject: Subject, school: School, year: String) -> String {
        base(
            subjectFilenameValue: subject.filenameValue,
            schoolFilenameValue: school.filenameValue,
            year: year
        )
    }

    static func base(
        subjectFilenameValue: String,
        schoolFilenameValue: String,
        year: String
    ) -> String {
        "\(subjectFilenameValue)_\(schoolFilenameValue)_\(year)"
    }

    static func question(subject: Subject, school: School, year: String) -> String {
        question(
            subjectFilenameValue: subject.filenameValue,
            schoolFilenameValue: school.filenameValue,
            year: year
        )
    }

    static func question(
        subjectFilenameValue: String,
        schoolFilenameValue: String,
        year: String
    ) -> String {
        let baseName = base(
            subjectFilenameValue: subjectFilenameValue,
            schoolFilenameValue: schoolFilenameValue,
            year: year
        )
        return "\(baseName).pdf"
    }

    static func combined(subject: Subject, school: School, year: String) -> String {
        question(subject: subject, school: school, year: year)
    }

    static func combined(
        subjectFilenameValue: String,
        schoolFilenameValue: String,
        year: String
    ) -> String {
        question(
            subjectFilenameValue: subjectFilenameValue,
            schoolFilenameValue: schoolFilenameValue,
            year: year
        )
    }

    static func solutions(subject: Subject, school: School, year: String) -> String {
        "\(base(subject: subject, school: school, year: year))_sols.pdf"
    }
}
