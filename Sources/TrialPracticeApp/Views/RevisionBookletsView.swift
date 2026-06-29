import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct RevisionBookletsView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \FlaggedQuestion.createdAt) private var questions: [FlaggedQuestion]
    @Query(sort: \Subject.displayName) private var subjects: [Subject]
    @Query(sort: \School.displayName) private var schools: [School]
    @Query private var papers: [Paper]

    @State var selectedSubjectID: UUID?
    @State var categoryFilter: BookletCategoryFilter = .both
    @State var completionFilter: BookletCompletionFilter = .active
    @State var priorityFilter: BookletPriorityFilter = .all
    @State var dueFilter: BookletDueFilter = .all
    @State var answerPlacement: RevisionBookletAnswerPlacement = .afterEachQuestion
    @State var includeWorkingPages = false
    @State var workingPageCount = 1
    @State private var exportMessage: String?
    @State private var exportedBookletURL: URL?
    @State var isExporting = false

    var availableSubjects: [Subject] {
        let activePaperIDs = Set(papers.filter { $0.deletedAt == nil }.map(\.id))
        let subjectIDs = Set(questions.filter {
            $0.deletedAt == nil && activePaperIDs.contains($0.paperID)
        }.map(\.subjectID))
        return subjects.filter {
            $0.deletedAt == nil && subjectIDs.contains($0.id)
        }
    }

    var selectedSubject: Subject? {
        availableSubjects.first { $0.id == selectedSubjectID }
    }

    var filteredQuestions: [FlaggedQuestion] {
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

            switch priorityFilter {
            case .all:
                break
            case .high where question.priority != .high:
                return false
            case .normal where question.priority != .normal:
                return false
            case .low where question.priority != .low:
                return false
            default:
                break
            }

            switch dueFilter {
            case .all:
                break
            case .dueNow where question.nextReviewAt.map({ $0 <= Date() }) != true:
                return false
            case .noDueDate where question.nextReviewAt != nil:
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
                    RevisionBookletQuestionRow(
                        question: question,
                        schoolName: school(for: question)?.displayName ?? "Unknown School"
                    )
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

    private func selectInitialSubject() {
        if selectedSubject == nil {
            selectedSubjectID = availableSubjects.first?.id
        }
    }

    private func school(for question: FlaggedQuestion) -> School? {
        schools.first { $0.id == question.schoolID }
    }

    func exportBooklet() {
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
            let entries = try filteredQuestions.map { question in
                let questionImageURL = try StoredFilePath(
                    question.questionImageRelativePath
                ).url(relativeTo: rootURL)
                let solutionImageURL = try question.solutionImageRelativePath.map {
                    try StoredFilePath($0).url(relativeTo: rootURL)
                }
                return RevisionBookletEntry(
                    schoolName: school(for: question)?.displayName ?? "Unknown School",
                    year: question.year,
                    questionNumber: question.questionNumber,
                    category: question.category,
                    status: question.studyStatus,
                    priority: question.priority,
                    topic: question.topic,
                    marksAvailable: question.marksAvailable,
                    questionImageURL: questionImageURL,
                    solutionImageURL: solutionImageURL
                )
            }
            try RevisionBookletService().export(
                subjectName: selectedSubject.displayName,
                entries: entries,
                answerPlacement: answerPlacement,
                workingPageCount: includeWorkingPages ? max(1, workingPageCount) : 0,
                to: destinationURL
            )
            exportedBookletURL = destinationURL
            exportMessage = "Revision booklet exported successfully."
        } catch {
            exportMessage = error.localizedDescription
        }
    }
}
