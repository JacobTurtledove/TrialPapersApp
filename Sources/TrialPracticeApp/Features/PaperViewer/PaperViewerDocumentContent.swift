import AppKit
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
            CenteredDividerHSplitView(resetToken: splitDividerResetToken) {
                labeledDocumentView(
                    title: "Questions",
                    url: questionURL,
                    selection: questionSelection,
                    controller: questionController,
                    viewportRole: .questions,
                    label: "question paper"
                )
            } trailing: {
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
            } else if annotationSession?.isLoading == true ||
                        annotationSession?.didAttemptLoad != true {
                PDFLoadingPlaceholder()
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

private struct PDFLoadingPlaceholder: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.background)
                        .aspectRatio(0.76, contentMode: .fit)
                        .frame(maxWidth: 520)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.secondary.opacity(0.16))
                                    .frame(width: 160, height: 16)

                                ForEach(0..<8, id: \.self) { line in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.secondary.opacity(0.10))
                                        .frame(
                                            width: line % 3 == 0 ? 320 : 400,
                                            height: 8
                                        )
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(34)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(.separator.opacity(0.55), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                        .opacity(index == 0 ? 1 : 0.65)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .topTrailing) {
            ProgressView()
                .controlSize(.small)
                .padding(14)
        }
    }
}

private struct CenteredDividerHSplitView<Leading: View, Trailing: View>: NSViewRepresentable {
    let resetToken: Int
    let leading: Leading
    let trailing: Trailing

    init(
        resetToken: Int,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.resetToken = resetToken
        self.leading = leading()
        self.trailing = trailing()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(resetToken: resetToken)
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let leadingHost = NSHostingView(rootView: leading)
        let trailingHost = NSHostingView(rootView: trailing)
        leadingHost.setContentHuggingPriority(.defaultLow, for: .horizontal)
        trailingHost.setContentHuggingPriority(.defaultLow, for: .horizontal)
        leadingHost.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trailingHost.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        splitView.addArrangedSubview(leadingHost)
        splitView.addArrangedSubview(trailingHost)
        context.coordinator.leadingHost = leadingHost
        context.coordinator.trailingHost = trailingHost

        DispatchQueue.main.async {
            context.coordinator.centerDivider(in: splitView)
        }

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        context.coordinator.leadingHost?.rootView = leading
        context.coordinator.trailingHost?.rootView = trailing

        guard context.coordinator.lastResetToken != resetToken else { return }
        context.coordinator.lastResetToken = resetToken
        DispatchQueue.main.async {
            context.coordinator.centerDivider(in: splitView)
        }
    }

    @MainActor
    final class Coordinator {
        var lastResetToken: Int
        var leadingHost: NSHostingView<Leading>?
        var trailingHost: NSHostingView<Trailing>?

        init(resetToken: Int) {
            lastResetToken = resetToken
        }

        func centerDivider(in splitView: NSSplitView) {
            splitView.layoutSubtreeIfNeeded()
            guard splitView.arrangedSubviews.count == 2 else { return }
            let availableWidth = splitView.bounds.width - splitView.dividerThickness
            guard availableWidth > 0 else { return }
            splitView.setPosition(availableWidth / 2, ofDividerAt: 0)
        }
    }
}
