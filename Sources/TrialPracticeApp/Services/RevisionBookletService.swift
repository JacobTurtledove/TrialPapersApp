import AppKit
import Foundation

struct RevisionBookletEntry {
    let schoolName: String
    let year: String
    let questionNumber: String
    let category: QuestionCategory
    var status: FlaggedQuestionStudyStatus = .active
    var priority: FlaggedQuestionPriority = .normal
    var topic: String?
    var marksAvailable: Int?
    let questionImageURL: URL
    let solutionImageURL: URL?
}

struct RevisionBookletService {
    enum ExportError: LocalizedError {
        case noQuestions
        case couldNotCreatePDF
        case missingQuestionImage(String)

        var errorDescription: String? {
            switch self {
            case .noQuestions:
                "No flagged questions match the selected filters."
            case .couldNotCreatePDF:
                "The revision booklet PDF could not be created."
            case .missingQuestionImage(let questionNumber):
                "The image for question \(questionNumber) could not be loaded."
            }
        }
    }

    private let pageSize = CGSize(width: 595, height: 842)
    private let margin: CGFloat = 52

    func export(
        subjectName: String,
        entries: [RevisionBookletEntry],
        answerPlacement: RevisionBookletAnswerPlacement = .afterEachQuestion,
        workingPageCount: Int = 0,
        generatedAt: Date = .now,
        to destinationURL: URL
    ) throws {
        guard !entries.isEmpty else {
            throw ExportError.noQuestions
        }

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard
            let consumer = CGDataConsumer(url: destinationURL as CFURL),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw ExportError.couldNotCreatePDF
        }

        drawTitlePage(
            subjectName: subjectName,
            entries: entries,
            generatedAt: generatedAt,
            in: context,
            mediaBox: mediaBox
        )

        for entry in entries {
            try drawQuestionPage(
                entry: entry,
                subjectName: subjectName,
                in: context,
                mediaBox: mediaBox
            )
            let safeWorkingPageCount = max(0, workingPageCount)
            if safeWorkingPageCount > 0 {
                for index in 1...safeWorkingPageCount {
                    drawWorkingPage(
                        entry: entry,
                        subjectName: subjectName,
                        pageNumber: index,
                        totalPages: safeWorkingPageCount,
                        in: context,
                        mediaBox: mediaBox
                    )
                }
            }
            if answerPlacement == .afterEachQuestion {
                drawSolutionPage(
                    entry: entry,
                    subjectName: subjectName,
                    in: context,
                    mediaBox: mediaBox
                )
            }
        }

        if answerPlacement == .answersAtEnd {
            for entry in entries {
                drawSolutionPage(
                    entry: entry,
                    subjectName: subjectName,
                    in: context,
                    mediaBox: mediaBox
                )
            }
        }

        context.closePDF()
    }

    private func drawQuestionPage(
        entry: RevisionBookletEntry,
        subjectName: String,
        in context: CGContext,
        mediaBox: CGRect
    ) throws {
        guard let questionImage = NSImage(contentsOf: entry.questionImageURL) else {
            throw ExportError.missingQuestionImage(entry.questionNumber)
        }
        drawImagePage(
            title: "Question \(entry.questionNumber)",
            subtitle: questionSubtitle(entry: entry, subjectName: subjectName),
            image: questionImage,
            in: context,
            mediaBox: mediaBox
        )
    }

    private func drawSolutionPage(
        entry: RevisionBookletEntry,
        subjectName: String,
        in context: CGContext,
        mediaBox: CGRect
    ) {
        if
            let solutionImageURL = entry.solutionImageURL,
            let solutionImage = NSImage(contentsOf: solutionImageURL)
        {
            drawImagePage(
                title: "Solution · Question \(entry.questionNumber)",
                subtitle: questionSubtitle(entry: entry, subjectName: subjectName),
                image: solutionImage,
                in: context,
                mediaBox: mediaBox
            )
        } else {
            drawMissingSolutionPage(
                entry: entry,
                subjectName: subjectName,
                in: context,
                mediaBox: mediaBox
            )
        }
    }

    private func drawTitlePage(
        subjectName: String,
        entries: [RevisionBookletEntry],
        generatedAt: Date,
        in context: CGContext,
        mediaBox: CGRect
    ) {
        context.beginPDFPage(nil)
        withGraphicsContext(context) {
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 34, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ]
            let subjectAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 25, weight: .semibold),
                .foregroundColor: NSColor.controlAccentColor
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 17),
                .foregroundColor: NSColor.labelColor
            ]

            draw(
                "Revision Booklet",
                at: CGPoint(x: margin, y: mediaBox.height - 150),
                attributes: titleAttributes
            )
            draw(
                subjectName,
                at: CGPoint(x: margin, y: mediaBox.height - 205),
                attributes: subjectAttributes
            )

            let mistakes = entries.filter { $0.category == .mistake }.count
            let unlearned = entries.count - mistakes
            let mastered = entries.filter { $0.status == .mastered }.count
            let date = generatedAt.formatted(date: .long, time: .omitted)
            let summary = [
                "Date Generated: \(date)",
                "Total Questions: \(entries.count)",
                "Mistakes: \(mistakes)",
                "Unlearned Content: \(unlearned)",
                "Mastered: \(mastered)"
            ]

            for (index, line) in summary.enumerated() {
                draw(
                    line,
                    at: CGPoint(x: margin, y: mediaBox.height - 300 - CGFloat(index * 38)),
                    attributes: bodyAttributes
                )
            }
        }
        context.endPDFPage()
    }

    private func drawImagePage(
        title: String,
        subtitle: String,
        image: NSImage,
        in context: CGContext,
        mediaBox: CGRect
    ) {
        context.beginPDFPage(nil)
        withGraphicsContext(context) {
            drawPageHeader(title: title, subtitle: subtitle, mediaBox: mediaBox)

            let availableRect = CGRect(
                x: margin,
                y: margin,
                width: mediaBox.width - margin * 2,
                height: mediaBox.height - margin * 2 - 90
            )
            image.draw(
                in: aspectFitRect(imageSize: image.size, inside: availableRect),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
        }
        context.endPDFPage()
    }

    private func drawMissingSolutionPage(
        entry: RevisionBookletEntry,
        subjectName: String,
        in context: CGContext,
        mediaBox: CGRect
    ) {
        context.beginPDFPage(nil)
        withGraphicsContext(context) {
            drawPageHeader(
                title: "Solution · Question \(entry.questionNumber)",
                subtitle: questionSubtitle(entry: entry, subjectName: subjectName),
                mediaBox: mediaBox
            )
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 23, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let text = NSAttributedString(
                string: "No solution provided",
                attributes: attributes
            )
            let size = text.size()
            text.draw(
                at: CGPoint(
                    x: (mediaBox.width - size.width) / 2,
                    y: (mediaBox.height - size.height) / 2
                )
            )
        }
        context.endPDFPage()
    }

    private func drawWorkingPage(
        entry: RevisionBookletEntry,
        subjectName: String,
        pageNumber: Int,
        totalPages: Int,
        in context: CGContext,
        mediaBox: CGRect
    ) {
        context.beginPDFPage(nil)
        withGraphicsContext(context) {
            drawPageHeader(
                title: "Working · Question \(entry.questionNumber)",
                subtitle: "\(questionSubtitle(entry: entry, subjectName: subjectName)) · Page \(pageNumber) of \(totalPages)",
                mediaBox: mediaBox
            )
            let lineColor = NSColor.separatorColor.withAlphaComponent(0.5)
            lineColor.setStroke()
            let path = NSBezierPath()
            let startY = mediaBox.height - 140
            let endY = margin + 20
            var y = startY
            while y >= endY {
                path.move(to: CGPoint(x: margin, y: y))
                path.line(to: CGPoint(x: mediaBox.width - margin, y: y))
                y -= 28
            }
            path.lineWidth = 0.7
            path.stroke()
        }
        context.endPDFPage()
    }

    private func drawPageHeader(title: String, subtitle: String, mediaBox: CGRect) {
        draw(
            title,
            at: CGPoint(x: margin, y: mediaBox.height - 70),
            attributes: [
                .font: NSFont.systemFont(ofSize: 21, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        draw(
            subtitle,
            at: CGPoint(x: margin, y: mediaBox.height - 98),
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }

    private func questionSubtitle(entry: RevisionBookletEntry, subjectName: String) -> String {
        var parts = [
            subjectName,
            entry.schoolName,
            entry.year,
            entry.status.rawValue,
            entry.priority.rawValue
        ]
        if let marksAvailable = entry.marksAvailable {
            parts.append("\(marksAvailable) marks")
        }
        if let topic = entry.topic, !topic.isEmpty {
            parts.append(topic)
        }
        return parts.joined(separator: " · ")
    }

    private func draw(
        _ string: String,
        at point: CGPoint,
        attributes: [NSAttributedString.Key: Any]
    ) {
        NSAttributedString(string: string, attributes: attributes).draw(at: point)
    }

    private func aspectFitRect(imageSize: CGSize, inside rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func withGraphicsContext(
        _ context: CGContext,
        draw: () -> Void
    ) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }
}
