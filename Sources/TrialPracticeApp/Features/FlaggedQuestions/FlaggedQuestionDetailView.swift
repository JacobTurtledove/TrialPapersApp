import SwiftData
import SwiftUI

struct FlaggedQuestionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @Query(sort: \FlaggedQuestionAttempt.attemptedAt, order: .reverse)
    private var attempts: [FlaggedQuestionAttempt]

    let question: FlaggedQuestion
    let subject: Subject?
    let school: School?

    @State private var errorMessage: String?
    @State private var exportMessage: String?
    @State private var exportedURL: URL?
    @State private var showDeleteConfirmation = false
    @State private var isSolutionVisible = false
    @State private var showPractice = false
    @State private var studyStatus: FlaggedQuestionStudyStatus = .active
    @State private var priority: FlaggedQuestionPriority = .normal
    @State private var marksText = ""
    @State private var topicText = ""
    @State private var studyNotesText = ""
    @State private var nextReviewEnabled = false
    @State private var nextReviewDate = Date()

    private var questionAttempts: [FlaggedQuestionAttempt] {
        attempts.filter { $0.questionID == question.id }
    }

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
                    Button {
                        showPractice = true
                    } label: {
                        Label("Practice This Question", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Label(question.category.rawValue, systemImage: "tag")
                    .foregroundStyle(.secondary)

                metadataSection

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

                attemptsSection

                Divider()

                HStack {
                    Button {
                        exportQuestion()
                    } label: {
                        Label("Export Flagged Question", systemImage: "square.and.arrow.up")
                    }

                    Button("Delete Flagged Question", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Question \(question.questionNumber)")
        .onAppear(perform: loadMetadata)
        .sheet(isPresented: $showPractice) {
            FlaggedQuestionPracticeView(
                question: question,
                subject: subject,
                school: school
            )
        }
        .confirmationDialog(
            "Delete this flagged question?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteQuestion()
            }
        } message: {
            Text("The flagged question will move to the Bin. Stored images will remain in Application Support.")
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

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Study Metadata")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Status", selection: $studyStatus) {
                    ForEach(FlaggedQuestionStudyStatus.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(width: 170)

                Picker("Priority", selection: $priority) {
                    ForEach(FlaggedQuestionPriority.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(width: 140)

                TextField("Marks", text: $marksText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)

                Toggle("Due", isOn: $nextReviewEnabled)
                DatePicker(
                    "Review date",
                    selection: $nextReviewDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .disabled(!nextReviewEnabled || studyStatus == .mastered)
            }

            TextField("Topic", text: $topicText)
                .textFieldStyle(.roundedBorder)

            TextField("Study notes", text: $studyNotesText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            Button {
                saveMetadata()
            } label: {
                Label("Save Study Metadata", systemImage: "square.and.arrow.down")
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var attemptsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Attempt History")
                .font(.headline)
            if questionAttempts.isEmpty {
                ContentUnavailableView(
                    "No Attempts Yet",
                    systemImage: "clock.arrow.circlepath"
                )
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ForEach(questionAttempts) { attempt in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: attempt.outcome == .correct ? "checkmark.circle" : "arrow.clockwise.circle")
                            .foregroundStyle(attempt.outcome == .correct ? .green : .orange)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(attempt.outcome.rawValue) · \(attempt.confidence.rawValue) confidence")
                                .font(.headline)
                            Text(attempt.attemptedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(attemptSummary(attempt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let notes = attempt.notes {
                                Text(notes)
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
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
            errorMessage = "The app storage folder is unavailable."
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

    private func deleteQuestion() {
        let oldDeletedAt = question.deletedAt
        do {
            question.deletedAt = .now
            try modelContext.save()
            dismiss()
        } catch {
            question.deletedAt = oldDeletedAt
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func exportQuestion() {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        guard let destinationURL = chooseFlaggedQuestionExportFolder() else { return }
        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportFlaggedQuestion(
                question,
                subject: subject,
                school: school,
                to: destinationURL
            )
            exportMessage = "Flagged question exported successfully."
        } catch {
            exportedURL = nil
            exportMessage = error.localizedDescription
        }
    }

    private func loadMetadata() {
        studyStatus = question.studyStatus
        priority = question.priority
        marksText = question.marksAvailable.map(String.init) ?? ""
        topicText = question.topic ?? ""
        studyNotesText = question.studyNotes ?? ""
        if let nextReviewAt = question.nextReviewAt {
            nextReviewEnabled = true
            nextReviewDate = nextReviewAt
        } else {
            nextReviewEnabled = false
            nextReviewDate = Date()
        }
    }

    private func saveMetadata() {
        if !marksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           parsedMarks == nil {
            errorMessage = "Marks must be a whole number."
            return
        }
        do {
            try FlaggedQuestionAttemptService().saveMetadata(
                for: question,
                status: studyStatus,
                priority: priority,
                marksAvailable: parsedMarks,
                topic: topicText,
                studyNotes: studyNotesText,
                nextReviewAt: nextReviewEnabled ? nextReviewDate : nil,
                modelContext: modelContext
            )
            loadMetadata()
        } catch {
            errorMessage = error.localizedDescription
            loadMetadata()
        }
    }

    private var parsedMarks: Int? {
        let trimmed = marksText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    private func attemptSummary(_ attempt: FlaggedQuestionAttempt) -> String {
        if let nextReviewAt = attempt.nextReviewAt {
            return "\(attempt.appliedStatus.rawValue), next review \(nextReviewAt.formatted(date: .abbreviated, time: .omitted))"
        }
        return attempt.appliedStatus.rawValue
    }
}
