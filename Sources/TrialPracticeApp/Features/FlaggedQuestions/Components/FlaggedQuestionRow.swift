import SwiftUI

struct FlaggedQuestionRow: View {
    @EnvironmentObject private var appState: AppState

    let question: FlaggedQuestion
    let subject: Subject?
    let school: School?
    let attemptCount: Int

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
                    Text(question.priority.rawValue)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(priorityColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(priorityColor)
                }

                Text(
                    "\(subject?.displayName ?? "Unknown Subject") · \(school?.displayName ?? "Unknown School") · \(question.year)"
                )
                .foregroundStyle(.secondary)
                .lineLimit(1)

                HStack(spacing: 10) {
                    Label(question.studyStatus.rawValue, systemImage: statusIcon)
                        .foregroundStyle(statusColor)
                    Label(dueText, systemImage: "calendar")
                    Label("\(attemptCount)", systemImage: "clock.arrow.circlepath")
                    Image(
                        systemName: question.solutionImageRelativePath == nil
                            ? "doc.questionmark"
                            : "checkmark.circle"
                    )
                    .help(
                        question.solutionImageRelativePath == nil
                            ? "No solution provided"
                            : "Includes solution"
                    )
                    if let topic = question.topic {
                        Label(topic, systemImage: "tag")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 5)
    }

    private var categoryColor: Color {
        question.category == .mistake ? .orange : .blue
    }

    private var priorityColor: Color {
        switch question.priority {
        case .low: .secondary
        case .normal: .blue
        case .high: .red
        }
    }

    private var statusIcon: String {
        switch question.studyStatus {
        case .active: "circle"
        case .needsReview: "exclamationmark.circle"
        case .mastered: "checkmark.seal.fill"
        }
    }

    private var statusColor: Color {
        switch question.studyStatus {
        case .active: .secondary
        case .needsReview: .orange
        case .mastered: .green
        }
    }

    private var dueText: String {
        guard let nextReviewAt = question.nextReviewAt else {
            return question.studyStatus == .mastered ? "No review" : "No due date"
        }
        if nextReviewAt <= Date() {
            return "Due now"
        }
        return "Due \(nextReviewAt.formatted(date: .abbreviated, time: .omitted))"
    }
}
