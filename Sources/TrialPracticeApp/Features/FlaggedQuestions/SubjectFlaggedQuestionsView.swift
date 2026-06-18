import SwiftData
import SwiftUI

struct SubjectFlaggedQuestionsView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \FlaggedQuestion.createdAt, order: .reverse)
    private var questions: [FlaggedQuestion]
    @Query(sort: \FlaggedQuestionAttempt.attemptedAt, order: .reverse)
    private var attempts: [FlaggedQuestionAttempt]
    @Query(sort: \School.displayName) private var schools: [School]
    @Query private var papers: [Paper]

    let subject: Subject

    @State private var searchText = ""
    @State private var categoryFilter: CategoryFilter = .all
    @State private var completionFilter: CompletionFilter = .active
    @State private var exportMessage: String?
    @State private var exportedURL: URL?

    private var subjectQuestions: [FlaggedQuestion] {
        let activePaperIDs = Set(papers.filter {
            $0.deletedAt == nil && $0.subjectID == subject.id
        }.map(\.id))
        return questions.filter {
            $0.deletedAt == nil &&
            $0.subjectID == subject.id &&
            activePaperIDs.contains($0.paperID)
        }
    }

    private var filteredQuestions: [FlaggedQuestion] {
        subjectQuestions.filter { question in
            switch categoryFilter {
            case .all:
                break
            case .mistakes where question.category != .mistake:
                return false
            case .unlearned where question.category != .unlearnedContent:
                return false
            default:
                break
            }
            switch completionFilter {
            case .all:
                break
            case .active where question.studyStatus != .active:
                return false
            case .needsReview where question.studyStatus != .needsReview:
                return false
            case .mastered where question.studyStatus != .mastered:
                return false
            default:
                break
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            let schoolName = school(for: question)?.displayName ?? ""
            return [
                schoolName,
                question.year,
                question.questionNumber,
                question.topic ?? "",
                question.studyNotes ?? ""
            ].contains {
                $0.localizedCaseInsensitiveContains(query)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()

            if subjectQuestions.isEmpty {
                ContentUnavailableView {
                    Label("No Flagged Questions", systemImage: "flag")
                } description: {
                    Text("There are no longer any flagged questions in this subject.")
                }
            } else if filteredQuestions.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredQuestions) { question in
                    NavigationLink {
                        FlaggedQuestionDetailView(
                            question: question,
                            subject: subject,
                            school: school(for: question)
                        )
                    } label: {
                        FlaggedQuestionRow(
                            question: question,
                            subject: subject,
                            school: school(for: question),
                            attemptCount: attempts.filter { $0.questionID == question.id }.count
                        )
                    }
                    .contextMenu {
                        Button("Show Question in Finder") {
                            reveal(question.questionImageRelativePath)
                        }
                        if let solutionPath = question.solutionImageRelativePath {
                            Button("Show Solution in Finder") {
                                reveal(solutionPath)
                            }
                        }
                        Button("Export Flagged Question") {
                            exportQuestion(question)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(subject.displayName)
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "School, year, or question"
        )
        .alert(
            "Flagged Question Export",
            isPresented: Binding(
                get: { exportMessage != nil },
                set: { if !$0 { exportMessage = nil } }
            )
        ) {
            if let exportedURL {
                Button("Show in Finder") {
                    FinderRevealService.reveal(exportedURL)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("Category", selection: $categoryFilter) {
                ForEach(CategoryFilter.allCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            .frame(maxWidth: 200)

            Picker("Status", selection: $completionFilter) {
                ForEach(CompletionFilter.allCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            .frame(maxWidth: 160)

            Spacer()

            Text("\(filteredQuestions.count) shown")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func school(for question: FlaggedQuestion) -> School? {
        schools.first { $0.id == question.schoolID }
    }

    private func reveal(_ relativePath: String) {
        guard let rootURL = appState.rootFolderURL else { return }
        try? FinderRevealService.revealStoredItem(
            relativePath: relativePath,
            rootURL: rootURL
        )
    }

    private func exportQuestion(_ question: FlaggedQuestion) {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        guard let destinationURL = chooseFlaggedQuestionExportFolder() else { return }
        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportFlaggedQuestion(
                question,
                subject: subject,
                school: school(for: question),
                to: destinationURL
            )
            exportMessage = "Flagged question exported successfully."
        } catch {
            exportedURL = nil
            exportMessage = error.localizedDescription
        }
    }
}
