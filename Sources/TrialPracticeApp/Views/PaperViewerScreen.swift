import AppKit
import PDFKit
import SwiftData
import SwiftUI

struct PaperViewerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var pdfViewportStore: PDFViewerViewportStore
    @Environment(\.modelContext) private var modelContext
    @Query private var existingQuestions: [FlaggedQuestion]

    let paper: Paper
    let subject: Subject?
    let school: School?

    @State var viewingMode: PaperViewingMode = .questions
    @State var isFlaggingQuestion = false
    @State var questionNumber = ""
    @State var category: QuestionCategory = .mistake
    @State var includeSolution = true
    @State var isSavingQuestion = false
    @State private var captureError: String?
    @State var paperUpdateError: String?
    @State private var exportMessage: String?
    @State private var showExportResult = false
    @State private var exportedURL: URL?
    @State private var showDuplicateWarning = false
    @State private var showSolutionsStartPicker = false
    @State private var selectedSolutionsStartPage = 1
    @State var selectedDrawingTool: PDFDrawingTool = .none
    @AppStorage("pdfViewer.pen1.colorHex") var pen1ColorHex = "#000000"
    @AppStorage("pdfViewer.pen1.lineWidth") var pen1LineWidth = 4.0
    @AppStorage("pdfViewer.pen2.colorHex") var pen2ColorHex = "#D92D20"
    @AppStorage("pdfViewer.pen2.lineWidth") var pen2LineWidth = 4.0
    @StateObject var questionController = PDFViewerController()
    @StateObject var solutionController = PDFViewerController()
    @StateObject private var questionAnnotationSession = PDFAnnotationSession()
    @StateObject private var solutionAnnotationSession = PDFAnnotationSession()

    var questionURL: URL? {
        fileURL(for: paper.primaryPDFRelativePath)
    }

    var solutionURL: URL? {
        fileURL(for: paper.combinedPDFRelativePath ?? paper.solutionsPDFRelativePath)
    }

    var questionSelection: PDFPageSelection {
        paper.solutionsStartPage.map { .questions(before: $0) } ?? .all
    }

    var solutionSelection: PDFPageSelection {
        paper.solutionsStartPage.map { .solutions(from: $0) } ?? .all
    }

    private var paperPageCount: Int? {
        guard let questionURL else { return nil }
        return PDFDocument(url: questionURL)?.pageCount
    }

    var penConfigurations: [PDFPenConfiguration] {
        [
            PDFPenConfiguration(
                colorHex: pen1ColorHex,
                lineWidth: clampedPenWidth(pen1LineWidth)
            ),
            PDFPenConfiguration(
                colorHex: pen2ColorHex,
                lineWidth: clampedPenWidth(pen2LineWidth)
            )
        ]
    }

    var activeDrawingTool: PDFDrawingTool {
        isFlaggingQuestion ? .none : selectedDrawingTool
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
            loadAnnotationSessions()
            if paper.hasSolutions != false, paper.solutionsStartPage == nil {
                viewingMode = .questions
                presentSolutionsStartPicker()
            } else if paper.hasSolutions != false {
                viewingMode = .both
            } else {
                viewingMode = .questions
            }
        }
        .onChange(of: questionURL) {
            loadAnnotationSessions()
        }
        .onChange(of: solutionURL) {
            loadAnnotationSessions()
        }
        .onDisappear {
            do {
                try savePendingAnnotations()
                pdfViewportStore.flushPendingPersistence()
            } catch {
                paperUpdateError = error.localizedDescription
            }
        }
        .sheet(isPresented: $showSolutionsStartPicker) {
            if let questionURL, let paperPageCount {
                SolutionsStartPagePickerSheet(
                    url: questionURL,
                    pageCount: paperPageCount,
                    selectedPage: $selectedSolutionsStartPage,
                    allowsCancel: paper.solutionsStartPage != nil || paper.hasSolutions != nil,
                    cancel: {
                        showSolutionsStartPicker = false
                    },
                    markNoSolutions: {
                        saveNoSolutions()
                    },
                    confirm: {
                        saveSolutionsStartPage(selectedSolutionsStartPage)
                    }
                )
            }
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

    var completionBinding: Binding<Bool> {
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

    func revealPaper() {
        guard let rootURL = appState.rootFolderURL else {
            paperUpdateError = "The app storage folder is unavailable."
            return
        }
        do {
            try FinderRevealService.revealStoredItem(
                relativePath: paper.primaryPDFRelativePath,
                rootURL: rootURL
            )
        } catch {
            paperUpdateError = error.localizedDescription
        }
    }

    func presentSolutionsStartPicker() {
        guard let pageCount = paperPageCount else { return }
        selectedSolutionsStartPage = min(
            pageCount,
            max(1, paper.solutionsStartPage ?? min(max(2, pageCount / 2), pageCount))
        )
        showSolutionsStartPicker = true
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
            showSolutionsStartPicker = false
            pdfViewportStore.clearPositions(for: paper.id)
            viewingMode = .both
        } catch {
            modelContext.rollback()
            captureError = error.localizedDescription
        }
    }

    private func saveNoSolutions() {
        paper.solutionsStartPage = nil
        paper.hasSolutions = false
        viewingMode = .questions
        showSolutionsStartPicker = false
        do {
            try modelContext.save()
            pdfViewportStore.clearPositions(for: paper.id)
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

    func performOnVisibleControllers(
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

    private func loadAnnotationSessions() {
        questionAnnotationSession.load(url: questionURL)
        if solutionURL == questionURL {
            solutionAnnotationSession.load(url: nil)
        } else {
            solutionAnnotationSession.load(url: solutionURL)
        }
    }

    func annotationSession(for url: URL) -> PDFAnnotationSession? {
        if url == questionURL {
            questionAnnotationSession
        } else if url == solutionURL {
            solutionURL == questionURL ? questionAnnotationSession : solutionAnnotationSession
        } else {
            nil
        }
    }

    func viewportPosition(for role: PDFViewportDocumentRole) -> PDFViewportPosition? {
        pdfViewportStore.position(for: paper.id, role: role)
    }

    func saveViewportPosition(
        _ position: PDFViewportPosition,
        for role: PDFViewportDocumentRole
    ) {
        pdfViewportStore.setPosition(position, for: paper.id, role: role)
    }

    private func savePendingAnnotations() throws {
        try questionAnnotationSession.saveIfNeeded()
        if solutionURL != questionURL {
            try solutionAnnotationSession.saveIfNeeded()
        }
    }

    func saveAnnotationsAndDismiss() {
        do {
            try savePendingAnnotations()
            pdfViewportStore.flushPendingPersistence()
            dismiss()
        } catch {
            paperUpdateError = error.localizedDescription
        }
    }

    func clampedPenWidth(_ width: Double) -> Double {
        min(18, max(2, width.rounded()))
    }

    func beginFlagging() {
        do {
            try savePendingAnnotations()
        } catch {
            captureError = error.localizedDescription
            return
        }

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

    func finishFlagging() {
        questionController.endCapture()
        solutionController.endCapture()
        isFlaggingQuestion = false
        includeSolution = false
        isSavingQuestion = false
    }

    func attemptSaveFlaggedQuestion() {
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
            let solutionDocument: PDFDocument?
            let solutionRange: PDFCaptureRange?
            if includeSolution {
                guard
                    let solutionURL,
                    let loadedSolutionDocument = loadPDFDocument(
                        url: solutionURL,
                        selection: solutionSelection
                    ),
                    let loadedSolutionRange = solutionController.captureRange()
                else {
                    throw FlaggedQuestionCaptureService.CaptureError.invalidPageRange
                }
                solutionDocument = loadedSolutionDocument
                solutionRange = loadedSolutionRange
            } else {
                solutionDocument = nil
                solutionRange = nil
            }

            _ = try FlaggedQuestionSaveService(rootURL: rootURL).save(
                FlaggedQuestionSaveRequest(
                    paper: paper,
                    subject: subject,
                    school: school,
                    questionDocument: questionDocument,
                    questionRange: questionRange,
                    solutionDocument: solutionDocument,
                    solutionRange: solutionRange,
                    questionNumber: questionNumber,
                    category: category
                ),
                modelContext: modelContext
            )
            finishFlagging()
        } catch {
            captureError = error.localizedDescription
            isSavingQuestion = false
        }
    }

    func exportPaper() {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            showExportResult = true
            return
        }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        let storedPath = paper.primaryPDFRelativePath
        savePanel.nameFieldStringValue = (storedPath as NSString).lastPathComponent

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        do {
            try savePendingAnnotations()
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
