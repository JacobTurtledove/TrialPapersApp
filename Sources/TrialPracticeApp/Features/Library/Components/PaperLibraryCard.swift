import SwiftData
import SwiftUI

struct PaperLibraryCard: View {
    let paper: Paper
    let flaggedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                Spacer()
                Text(paper.year)
                    .font(.title2.bold())
            }

            Text("\(paper.year) Trial Paper")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack {
                Label("\(flaggedCount)", systemImage: "flag")
                if let score = paper.score {
                    Label("\(score)", systemImage: "number.circle")
                }
                Spacer()
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Spacer()
                .frame(height: 24)
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
}

struct ImportingPaperCard: View {
    let year: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.badge.clock")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(year)
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            }

            Text("\(year) Trial Paper")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Importing")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()
                .frame(height: 24)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 165, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .redacted(reason: .placeholder)
        .overlay(alignment: .bottomLeading) {
            Label("Importing", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
                .unredacted()
        }
    }
}

struct ImportingPaperListRow: View {
    let importRecord: OptimisticPaperImport

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "doc.badge.clock")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(importRecord.year) Trial Paper")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(importRecord.schoolName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                ProgressView()
                    .controlSize(.small)
            }
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator.opacity(0.5), lineWidth: 1)
        }
    }
}

enum PaperScoreEditorStyle {
    case compact
    case regular
}

struct PaperScoreEditor: View {
    @Environment(\.modelContext) private var modelContext

    let paper: Paper
    @Binding var errorMessage: String?
    var style: PaperScoreEditorStyle = .regular

    @State private var scoreText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if style == .compact {
                Image(systemName: "number.circle")
                    .foregroundStyle(.secondary)
                    .help("Score")
            } else {
                Label("Score", systemImage: "number.circle")
                    .foregroundStyle(.secondary)
            }

            TextField("Score", text: $scoreText)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospacedDigit())
                .frame(width: style == .compact ? 62 : 76)
                .focused($isFocused)
                .onSubmit {
                    saveScore()
                }

            if paper.score != nil || !scoreText.isEmpty {
                Button {
                    clearScore()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear score")
            }
        }
        .onAppear {
            syncScoreText()
        }
        .onChange(of: paper.score) {
            if !isFocused {
                syncScoreText()
            }
        }
        .onChange(of: isFocused) {
            if !isFocused {
                saveScore()
            }
        }
    }

    private func clearScore() {
        scoreText = ""
        saveScore()
    }

    private func saveScore() {
        let trimmed = scoreText.trimmingCharacters(in: .whitespacesAndNewlines)
        let newScore: Int?
        if trimmed.isEmpty {
            newScore = nil
        } else if let parsed = Int(trimmed), parsed >= 0 {
            newScore = parsed
        } else {
            syncScoreText()
            errorMessage = "Score must be a whole number."
            return
        }

        guard paper.score != newScore else {
            scoreText = newScore.map(String.init) ?? ""
            return
        }

        let oldScore = paper.score
        paper.score = newScore
        do {
            try modelContext.save()
            scoreText = newScore.map(String.init) ?? ""
        } catch {
            paper.score = oldScore
            modelContext.rollback()
            syncScoreText()
            errorMessage = error.localizedDescription
        }
    }

    private func syncScoreText() {
        scoreText = paper.score.map(String.init) ?? ""
    }
}

struct PaperListRow: View {
    let paper: Paper
    let subject: Subject
    let school: School?
    let flaggedCount: Int
    @Binding var errorMessage: String?
    let completionBinding: Binding<Bool>

    var body: some View {
        HStack(spacing: 14) {
            NavigationLink {
                PaperViewerScreen(
                    paper: paper,
                    subject: subject,
                    school: school
                )
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(paper.year) Trial Paper")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(school?.displayName ?? "Unknown School")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Label("\(flaggedCount)", systemImage: "flag")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("Completed", isOn: completionBinding)
                .toggleStyle(.checkbox)

            PaperScoreEditor(
                paper: paper,
                errorMessage: $errorMessage,
                style: .compact
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator.opacity(0.5), lineWidth: 1)
        }
    }
}
