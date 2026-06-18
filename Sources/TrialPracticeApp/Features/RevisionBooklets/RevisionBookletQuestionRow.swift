import SwiftUI

struct RevisionBookletQuestionRow: View {
    let question: FlaggedQuestion
    let schoolName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: question.category == .mistake ? "exclamationmark.triangle" : "book")
                .foregroundStyle(question.category == .mistake ? Color.orange : Color.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("Question \(question.questionNumber)")
                    .font(.headline)
                Text("\(schoolName) · \(question.year)")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(question.category.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(question.studyStatus.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(question.priority.rawValue)
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
