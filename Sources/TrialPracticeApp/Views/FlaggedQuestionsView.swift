import AppKit
import SwiftData
import SwiftUI

private enum CategoryFilter: String, CaseIterable, Identifiable {
    case all = "All Categories"
    case mistakes = "Mistakes"
    case unlearned = "Unlearned Content"

    var id: String { rawValue }
}

private enum CompletionFilter: String, CaseIterable, Identifiable {
    case incomplete = "Incomplete"
    case completed = "Completed"
    case both = "Both"

    var id: String { rawValue }
}

struct FlaggedQuestionsView: View {
    @Query(sort: \FlaggedQuestion.createdAt, order: .reverse)
    private var questions: [FlaggedQuestion]
    @Query(sort: \Subject.displayName) private var subjects: [Subject]

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 20)
    ]

    private var subjectFolders: [(subject: Subject, questions: [FlaggedQuestion])] {
        subjects.compactMap { subject in
            guard subject.deletedAt == nil else { return nil }
            let matchingQuestions = questions.filter { $0.subjectID == subject.id }
            return matchingQuestions.isEmpty ? nil : (subject, matchingQuestions)
        }
    }

    var body: some View {
        Group {
            if subjectFolders.isEmpty {
                ContentUnavailableView {
                    Label("No Flagged Questions", systemImage: "flag")
                } description: {
                    Text("Open a paper and use Flag Question to capture something for revision.")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(subjectFolders, id: \.subject.id) { folder in
                            NavigationLink {
                                SubjectFlaggedQuestionsView(subject: folder.subject)
                            } label: {
                                FlaggedSubjectFolderCard(
                                    subject: folder.subject,
                                    questions: folder.questions
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle("Flagged Questions")
    }
}

private struct SubjectFlaggedQuestionsView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \FlaggedQuestion.createdAt, order: .reverse)
    private var questions: [FlaggedQuestion]
    @Query(sort: \School.displayName) private var schools: [School]

    let subject: Subject

    @State private var searchText = ""
    @State private var categoryFilter: CategoryFilter = .all
    @State private var completionFilter: CompletionFilter = .incomplete

    private var subjectQuestions: [FlaggedQuestion] {
        questions.filter { $0.subjectID == subject.id }
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
            case .both:
                break
            case .completed where !question.isCompleted:
                return false
            case .incomplete where question.isCompleted:
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
                question.questionNumber
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
                            school: school(for: question)
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
}

private struct FlaggedSubjectFolderCard: View {
    let subject: Subject
    let questions: [FlaggedQuestion]

    private var incompleteCount: Int {
        questions.filter { !$0.isCompleted }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 58))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(subject.folderColor)

            Text(subject.displayName)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(questionDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 165, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    private var questionDescription: String {
        let total = questions.count
        let questionWord = total == 1 ? "question" : "questions"
        return "\(total) \(questionWord) · \(incompleteCount) incomplete"
    }
}

private struct FlaggedQuestionRow: View {
    @EnvironmentObject private var appState: AppState

    let question: FlaggedQuestion
    let subject: Subject?
    let school: School?

    var body: some View {
        HStack(spacing: 14) {
            StoredImage(
                relativePath: question.questionImageRelativePath,
                rootURL: appState.rootFolderURL
            )
            .frame(width: 86, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Question \(question.questionNumber)")
                        .font(.headline)
                    Text(question.category.rawValue)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(categoryColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(categoryColor)
                }

                Text(
                    "\(subject?.displayName ?? "Unknown Subject") · \(school?.displayName ?? "Unknown School") · \(question.year)"
                )
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Label(
                    question.isCompleted ? "Completed" : "Incomplete",
                    systemImage: question.isCompleted ? "checkmark.circle.fill" : "circle"
                )
                .font(.caption)
                .foregroundStyle(question.isCompleted ? .green : .secondary)
            }

            Spacer()
        }
        .padding(.vertical, 5)
    }

    private var categoryColor: Color {
        question.category == .mistake ? .orange : .blue
    }
}

private struct FlaggedQuestionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    let question: FlaggedQuestion
    let subject: Subject?
    let school: School?

    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var isSolutionVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Question \(question.questionNumber)")
                            .font(.largeTitle.bold())
                        Text(
                            "\(subject?.displayName ?? "Unknown Subject") · \(school?.displayName ?? "Unknown School") · \(question.year)"
                        )
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(
                        "Completed",
                        isOn: Binding(
                            get: { question.isCompleted },
                            set: { setCompleted($0) }
                        )
                    )
                    .toggleStyle(.checkbox)
                }

                Label(question.category.rawValue, systemImage: "tag")
                    .foregroundStyle(.secondary)

                imageSection(
                    title: "Question",
                    relativePath: question.questionImageRelativePath
                )

                if let solutionPath = question.solutionImageRelativePath {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Show Solution", isOn: $isSolutionVisible)
                            .toggleStyle(.switch)

                        if isSolutionVisible {
                            imageSection(title: "Solution", relativePath: solutionPath)
                                .transition(.opacity)
                        } else {
                            ContentUnavailableView(
                                "Solution Hidden",
                                systemImage: "eye.slash",
                                description: Text(
                                    "Try the question first, then turn on Show Solution."
                                )
                            )
                            .frame(maxWidth: .infinity, minHeight: 180)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: isSolutionVisible)
                } else {
                    ContentUnavailableView(
                        "No Solution Provided",
                        systemImage: "doc.questionmark"
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                }

                Divider()

                Button("Delete Flagged Question", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
            .padding(24)
        }
        .navigationTitle("Question \(question.questionNumber)")
        .confirmationDialog(
            "Delete this flagged question?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteQuestion()
            }
        } message: {
            Text("The captured question and solution images will also be deleted.")
        }
        .alert(
            "Could Not Update Question",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func imageSection(title: String, relativePath: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                Spacer()
                Button("Show in Finder") {
                    reveal(relativePath)
                }
            }
            StoredImage(relativePath: relativePath, rootURL: appState.rootFolderURL)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator, lineWidth: 1)
                }
        }
    }

    private func reveal(_ relativePath: String) {
        guard let rootURL = appState.rootFolderURL else {
            errorMessage = "Reconnect the app data folder in Settings."
            return
        }
        do {
            try FinderRevealService.revealStoredItem(
                relativePath: relativePath,
                rootURL: rootURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setCompleted(_ completed: Bool) {
        let oldValue = question.isCompleted
        question.isCompleted = completed
        do {
            try modelContext.save()
        } catch {
            question.isCompleted = oldValue
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func deleteQuestion() {
        guard let rootURL = appState.rootFolderURL else {
            errorMessage = "The data folder is unavailable. Reconnect it in Settings."
            return
        }
        var transaction: LocalFileStore.DeletionTransaction?
        do {
            transaction = try LocalFileStore(rootURL: rootURL).stageDeletion(for: question)
            modelContext.delete(question)
            try modelContext.save()
            try? transaction?.commit()
        } catch {
            modelContext.rollback()
            try? transaction?.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct StoredImage: View {
    let relativePath: String
    let rootURL: URL?

    var body: some View {
        if
            let rootURL,
            let image = NSImage(contentsOf: rootURL.appending(path: relativePath))
        {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ContentUnavailableView("Image Missing", systemImage: "photo.badge.exclamationmark")
        }
    }
}
