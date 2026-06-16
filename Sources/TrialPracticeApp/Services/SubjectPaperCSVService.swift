import Foundation

struct SubjectPaperCSVRow {
    let schoolName: String
    let year: String
    let mark: Double?
}

struct SubjectPaperCSVService {
    enum ExportError: LocalizedError {
        case noPapers

        var errorDescription: String? {
            switch self {
            case .noPapers:
                "There are no papers to export for this subject."
            }
        }
    }

    func csvData(rows: [SubjectPaperCSVRow]) throws -> Data {
        guard !rows.isEmpty else {
            throw ExportError.noPapers
        }

        let sortedRows = rows.sorted {
            let schoolComparison = $0.schoolName.localizedCaseInsensitiveCompare($1.schoolName)
            if schoolComparison == .orderedSame {
                return $0.year.localizedStandardCompare($1.year) == .orderedAscending
            }
            return schoolComparison == .orderedAscending
        }

        var lines = ["School,Year,Mark"]
        for row in sortedRows {
            let markValue = row.mark.map { String($0) } ?? ""
            let line = [
                escaped(row.schoolName),
                escaped(row.year),
                markValue
            ].joined(separator: ",")
            lines.append(line)
        }

        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    func export(rows: [SubjectPaperCSVRow], to destinationURL: URL) throws {
        try csvData(rows: rows).write(to: destinationURL, options: .atomic)
    }

    private func escaped(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
