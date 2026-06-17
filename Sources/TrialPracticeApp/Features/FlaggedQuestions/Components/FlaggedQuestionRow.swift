import SwiftUI

struct FlaggedQuestionRow: View {
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
