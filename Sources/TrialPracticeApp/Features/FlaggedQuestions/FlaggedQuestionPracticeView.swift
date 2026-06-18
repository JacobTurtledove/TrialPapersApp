import SwiftData
import SwiftUI

struct FlaggedQuestionPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    let question: FlaggedQuestion
    let subject: Subject?
    let school: School?

    @State private var isSolutionVisible = false
    @State private var outcome: FlaggedQuestionAttemptOutcome = .correct
    @State private var confidence: FlaggedQuestionAttemptConfidence = .medium
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Question \(question.questionNumber)")
                            .font(.title.bold())
                        Text(
                            "\(subject?.displayName ?? "Unknown Subject") · \(school?.displayName ?? "Unknown School") · \(question.year)"
                        )
                        .foregroundStyle(.secondary)
                    }

                    StoredImage(
                        relativePath: question.questionImageRelativePath,
                        rootURL: appState.rootFolderURL
                    )
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.separator, lineWidth: 1)
                    }

                    solutionSection
                    attemptControls
                }
                .padding(22)
            }

            Divider()
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Spacer()
                Button {
                    recordAttempt()
                } label: {
                    Label("Record Attempt", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(.bar)
        }
        .frame(minWidth: 640, minHeight: 620)
        .alert(
            "Could Not Record Attempt",
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

    @ViewBuilder
    private var solutionSection: some View {
        if let solutionPath = question.solutionImageRelativePath {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Show Solution", isOn: $isSolutionVisible)
                    .toggleStyle(.switch)
                if isSolutionVisible {
                    StoredImage(relativePath: solutionPath, rootURL: appState.rootFolderURL)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.separator, lineWidth: 1)
                        }
                } else {
                    ContentUnavailableView(
                        "Solution Hidden",
                        systemImage: "eye.slash",
                        description: Text("Try the question first, then reveal the solution.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 160)
                }
            }
        } else {
            ContentUnavailableView("No Solution Provided", systemImage: "doc.questionmark")
                .frame(maxWidth: .infinity, minHeight: 160)
        }
    }

    private var attemptControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attempt Result")
                .font(.headline)
            HStack(spacing: 12) {
                Picker("Outcome", selection: $outcome) {
                    ForEach(FlaggedQuestionAttemptOutcome.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(width: 180)

                Picker("Confidence", selection: $confidence) {
                    ForEach(FlaggedQuestionAttemptConfidence.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(width: 170)

                Text(schedulePreview)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TextField("Attempt notes", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
        }
    }

    private var schedulePreview: String {
        let result = FlaggedQuestionStudyScheduler().schedule(
            outcome: outcome,
            confidence: confidence,
            attemptedAt: Date()
        )
        guard let nextReviewAt = result.nextReviewAt else {
            return "Will be marked Mastered"
        }
        return "Will be \(result.status.rawValue), due \(nextReviewAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func recordAttempt() {
        do {
            _ = try FlaggedQuestionAttemptService().recordAttempt(
                for: question,
                outcome: outcome,
                confidence: confidence,
                notes: notes,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
