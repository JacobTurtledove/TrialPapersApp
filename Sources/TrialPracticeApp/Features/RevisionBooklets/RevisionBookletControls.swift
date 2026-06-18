import SwiftUI

extension RevisionBookletsView {
    var exportControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Picker("Subject", selection: $selectedSubjectID) {
                    ForEach(availableSubjects) { subject in
                        Text(subject.displayName).tag(Optional(subject.id))
                    }
                }
                .frame(maxWidth: 240)

                Picker("Category", selection: $categoryFilter) {
                    ForEach(BookletCategoryFilter.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(maxWidth: 190)

                Picker("Completion", selection: $completionFilter) {
                    ForEach(BookletCompletionFilter.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(maxWidth: 170)

                Picker("Priority", selection: $priorityFilter) {
                    ForEach(BookletPriorityFilter.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(maxWidth: 160)

                Picker("Due", selection: $dueFilter) {
                    ForEach(BookletDueFilter.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(maxWidth: 150)

                Spacer()
            }

            HStack(spacing: 12) {
                Picker("Answers", selection: $answerPlacement) {
                    ForEach(RevisionBookletAnswerPlacement.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(maxWidth: 220)

                Toggle("Working pages", isOn: $includeWorkingPages)
                Stepper(
                    "\(workingPageCount) page\(workingPageCount == 1 ? "" : "s")",
                    value: $workingPageCount,
                    in: 1...5
                )
                .disabled(!includeWorkingPages)

                Spacer()
            }

            HStack {
                Text(
                    "\(filteredQuestions.count) question\(filteredQuestions.count == 1 ? "" : "s") will be exported"
                )
                .font(.callout)
                .foregroundStyle(.secondary)

                Spacer()

                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Export PDF") {
                    exportBooklet()
                }
                .buttonStyle(.borderedProminent)
                .disabled(filteredQuestions.isEmpty || selectedSubject == nil || isExporting)
            }
        }
        .padding(16)
    }
}
