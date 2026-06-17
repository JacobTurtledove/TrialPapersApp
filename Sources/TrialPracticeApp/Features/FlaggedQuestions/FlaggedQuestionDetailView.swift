import SwiftData
import SwiftUI

struct FlaggedQuestionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    let question: FlaggedQuestion
    let subject: Subject?
    let school: School?

    @State private var errorMessage: String?
    @State private var exportMessage: String?
    @State private var exportedURL: URL?
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
}
