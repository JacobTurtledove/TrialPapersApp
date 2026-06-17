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
