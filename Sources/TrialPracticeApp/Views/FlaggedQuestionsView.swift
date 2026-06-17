import SwiftData
import SwiftUI

struct FlaggedQuestionsView: View {
    @Query(sort: \FlaggedQuestion.createdAt, order: .reverse)
    private var questions: [FlaggedQuestion]
    @Query(sort: \Subject.displayName) private var subjects: [Subject]
    @Query private var papers: [Paper]

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 20)
    ]

    private var subjectFolders: [(subject: Subject, questions: [FlaggedQuestion])] {
        subjects.compactMap { subject in
            guard subject.deletedAt == nil else { return nil }
            let activePaperIDs = Set(papers.filter {
                $0.deletedAt == nil && $0.subjectID == subject.id
            }.map(\.id))
            let matchingQuestions = questions.filter {
                $0.deletedAt == nil &&
                $0.subjectID == subject.id &&
                activePaperIDs.contains($0.paperID)
            }
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
