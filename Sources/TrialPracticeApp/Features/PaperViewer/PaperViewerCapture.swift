import SwiftUI

extension PaperViewerScreen {
    var captureToolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Label("Select the question between the two lines", systemImage: "arrow.up.and.down")
                    .font(.callout.weight(.medium))

                Spacer()

                TextField("Question number", text: $questionNumber)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)

                Picker("Category", selection: $category) {
                    ForEach(QuestionCategory.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
            }

            HStack(spacing: 12) {
                Picker("Status", selection: $studyStatus) {
                    ForEach(FlaggedQuestionStudyStatus.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(width: 150)

                Picker("Priority", selection: $priority) {
                    ForEach(FlaggedQuestionPriority.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .frame(width: 130)

                TextField("Marks", text: $marksText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)

                TextField("Topic", text: $topicText)
                    .textFieldStyle(.roundedBorder)

                Toggle("Due", isOn: $nextReviewEnabled)
                DatePicker(
                    "Review date",
                    selection: $nextReviewDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .disabled(!nextReviewEnabled)
            }

            TextField("Study notes", text: $studyNotesText)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Toggle("Include solution capture", isOn: $includeSolution)
                    .disabled(solutionURL == nil)
                    .onChange(of: includeSolution) {
                        if includeSolution {
                            solutionController.beginCapture()
                        } else {
                            solutionController.endCapture()
                        }
                    }

                Text("Scroll normally; drag either line to adjust the selected full-width area.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isSavingQuestion {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Cancel", role: .cancel) {
                    finishFlagging()
                }

                Button("Save") {
                    attemptSaveFlaggedQuestion()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSavingQuestion)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
