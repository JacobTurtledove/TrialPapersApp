import SwiftData
import SwiftUI

struct StudyQueueView: View {
    @Query(sort: \FlaggedQuestion.createdAt, order: .reverse)
    private var questions: [FlaggedQuestion]
    @Query(sort: \FlaggedQuestionAttempt.attemptedAt, order: .reverse)
    private var attempts: [FlaggedQuestionAttempt]
    @Query(sort: \Subject.displayName) private var subjects: [Subject]
    @Query(sort: \School.displayName) private var schools: [School]
    @Query private var papers: [Paper]

    @State private var practiceQuestion: FlaggedQuestion?

    private var queuedQuestions: [FlaggedQuestion] {
        FlaggedQuestionStudyQueueService().defaultQueue(
            questions: questions,
            papers: papers,
            subjects: subjects
        )
    }

    var body: some View {
        Group {
            if queuedQuestions.isEmpty {
                ContentUnavailableView(
                    "Study Queue Empty",
                    systemImage: "checkmark.seal",
                    description: Text("No active flagged questions are due for practice.")
                )
            } else {
                List(queuedQuestions) { question in
                    HStack {
                        NavigationLink {
                            FlaggedQuestionDetailView(
                                question: question,
                                subject: subject(for: question),
                                school: school(for: question)
                            )
                        } label: {
                            StudyQueueRow(
                                question: question,
                                subject: subject(for: question),
                                school: school(for: question),
                                attemptCount: attempts.filter { $0.questionID == question.id }.count
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            practiceQuestion = question
                        } label: {
                            Label("Practice", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationTitle("Study Queue")
        .sheet(item: $practiceQuestion) { question in
            FlaggedQuestionPracticeView(
                question: question,
                subject: subject(for: question),
                school: school(for: question)
            )
        }
    }

    private func subject(for question: FlaggedQuestion) -> Subject? {
        subjects.first { $0.id == question.subjectID }
    }

    private func school(for question: FlaggedQuestion) -> School? {
        schools.first { $0.id == question.schoolID }
    }
}

private struct StudyQueueRow: View {
    let question: FlaggedQuestion
    let subject: Subject?
    let school: School?
    let attemptCount: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Question \(question.questionNumber)")
                        .font(.headline)
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
                    Label(question.studyStatus.rawValue, systemImage: "target")
                    Label(dueText, systemImage: "calendar")
                    Label("\(attemptCount) attempt\(attemptCount == 1 ? "" : "s")", systemImage: "clock.arrow.circlepath")
                    if let topic = question.topic {
                        Label(topic, systemImage: "tag")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var dueText: String {
        guard let nextReviewAt = question.nextReviewAt else {
            return question.studyStatus == .mastered ? "No review due" : "No due date"
        }
        if nextReviewAt <= Date() {
            return "Due now"
        }
        return "Due \(nextReviewAt.formatted(date: .abbreviated, time: .omitted))"
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

    private var priorityColor: Color {
        switch question.priority {
        case .low: .secondary
        case .normal: .blue
        case .high: .red
        }
    }
}
