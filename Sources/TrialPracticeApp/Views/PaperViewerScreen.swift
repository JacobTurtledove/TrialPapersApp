import AppKit
import PDFKit
import SwiftData
import SwiftUI

enum PaperViewingMode: String, CaseIterable, Identifiable {
    case questions = "Questions"
    case solutions = "Solutions"
    case both = "Both"

    var id: String { rawValue }
}

struct PaperViewerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var existingQuestions: [FlaggedQuestion]

    let paper: Paper
    let subject: Subject?
    let school: School?

    @State private var viewingMode: PaperViewingMode = .questions
    @State private var isFlaggingQuestion = false
    @State private var questionNumber = ""
    @State private var category: QuestionCategory = .mistake
    @State private var includeSolution = true
    @State private var isSavingQuestion = false
    @State private var captureError: String?
    @State private var paperUpdateError: String?
    @State private var exportMessage: String?
    @State private var showExportResult = false
    @State private var exportedURL: URL?
    @State private var showDuplicateWarning = false
    @State private var isChoosingSolutionsStart = false
    @State private var showSolutionsSetupPrompt = false
    @StateObject private var questionController = PDFViewerController()
    @StateObject private var solutionController = PDFViewerController()

    private var questionURL: URL? {
        fileURL(for: paper.combinedPDFRelativePath ?? paper.questionPDFRelativePath)
    }

    private var solutionURL: URL? {
        fileURL(for: paper.combinedPDFRelativePath ?? paper.solutionsPDFRelativePath)
    }

    private var questionSelection: PDFPageSelection {
        paper.solutionsStartPage.map { .questions(before: $0) } ?? .all
    }

    private var solutionSelection: PDFPageSelection {
        paper.solutionsStartPage.map { .solutions(from: $0) } ?? .all
    }

    var body: some View {
        VStack(spacing: 0) {
            viewerToolbar
            if isFlaggingQuestion {
                Divider()
                captureToolbar
            }
            Divider()
            viewerContent
        }
        .navigationTitle(viewerTitle)
        .onAppear {
            if paper.hasSolutions != false, paper.solutionsStartPage == nil {
                viewingMode = .questions
                showSolutionsSetupPrompt = true
            }
        }
        .alert("Where Do Solutions Start?", isPresented: $showSolutionsSetupPrompt) {
            Button("Select First Solutions Page") {
                viewingMode = .questions
                isChoosingSolutionsStart = true
            }
            Button("This Paper Has No Solutions") {
                saveNoSolutions()
            }
            if paper.solutionsStartPage != nil || paper.hasSolutions != nil {
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            Text("This app keeps questions and solutions in one PDF. If the PDF includes solutions, choose the first page where solutions begin so the viewer can show Questions, Solutions, or Both. If there are no solutions, choose “This Paper Has No Solutions”.")
        }
        .alert("Question Already Flagged", isPresented: $showDuplicateWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Save Duplicate") {
                saveFlaggedQuestion()
            }
        } message: {
            Text(
                "A flagged question with this subject, school, year, and question number already exists."
            )
        }
        .alert(
            "Could Not Save Question",
            isPresented: Binding(
                get: { captureError != nil },
                set: { if !$0 { captureError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(captureError ?? "")
        }
        .alert(
            "Could Not Update Paper",
            isPresented: Binding(
                get: { paperUpdateError != nil },
                set: { if !$0 { paperUpdateError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(paperUpdateError ?? "")
        }
        .alert("PDF Export", isPresented: $showExportResult) {
            if let exportedURL {
                Button("Show in Finder") {
                    FinderRevealService.reveal(exportedURL)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private var viewerToolbar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .keyboardShortcut(.cancelAction)
            .help("Close this PDF and return to the paper list")

            Divider()
                .frame(height: 22)

            Picker("Viewing mode", selection: $viewingMode) {
                ForEach(PaperViewingMode.allCases) { mode in
                    if paper.hasSolutions != false || mode == .questions {
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
            .disabled(isFlaggingQuestion || isChoosingSolutionsStart)

            Button("Change Solutions Start") {
                viewingMode = .questions
                showSolutionsSetupPrompt = true
            }
            .disabled(isFlaggingQuestion || questionURL == nil)

            Spacer()

            Toggle("Completed", isOn: completionBinding)
                .toggleStyle(.checkbox)

            Button {
                revealPaper()
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }

            Button {
                exportPaper()
            } label: {
                Label("Export PDF", systemImage: "square.and.arrow.up")
            }
            .disabled(questionURL == nil)

            Button {
                beginFlagging()
            } label: {
                Label("Flag Question", systemImage: "flag.badge.plus")
            }
            .disabled(
                isFlaggingQuestion ||
                subject == nil ||
                school == nil ||
                questionURL == nil
            )
            .help("Capture a question for revision")

            Button {
                performOnVisibleControllers { $0.zoomOut() }
            } label: {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .help("Zoom out")

            Button {
                performOnVisibleControllers { $0.fitWidth() }
            } label: {
                Label("Fit Width", systemImage: "arrow.left.and.right")
            }
            .labelStyle(.iconOnly)
            .help("Fit pages to the viewer")

            Button {
                performOnVisibleControllers { $0.zoomIn() }
            } label: {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .help("Zoom in")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var completionBinding: Binding<Bool> {
        Binding(
            get: { paper.isCompleted },
            set: { isCompleted in
                let oldValue = paper.isCompleted
                paper.isCompleted = isCompleted
                do {
                    try modelContext.save()
                } catch {
                    paper.isCompleted = oldValue
                    modelContext.rollback()
                    paperUpdateError = error.localizedDescription
                }
            }
        )
    }

    private func revealPaper() {
        guard let rootURL = appState.rootFolderURL else {
            paperUpdateError = "The app storage folder is unavailable."
            return
        }
        do {
            try FinderRevealService.revealStoredItem(
                relativePath: paper.combinedPDFRelativePath
                    ?? paper.questionPDFRelativePath,
                rootURL: rootURL
            )
        } catch {
            paperUpdateError = error.localizedDescription
        }
    }

    private var captureToolbar: some View {
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

    @ViewBuilder
    private var viewerContent: some View {
        switch viewingMode {
        case .questions:
            documentView(
                url: questionURL,
                selection: isChoosingSolutionsStart ? .all : questionSelection,
                controller: questionController,
                label: "question paper",
                allowsBoundarySelection: isChoosingSolutionsStart
            )
        case .solutions:
            documentView(
                url: solutionURL,
                selection: solutionSelection,
                controller: solutionController,
                label: "solutions paper"
            )
        case .both:
            HSplitView {
                labeledDocumentView(
                    title: "Questions",
                    url: questionURL,
                    selection: questionSelection,
                    controller: questionController,
                    label: "question paper"
                )
                labeledDocumentView(
                    title: "Solutions",
                    url: solutionURL,
                    selection: solutionSelection,
                    controller: solutionController,
                    label: "solutions paper"
                )
            }
        }
    }

    private func labeledDocumentView(
        title: String,
        url: URL?,
        selection: PDFPageSelection,
        controller: PDFViewerController,
        label: String
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
            documentView(
                url: url,
                selection: selection,
                controller: controller,
                label: label
            )
        }
        .frame(minWidth: 320)
    }

    @ViewBuilder
    private func documentView(
        url: URL?,
        selection: PDFPageSelection,
        controller: PDFViewerController,
        label: String,
        allowsBoundarySelection: Bool = false
    ) -> some View {
        if let url {
            if allowsBoundarySelection {
                PDFViewerView(
                    url: url,
                    selection: selection,
                    pageSelectionEnabled: true,
                    onPageSelected: { pageNumber in
                        saveSolutionsStartPage(pageNumber)
                    },
                    controller: controller
                )
            } else {
                PDFViewerView(
                    url: url,
                    selection: selection,
                    controller: controller
                )
            }
        } else {
            ContentUnavailableView(
                "PDF Not Found",
                systemImage: "doc.badge.exclamationmark",
                description: Text(
                    "The \(label) has been moved or deleted. Restore it in the app data folder."
                )
            )
        }
    }

    private func saveSolutionsStartPage(_ pageNumber: Int) {
        guard let questionURL,
              let pageCount = PDFDocument(url: questionURL)?.pageCount,
              pageNumber > 1,
              pageNumber <= pageCount else {
            captureError = "Choose a page after the first page of the paper."
            return
        }
        paper.solutionsStartPage = pageNumber
        paper.hasSolutions = true
        do {
            try modelContext.save()
            isChoosingSolutionsStart = false
            viewingMode = .questions
        } catch {
            modelContext.rollback()
            captureError = error.localizedDescription
        }
    }

    private func saveNoSolutions() {
        paper.solutionsStartPage = nil
        paper.hasSolutions = false
        viewingMode = .questions
        isChoosingSolutionsStart = false
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            captureError = error.localizedDescription
        }
    }

    private var viewerTitle: String {
        let subjectName = subject?.displayName ?? "Unknown Subject"
        let schoolName = school?.displayName ?? "Unknown School"
        return "\(subjectName) · \(schoolName) · \(paper.year)"
    }

    private func fileURL(for relativePath: String) -> URL? {
        guard let rootURL = appState.rootFolderURL else { return nil }
        let url = rootURL.appending(path: relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func performOnVisibleControllers(
        _ action: (PDFViewerController) -> Void
    ) {
        switch viewingMode {
        case .questions:
            action(questionController)
        case .solutions:
            action(solutionController)
        case .both:
            action(questionController)
            action(solutionController)
        }
    }

    private func beginFlagging() {
        questionNumber = ""
        category = .mistake
        includeSolution = paper.hasSolutions != false && paper.solutionsStartPage != nil
        captureError = nil
        isFlaggingQuestion = true
        viewingMode = includeSolution ? .both : .questions

        DispatchQueue.main.async {
            questionController.beginCapture()
            if includeSolution {
                solutionController.beginCapture()
            } else {
                solutionController.endCapture()
            }
        }
    }

    private func finishFlagging() {
        questionController.endCapture()
        solutionController.endCapture()
        isFlaggingQuestion = false
        includeSolution = false
        isSavingQuestion = false
    }

    private func attemptSaveFlaggedQuestion() {
        guard let subject, let school else {
            captureError = "The paper's subject or school is unavailable."
            return
        }
        let trimmedNumber = questionNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNumber.isEmpty else {
            captureError = "Enter a question number."
            return
        }
        guard questionController.captureRange() != nil else {
            captureError = "The question selection could not be read."
            return
        }
        if includeSolution, solutionController.captureRange() == nil {
            captureError = "The solution selection could not be read."
            return
        }

        let isDuplicate = existingQuestions.contains {
            $0.deletedAt == nil &&
            $0.subjectID == subject.id &&
            $0.schoolID == school.id &&
            $0.year == paper.year &&
            $0.questionNumber.localizedCaseInsensitiveCompare(trimmedNumber) == .orderedSame
        }
        if isDuplicate {
            showDuplicateWarning = true
        } else {
            saveFlaggedQuestion()
        }
    }

    private func saveFlaggedQuestion() {
        guard
            let rootURL = appState.rootFolderURL,
            let subject,
            let school,
            let questionURL,
            let questionDocument = loadPDFDocument(
                url: questionURL,
                selection: questionSelection
            ),
            let questionRange = questionController.captureRange()
        else {
            captureError = "The question PDF or data folder is unavailable."
            return
        }

        isSavingQuestion = true

        do {
            let service = FlaggedQuestionCaptureService(rootURL: rootURL)
            let questionPNG = try service.capturePNG(
                from: questionDocument,
                range: questionRange
            )

            let solutionPNG: Data?
            if includeSolution {
                guard
                    let solutionURL,
                    let solutionDocument = loadPDFDocument(
                        url: solutionURL,
                        selection: solutionSelection
                    ),
                    let solutionRange = solutionController.captureRange()
                else {
                    throw FlaggedQuestionCaptureService.CaptureError.invalidPageRange
                }
                solutionPNG = try service.capturePNG(
                    from: solutionDocument,
                    range: solutionRange
                )
            } else {
                solutionPNG = nil
            }

            let images = try service.saveImages(
                questionPNG: questionPNG,
                solutionPNG: solutionPNG,
                subject: subject,
                school: school,
                year: paper.year,
                questionNumber: questionNumber,
                category: category
            )
            let flaggedQuestion = FlaggedQuestion(
                paperID: paper.id,
                subjectID: subject.id,
                schoolID: school.id,
                year: paper.year,
                questionNumber: questionNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                questionImageRelativePath: images.questionRelativePath,
                solutionImageRelativePath: images.solutionRelativePath
            )

            do {
                modelContext.insert(flaggedQuestion)
                try modelContext.save()
                finishFlagging()
            } catch {
                modelContext.delete(flaggedQuestion)
                try? service.deleteImages(for: flaggedQuestion)
                throw error
            }
        } catch {
            captureError = error.localizedDescription
            isSavingQuestion = false
        }
    }

    private func exportPaper() {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            showExportResult = true
            return
        }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        let storedPath = paper.combinedPDFRelativePath ?? paper.questionPDFRelativePath
        savePanel.nameFieldStringValue = (storedPath as NSString).lastPathComponent

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportPaper(
                paper,
                to: destinationURL
            )
            exportMessage = "PDF exported successfully."
        } catch {
            exportedURL = nil
            exportMessage = error.localizedDescription
        }
        showExportResult = true
    }
}
