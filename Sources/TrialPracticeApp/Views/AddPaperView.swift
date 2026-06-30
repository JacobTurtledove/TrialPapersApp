import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AddPaperView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationCoordinator: AppNavigationCoordinator

    @Query(sort: \Subject.displayName) private var subjects: [Subject]
    @Query(sort: \School.displayName) private var schools: [School]
    @Query private var papers: [Paper]

    @State private var subjectID: UUID?
    @State private var schoolName = ""
    @State private var year = ""
    @State private var solutionsIncluded = true
    @State private var questionPDFURL: URL?
    @State private var solutionsPDFURL: URL?
    @State private var isChoosingPDF = false
    @State private var pickerTarget: PDFPickerTarget?
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var isPDFTargeted = false
    @State private var importTask: Task<Void, Never>?

    private let initialSubjectID: UUID?
    private let initialSchoolName: String
    private let initialPDFURL: URL?

    init(
        initialSubjectID: UUID? = nil,
        initialSchoolName: String = "",
        initialPDFURL: URL? = nil
    ) {
        self.initialSubjectID = initialSubjectID
        self.initialSchoolName = initialSchoolName
        self.initialPDFURL = initialPDFURL
        _subjectID = State(initialValue: initialSubjectID)
        _schoolName = State(initialValue: initialSchoolName)
        _questionPDFURL = State(initialValue: initialPDFURL)
    }

    private var activeSubjects: [Subject] {
        subjects.filter { $0.deletedAt == nil }
    }

    private var schoolSuggestions: [School] {
        guard !schoolName.isEmpty else { return Array(schools.prefix(5)) }
        return schools.filter {
            $0.displayName.localizedCaseInsensitiveContains(schoolName)
        }
        .prefix(5)
        .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Trial Paper")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") {
                    importTask?.cancel()
                    dismiss()
                }
                .disabled(isImporting)
            }
            .padding(24)

            Divider()

            Form {
                Section("Paper Details") {
                    Picker("Subject", selection: $subjectID) {
                        Text("Select a subject").tag(nil as UUID?)
                        ForEach(activeSubjects) { subject in
                            Text(subject.displayName).tag(subject.id as UUID?)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("School", text: $schoolName)
                        if !schoolSuggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(schoolSuggestions) { school in
                                        Button(school.displayName) {
                                            schoolName = school.displayName
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }
                    }

                    TextField("Year", text: $year)
                        .help("Numbers only, for example 2025")
                }

                Section("PDF Files") {
                    VStack(spacing: 14) {
                        Label(
                            isPDFTargeted ? "Release to add PDF" : "Drag paper PDF here",
                            systemImage: isPDFTargeted ? "arrow.down.doc.fill" : "arrow.down.doc"
                        )
                        .font(.headline)
                        .foregroundStyle(isPDFTargeted ? Color.accentColor : .secondary)

                        PDFSelectionRow(
                            title: "Paper PDF",
                            url: questionPDFURL
                        ) {
                            pickerTarget = .question
                            isChoosingPDF = true
                        }

                        Toggle("Solutions included in PDF", isOn: $solutionsIncluded)

                        if !solutionsIncluded {
                            PDFSelectionRow(
                                title: "Separate solutions (optional)",
                                url: solutionsPDFURL
                            ) {
                                pickerTarget = .solutions
                                isChoosingPDF = true
                            }
                            Text("Leave this empty if the paper has no solutions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isPDFTargeted ? Color.accentColor.opacity(0.12) : .clear)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isPDFTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                                style: StrokeStyle(lineWidth: isPDFTargeted ? 3 : 1, dash: [7])
                            )
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button {
                    navigationCoordinator.showTHSCImport()
                    dismiss()
                } label: {
                    Label("Import from THSC instead", systemImage: "arrow.down.doc.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isImporting)

                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button("Import Paper") {
                    importPaper()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)
            }
            .padding(20)
        }
        .frame(width: 560, height: 620)
        .dropDestination(for: URL.self) { urls, _ in
            guard let pdf = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else {
                return false
            }
            questionPDFURL = pdf
            return true
        } isTargeted: {
            isPDFTargeted = $0
        }
        .fileImporter(
            isPresented: $isChoosingPDF,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePDFSelection(result)
        }
        .alert(
            "Unable to Import Paper",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            subjectID = subjectID ?? initialSubjectID ?? activeSubjects.first?.id
            if schoolName.isEmpty {
                schoolName = initialSchoolName
            }
        }
        .onChange(of: solutionsIncluded) {
            if solutionsIncluded {
                solutionsPDFURL = nil
            }
        }
        .onDisappear {
            importTask?.cancel()
        }
    }

    private func handlePDFSelection(_ result: Result<[URL], Error>) {
        defer { pickerTarget = nil }

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            switch pickerTarget {
            case .question:
                questionPDFURL = url
            case .solutions:
                solutionsPDFURL = url
            case nil:
                break
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func importPaper() {
        guard let subjectID,
              let subject = activeSubjects.first(where: { $0.id == subjectID }) else {
            errorMessage = "Select a subject."
            return
        }

        let normalizedSchoolName = NameNormalizer.displayName(from: schoolName)
        let schoolFilenameValue = NameNormalizer.filenameValue(from: normalizedSchoolName)
        guard !normalizedSchoolName.isEmpty, !schoolFilenameValue.isEmpty else {
            errorMessage = "Enter a school name containing at least one letter."
            return
        }
        guard let validatedYear = PaperValidation.year(from: year) else {
            errorMessage = "Year must contain numbers only."
            return
        }

        guard let questionPDFURL else {
            errorMessage = "Select or drag in a paper PDF."
            return
        }

        let school = schools.first {
            $0.displayName.localizedCaseInsensitiveCompare(normalizedSchoolName) == .orderedSame
        } ?? School(
            displayName: normalizedSchoolName,
            filenameValue: schoolFilenameValue
        )

        guard !papers.contains(where: {
            $0.subjectID == subject.id &&
            $0.schoolID == school.id &&
            $0.year == validatedYear
        }) else {
            errorMessage = "A paper already exists for this subject, school, and year."
            return
        }
        guard let rootURL = appState.rootFolderURL else {
            errorMessage = "The app data folder is unavailable."
            return
        }

        isImporting = true
        errorMessage = nil
        let importService = PaperImportService(rootURL: rootURL)
        let request = PaperImportRequest(
            subjectFilenameValue: subject.filenameValue,
            schoolFilenameValue: school.filenameValue,
            year: validatedYear,
            mode: solutionsIncluded || solutionsPDFURL == nil ? .combined : .separate,
            questionPDFURL: questionPDFURL,
            solutionsPDFURL: solutionsPDFURL
        )

        importTask?.cancel()
        importTask = Task { @MainActor in
            var importedFiles: ImportedPaperFiles?
            do {
                let files = try await Task.detached(priority: .userInitiated) {
                    try importService.importPaper(request)
                }.value
                importedFiles = files

                guard !Task.isCancelled else {
                    importService.discardImportedFiles(files)
                    isImporting = false
                    return
                }

                if school.modelContext == nil {
                    modelContext.insert(school)
                }
                modelContext.insert(
                    Paper(
                        subjectID: subject.id,
                        schoolID: school.id,
                        year: validatedYear,
                        questionPDFRelativePath: files.combinedRelativePath,
                        solutionsPDFRelativePath: files.combinedRelativePath,
                        combinedPDFRelativePath: files.combinedRelativePath,
                        solutionsStartPage: !solutionsIncluded && solutionsPDFURL != nil
                            ? files.questionPageCount.map { $0 + 1 }
                            : nil,
                        hasSolutions: solutionsIncluded || solutionsPDFURL != nil
                    )
                )
                try modelContext.save()
                isImporting = false
                dismiss()
            } catch {
                modelContext.rollback()
                if let importedFiles {
                    importService.discardImportedFiles(importedFiles)
                }
                errorMessage = error.localizedDescription
                isImporting = false
            }
        }
    }
}
