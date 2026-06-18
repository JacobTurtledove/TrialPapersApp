import SwiftUI

struct FlaggedSubjectFolderCard: View {
    let subject: Subject
    let questions: [FlaggedQuestion]

    private var incompleteCount: Int {
        questions.filter { $0.studyStatus != .mastered }.count
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
