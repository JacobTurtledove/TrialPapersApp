import SwiftUI

extension PaperViewerScreen {
    @ViewBuilder
    var viewerContent: some View {
        switch viewingMode {
        case .questions:
            documentView(
                url: questionURL,
                selection: questionSelection,
                controller: questionController,
                viewportRole: .questions,
                label: "question paper"
            )
        case .solutions:
            documentView(
                url: solutionURL,
                selection: solutionSelection,
                controller: solutionController,
                viewportRole: .solutions,
                label: "solutions paper"
            )
        case .both:
            HSplitView {
                labeledDocumentView(
                    title: "Questions",
                    url: questionURL,
                    selection: questionSelection,
                    controller: questionController,
                    viewportRole: .questions,
                    label: "question paper"
                )
                labeledDocumentView(
                    title: "Solutions",
                    url: solutionURL,
                    selection: solutionSelection,
                    controller: solutionController,
                    viewportRole: .solutions,
                    label: "solutions paper"
                )
            }
        }
    }

    func labeledDocumentView(
        title: String,
        url: URL?,
        selection: PDFPageSelection,
        controller: PDFViewerController,
        viewportRole: PDFViewportDocumentRole,
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
                viewportRole: viewportRole,
                label: label
            )
        }
        .frame(minWidth: 320)
    }

    @ViewBuilder
    func documentView(
        url: URL?,
        selection: PDFPageSelection,
        controller: PDFViewerController,
        viewportRole: PDFViewportDocumentRole,
        label: String
    ) -> some View {
        if let url {
            let annotationSession = annotationSession(for: url)
            if let document = annotationSession?.document {
                PDFViewerView(
                    url: url,
                    sourceDocument: document,
                    selection: selection,
                    viewportPosition: viewportPosition(for: viewportRole),
                    drawingTool: activeDrawingTool,
                    penConfigurations: penConfigurations,
                    onViewportChanged: { position in
                        saveViewportPosition(position, for: viewportRole)
                    },
                    onAnnotationsChanged: {
                        annotationSession?.markDirty()
                        scheduleAnnotationAutosave(for: annotationSession)
                    },
                    onAnnotationError: { message in
                        paperUpdateError = message
                    },
                    controller: controller
                )
            } else if hasPendingAnnotationSave(for: url) {
                ProgressView("Saving annotations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if annotationSession?.didAttemptLoad == true {
                ContentUnavailableView(
                    "PDF Not Found",
                    systemImage: "doc.badge.exclamationmark",
                    description: Text(
                        "The \(label) could not be opened. Restore it in the app data folder."
                    )
                )
            } else {
                ProgressView("Loading PDF...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}
