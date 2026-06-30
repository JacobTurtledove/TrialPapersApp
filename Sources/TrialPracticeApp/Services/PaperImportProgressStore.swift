import Foundation

struct OptimisticPaperImport: Identifiable, Equatable {
    let id: UUID
    let subjectID: UUID
    let schoolID: UUID
    let schoolName: String
    let year: String
    let startedAt: Date
}

struct PaperImportFailure: Identifiable, Equatable {
    let id = UUID()
    let paperTitle: String
    let message: String
}

@MainActor
final class PaperImportProgressStore: ObservableObject {
    @Published private(set) var imports: [OptimisticPaperImport] = []
    @Published var failure: PaperImportFailure?

    func begin(
        subjectID: UUID,
        schoolID: UUID,
        schoolName: String,
        year: String
    ) -> UUID {
        let id = UUID()
        imports.append(
            OptimisticPaperImport(
                id: id,
                subjectID: subjectID,
                schoolID: schoolID,
                schoolName: schoolName,
                year: year,
                startedAt: .now
            )
        )
        return id
    }

    func finish(_ id: UUID) {
        imports.removeAll { $0.id == id }
    }

    func fail(_ id: UUID, error: Error) {
        guard let importRecord = imports.first(where: { $0.id == id }) else { return }
        finish(id)
        failure = PaperImportFailure(
            paperTitle: "\(importRecord.year) \(importRecord.schoolName)",
            message: error.localizedDescription
        )
    }

    func imports(forSubjectID subjectID: UUID) -> [OptimisticPaperImport] {
        imports
            .filter { $0.subjectID == subjectID }
            .sorted { $0.startedAt < $1.startedAt }
    }

    func imports(forSubjectID subjectID: UUID, schoolID: UUID) -> [OptimisticPaperImport] {
        imports(forSubjectID: subjectID)
            .filter { $0.schoolID == schoolID }
    }
}
