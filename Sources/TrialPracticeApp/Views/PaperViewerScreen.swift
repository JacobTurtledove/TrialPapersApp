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

private struct PDFPenColorChoice: Identifiable {
    let name: String
    let hex: String

    var id: String { hex }
}

private let pdfPenColorChoices: [PDFPenColorChoice] = [
    PDFPenColorChoice(name: "Black", hex: "#000000"),
    PDFPenColorChoice(name: "Red", hex: "#D92D20"),
    PDFPenColorChoice(name: "Blue", hex: "#2563EB"),
    PDFPenColorChoice(name: "Green", hex: "#16A34A"),
    PDFPenColorChoice(name: "Purple", hex: "#7C3AED"),
    PDFPenColorChoice(name: "Orange", hex: "#EA580C"),
    PDFPenColorChoice(name: "Yellow", hex: "#FACC15"),
    PDFPenColorChoice(name: "Gray", hex: "#6B7280")
]

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
    @State private var showSolutionsStartPicker = false
    @State private var selectedSolutionsStartPage = 1
    @State private var selectedDrawingTool: PDFDrawingTool = .none
    @AppStorage("pdfViewer.pen1.colorHex") private var pen1ColorHex = "#000000"
    @AppStorage("pdfViewer.pen1.lineWidth") private var pen1LineWidth = 4.0
    @AppStorage("pdfViewer.pen2.colorHex") private var pen2ColorHex = "#D92D20"
    @AppStorage("pdfViewer.pen2.lineWidth") private var pen2LineWidth = 4.0
    @StateObject private var questionController = PDFViewerController()
    @StateObject private var solutionController = PDFViewerController()
    @StateObject private var questionAnnotationSession = PDFAnnotationSession()
    @StateObject private var solutionAnnotationSession = PDFAnnotationSession()

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

    private var paperPageCount: Int? {
        guard let questionURL else { return nil }
        return PDFDocument(url: questionURL)?.pageCount
    }

    private var penConfigurations: [PDFPenConfiguration] {
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

    private var activeDrawingTool: PDFDrawingTool {
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

    private var viewerToolbar: some View {
        HStack(spacing: 12) {
            Button {
                saveAnnotationsAndDismiss()
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
            .disabled(isFlaggingQuestion)

            Divider()
                .frame(height: 34)

            penToolControls

            Toggle("Completed", isOn: completionBinding)
                .toggleStyle(.checkbox)

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
                performOnVisibleControllers { $0.fitWidth() }
            } label: {
                Label("Fit Width", systemImage: "arrow.left.and.right")
            }
            .labelStyle(.iconOnly)
            .help("Fit pages to the viewer")

            Menu {
                Button {
                    viewingMode = .questions
                    presentSolutionsStartPicker()
                } label: {
                    Label("Set First Page of Solutions", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(isFlaggingQuestion || questionURL == nil)

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
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help("More actions")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var penToolControls: some View {
        HStack(spacing: 10) {
            penPresetControl(
                index: 0,
                colorHex: $pen1ColorHex,
                lineWidth: $pen1LineWidth
            )
            penPresetControl(
                index: 1,
                colorHex: $pen2ColorHex,
                lineWidth: $pen2LineWidth
            )

            Button {
                selectedDrawingTool = selectedDrawingTool == .eraser ? .none : .eraser
            } label: {
                Image(systemName: "eraser")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        selectedDrawingTool == .eraser
                            ? Color.accentColor
                            : Color.clear,
                        lineWidth: 2
                    )
            )
            .disabled(isFlaggingQuestion)
            .help("Erase drawn strokes")

            Spacer()
        }
    }

    private func penPresetControl(
        index: Int,
        colorHex: Binding<String>,
        lineWidth: Binding<Double>
    ) -> some View {
        VStack(spacing: 3) {
            Button {
                let tool: PDFDrawingTool = .pen(index)
                selectedDrawingTool = selectedDrawingTool == tool ? .none : tool
            } label: {
                PenCircle(
                    colorHex: colorHex.wrappedValue,
                    lineWidth: clampedPenWidth(lineWidth.wrappedValue)
                )
                .frame(width: 28, height: 24)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        selectedDrawingTool == .pen(index)
                            ? Color.accentColor
                            : Color.clear,
                        lineWidth: 2
                    )
            )

            penOptionsMenu(
                colorHex: colorHex,
                lineWidth: lineWidth
            )
        }
        .frame(width: 38)
        .disabled(isFlaggingQuestion)
        .help(index == 0 ? "Pen preset 1" : "Pen preset 2")
    }

    private func penOptionsMenu(
        colorHex: Binding<String>,
        lineWidth: Binding<Double>
    ) -> some View {
        Menu {
            Section("Color") {
                ForEach(pdfPenColorChoices) { choice in
                    Button {
                        colorHex.wrappedValue = choice.hex
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(nsColor: NSColor(hexRGB: choice.hex) ?? .black))
                                .frame(width: 9, height: 9)
                            Text(choice.name)
                            if colorHex.wrappedValue == choice.hex {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                ColorPicker(
                    "More Colors",
                    selection: colorBinding(for: colorHex),
                    supportsOpacity: false
                )
            }

            Section("Size") {
                Picker("Size", selection: lineWidth) {
                    ForEach(2...18, id: \.self) { size in
                        Text("\(size) pt").tag(Double(size))
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.down.circle")
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
        .frame(width: 26, height: 18)
    }

    private func colorBinding(for colorHex: Binding<String>) -> Binding<Color> {
        Binding(
            get: {
                Color(nsColor: NSColor(hexRGB: colorHex.wrappedValue) ?? .black)
            },
            set: { color in
                let nsColor = NSColor(color)
                colorHex.wrappedValue = (
                    nsColor.usingColorSpace(.deviceRGB) ?? nsColor
                ).hexRGBString
            }
        )
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
                selection: questionSelection,
                controller: questionController,
                label: "question paper"
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
        label: String
    ) -> some View {
        if let url {
            let annotationSession = annotationSession(for: url)
            PDFViewerView(
                url: url,
                sourceDocument: annotationSession?.document,
                selection: selection,
                drawingTool: activeDrawingTool,
                penConfigurations: penConfigurations,
                onAnnotationsChanged: {
                    annotationSession?.markDirty()
                },
                onAnnotationError: { message in
                    paperUpdateError = message
                },
                controller: controller
            )
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

    private func presentSolutionsStartPicker() {
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

    private func loadAnnotationSessions() {
        questionAnnotationSession.load(url: questionURL)
        if solutionURL == questionURL {
            solutionAnnotationSession.load(url: nil)
        } else {
            solutionAnnotationSession.load(url: solutionURL)
        }
    }

    private func annotationSession(for url: URL) -> PDFAnnotationSession? {
        if url == questionURL {
            questionAnnotationSession
        } else if url == solutionURL {
            solutionURL == questionURL ? questionAnnotationSession : solutionAnnotationSession
        } else {
            nil
        }
    }

    private func savePendingAnnotations() throws {
        try questionAnnotationSession.saveIfNeeded()
        if solutionURL != questionURL {
            try solutionAnnotationSession.saveIfNeeded()
        }
    }

    private func saveAnnotationsAndDismiss() {
        do {
            try savePendingAnnotations()
            dismiss()
        } catch {
            paperUpdateError = error.localizedDescription
        }
    }

    private func clampedPenWidth(_ width: Double) -> Double {
        min(18, max(2, width.rounded()))
    }

    private func beginFlagging() {
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

private struct PenCircle: View {
    let colorHex: String
    let lineWidth: Double

    private var diameter: CGFloat {
        CGFloat(min(24, max(8, lineWidth + 6)))
    }

    var body: some View {
        Circle()
            .fill(Color(nsColor: NSColor(hexRGB: colorHex) ?? .black))
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle()
                    .stroke(Color.primary.opacity(0.18), lineWidth: 1)
            }
            .frame(width: 28, height: 24)
    }
}

private struct SolutionsStartPagePickerSheet: View {
    let url: URL
    let pageCount: Int
    @Binding var selectedPage: Int
    @FocusState private var isKeyboardNavigationFocused: Bool
    let allowsCancel: Bool
    let cancel: () -> Void
    let markNoSolutions: () -> Void
    let confirm: () -> Void

    private var canMoveBackward: Bool {
        selectedPage > 1
    }

    private var canMoveForward: Bool {
        selectedPage < pageCount
    }

    private var sliderValue: Binding<Double> {
        Binding(
            get: { Double(selectedPage) },
            set: { selectedPage = clampedPage(Int($0.rounded())) }
        )
    }

    private var pageTextValue: Binding<Int> {
        Binding(
            get: { selectedPage },
            set: { selectedPage = clampedPage($0) }
        )
    }

    private func previousPage() {
        selectedPage = clampedPage(selectedPage - 1)
    }

    private func nextPage() {
        selectedPage = clampedPage(selectedPage + 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select the first page with solutions")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            PDFPagePreviewView(url: url, pageNumber: selectedPage)
                .frame(width: 540, height: 620)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Button {
                        previousPage()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canMoveBackward)
                    .help("Previous page")

                    Text("Page")
                        .foregroundStyle(.secondary)

                    TextField("Page", value: pageTextValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 72)

                    Text("of \(pageCount)")
                        .foregroundStyle(.secondary)

                    Button {
                        nextPage()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canMoveForward)
                    .help("Next page")

                    Slider(
                        value: sliderValue,
                        in: 1...Double(max(pageCount, 1))
                    )
                }

                HStack {
                    Button("This Paper Has No Solutions", action: markNoSolutions)

                    Spacer()

                    if allowsCancel {
                        Button("Cancel", role: .cancel, action: cancel)
                    }

                    Button("This is the first solutions page", action: confirm)
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedPage <= 1)
                }
            }
            .padding(20)
        }
        .frame(width: 580)
        .focusable()
        .focused($isKeyboardNavigationFocused)
        .onAppear {
            isKeyboardNavigationFocused = true
        }
        .onMoveCommand { direction in
            switch direction {
            case .left, .up:
                previousPage()
            case .right, .down:
                nextPage()
            @unknown default:
                break
            }
        }
    }

    private func clampedPage(_ page: Int) -> Int {
        min(max(page, 1), max(pageCount, 1))
    }
}
