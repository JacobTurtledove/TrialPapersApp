import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum BookletCategoryFilter: String, CaseIterable, Identifiable {
    case both = "Both Categories"
    case mistakes = "Mistakes Only"
    case unlearned = "Unlearned Only"

    var id: String { rawValue }
}

private enum BookletCompletionFilter: String, CaseIterable, Identifiable {
    case incomplete = "Incomplete Only"
    case completed = "Completed Only"
    case both = "Both"

    var id: String { rawValue }
}

struct RevisionBookletsView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \FlaggedQuestion.createdAt) private var questions: [FlaggedQuestion]
    @Query(sort: \Subject.displayName) private var subjects: [Subject]
    @Query(sort: \School.displayName) private var schools: [School]
    @Query private var papers: [Paper]

    @State private var selectedSubjectID: UUID?
    @State private var categoryFilter: BookletCategoryFilter = .both
    @State private var completionFilter: BookletCompletionFilter = .incomplete
    @State private var exportMessage: String?
    @State private var exportedBookletURL: URL?
    @State private var isExporting = false

    private var availableSubjects: [Subject] {
        let activePaperIDs = Set(papers.filter { $0.deletedAt == nil }.map(\.id))
        let subjectIDs = Set(questions.filter {
            $0.deletedAt == nil && activePaperIDs.contains($0.paperID)
        }.map(\.subjectID))
        return subjects.filter {
            $0.deletedAt == nil && subjectIDs.contains($0.id)
        }
    }

    private var selectedSubject: Subject? {
        availableSubjects.first { $0.id == selectedSubjectID }
    }

    private var filteredQuestions: [FlaggedQuestion] {
        guard let selectedSubjectID else { return [] }
        let activePaperIDs = Set(papers.filter {
            $0.deletedAt == nil && $0.subjectID == selectedSubjectID
        }.map(\.id))
        return questions.filter { question in
            guard question.subjectID == selectedSubjectID else { return false }
            guard question.deletedAt == nil else { return false }
            guard activePaperIDs.contains(question.paperID) else { return false }

            switch categoryFilter {
            case .both:
                break
            case .mistakes where question.category != .mistake:
                return false
            case .unlearned where question.category != .unlearnedContent:
                return false
            default:
                break
            }

            switch completionFilter {
            case .both:
                break
            case .completed where !question.isCompleted:
                return false
            case .incomplete where question.isCompleted:
                return false
            default:
                break
            }

            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            exportControls
            Divider()

            if availableSubjects.isEmpty {
                ContentUnavailableView(
                    "No Flagged Questions",
                    systemImage: "book.pages",
                    description: Text(
                        "Flag some questions before generating a revision booklet."
                    )
                )
            } else if filteredQuestions.isEmpty {
                ContentUnavailableView(
                    "No Matching Questions",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Adjust the booklet filters to include more questions.")
                )
            } else {
                List(filteredQuestions) { question in
                    HStack(spacing: 12) {
                        Image(systemName: question.category == .mistake ? "exclamationmark.triangle" : "book")
                            .foregroundStyle(
                                question.category == .mistake ? Color.orange : Color.blue
                            )
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Question \(question.questionNumber)")
                                .font(.headline)
                            Text(
                                "\(school(for: question)?.displayName ?? "Unknown School") · \(question.year)"
                            )
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(question.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Image(
                            systemName: question.solutionImageRelativePath == nil
                                ? "doc.questionmark"
                                : "checkmark.circle"
                        )
                        .foregroundStyle(.secondary)
                        .help(
                            question.solutionImageRelativePath == nil
                                ? "No solution provided"
                                : "Includes solution"
                        )
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Revision Booklets")
        .onAppear(perform: selectInitialSubject)
        .onChange(of: availableSubjects.map(\.id)) {
            if selectedSubject == nil {
                selectInitialSubject()
            }
        }
        .alert(
            "Revision Booklet",
            isPresented: Binding(
                get: { exportMessage != nil },
                set: { if !$0 { exportMessage = nil } }
            )
        ) {
            if let exportedBookletURL {
                Button("Show in Finder") {
                    FinderRevealService.reveal(exportedBookletURL)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private var exportControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Picker("Subject", selection: $selectedSubjectID) {
                    ForEach(availableSubjects) { subject in
                        Text(subject.displayName).tag(Optional(subject.id))
                    }
                }
                .frame(maxWidth: 240)

                Picker("Category", selection: $categoryFilter) {
                    ForEach(BookletCategoryFilter.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(maxWidth: 190)

                Picker("Completion", selection: $completionFilter) {
                    ForEach(BookletCompletionFilter.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(maxWidth: 170)

                Spacer()
            }

            HStack {
                Text(
                    "\(filteredQuestions.count) question\(filteredQuestions.count == 1 ? "" : "s") will be exported"
                )
                .font(.callout)
                .foregroundStyle(.secondary)

                Spacer()

                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Export PDF") {
                    exportBooklet()
                }
                .buttonStyle(.borderedProminent)
                .disabled(filteredQuestions.isEmpty || selectedSubject == nil || isExporting)
            }
        }
        .padding(16)
    }

    private func selectInitialSubject() {
        if selectedSubject == nil {
            selectedSubjectID = availableSubjects.first?.id
        }
    }

    private func school(for question: FlaggedQuestion) -> School? {
        schools.first { $0.id == question.schoolID }
    }

    private func exportBooklet() {
        guard
            let rootURL = appState.rootFolderURL,
            let selectedSubject
        else {
            exportMessage = "The subject or data folder is unavailable."
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue =
            "\(selectedSubject.filenameValue)_Revision_Booklet_\(Date.now.formatted(.iso8601.year().month().day())).pdf"

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        exportedBookletURL = nil
        isExporting = true
        defer { isExporting = false }

        do {
            let entries = filteredQuestions.map { question in
                RevisionBookletEntry(
                    schoolName: school(for: question)?.displayName ?? "Unknown School",
                    year: question.year,
                    questionNumber: question.questionNumber,
                    category: question.category,
                    questionImageURL: rootURL.appending(
                        path: question.questionImageRelativePath
                    ),
                    solutionImageURL: question.solutionImageRelativePath.map {
                        rootURL.appending(path: $0)
                    }
                )
            }
            try RevisionBookletService().export(
                subjectName: selectedSubject.displayName,
                entries: entries,
                to: destinationURL
            )
            exportedBookletURL = destinationURL
            exportMessage = "Revision booklet exported successfully."
        } catch {
            exportMessage = error.localizedDescription
        }
    }
}
