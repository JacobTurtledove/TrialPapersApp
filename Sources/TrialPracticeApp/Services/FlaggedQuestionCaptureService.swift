import AppKit
import Foundation
import PDFKit

struct PDFCaptureRange: Equatable {
    let startPage: Int
    let endPage: Int
    let topBoundary: Double
    let bottomBoundary: Double
}

struct SavedFlaggedQuestionImages {
    let questionRelativePath: String
    let solutionRelativePath: String?
}

struct FlaggedQuestionCaptureService {
    enum CaptureError: LocalizedError {
        case invalidPageRange
        case invalidBoundaries
        case unreadablePage(Int)
        case imageCreationFailed
        case invalidQuestionNumber

        var errorDescription: String? {
            switch self {
            case .invalidPageRange:
                "Select a valid start and end page."
            case .invalidBoundaries:
                "The bottom boundary must be below the top boundary."
            case .unreadablePage(let page):
                "Page \(page) could not be captured."
            case .imageCreationFailed:
                "The captured image could not be created."
            case .invalidQuestionNumber:
                "Enter a question number containing letters or numbers."
            }
        }
    }

    let rootURL: URL

    func capturePNG(
        from document: PDFDocument,
        range: PDFCaptureRange,
        targetWidth: Int = 1600
    ) throws -> Data {
        guard
            range.startPage >= 0,
            range.endPage >= range.startPage,
            range.endPage < document.pageCount
        else {
            throw CaptureError.invalidPageRange
        }
        guard
            (0...1).contains(range.topBoundary),
            (0...1).contains(range.bottomBoundary)
        else {
            throw CaptureError.invalidBoundaries
        }
        if range.startPage == range.endPage,
           range.topBoundary >= range.bottomBoundary {
            throw CaptureError.invalidBoundaries
        }

        var fragments: [CGImage] = []
        for pageIndex in range.startPage...range.endPage {
            guard let page = document.page(at: pageIndex) else {
                throw CaptureError.unreadablePage(pageIndex + 1)
            }

            let pageBounds = page.bounds(for: .mediaBox)
            let height = max(
                1,
                Int((CGFloat(targetWidth) * pageBounds.height / pageBounds.width).rounded())
            )
            let thumbnail = page.thumbnail(
                of: NSSize(width: targetWidth, height: height),
                for: .mediaBox
            )
            var proposedRect = NSRect(origin: .zero, size: thumbnail.size)
            guard let pageImage = thumbnail.cgImage(
                forProposedRect: &proposedRect,
                context: nil,
                hints: nil
            ) else {
                throw CaptureError.unreadablePage(pageIndex + 1)
            }

            let top = pageIndex == range.startPage ? range.topBoundary : 0
            let bottom = pageIndex == range.endPage ? range.bottomBoundary : 1
            guard top < bottom || range.startPage != range.endPage else {
                throw CaptureError.invalidBoundaries
            }

            let cropY = Int((Double(pageImage.height) * top).rounded(.down))
            let cropBottom = Int((Double(pageImage.height) * bottom).rounded(.up))
            let cropRect = CGRect(
                x: 0,
                y: cropY,
                width: pageImage.width,
                height: max(1, cropBottom - cropY)
            )
            guard let fragment = pageImage.cropping(to: cropRect) else {
                throw CaptureError.imageCreationFailed
            }
            fragments.append(fragment)
        }

        let outputWidth = fragments.map(\.width).max() ?? targetWidth
        let outputHeight = fragments.reduce(0) { $0 + $1.height }
        guard
            let context = CGContext(
                data: nil,
                width: outputWidth,
                height: outputHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw CaptureError.imageCreationFailed
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

        var consumedHeight = 0
        for fragment in fragments {
            let y = outputHeight - consumedHeight - fragment.height
            context.draw(
                fragment,
                in: CGRect(x: 0, y: y, width: fragment.width, height: fragment.height)
            )
            consumedHeight += fragment.height
        }

        guard let stitchedImage = context.makeImage() else {
            throw CaptureError.imageCreationFailed
        }
        let representation = NSBitmapImageRep(cgImage: stitchedImage)
        guard let pngData = representation.representation(using: .png, properties: [:]) else {
            throw CaptureError.imageCreationFailed
        }
        return pngData
    }

    func saveImages(
        questionPNG: Data,
        solutionPNG: Data?,
        subject: Subject,
        school: School,
        year: String,
        questionNumber: String,
        category: QuestionCategory
    ) throws -> SavedFlaggedQuestionImages {
        let questionToken = try normalizedQuestionToken(questionNumber)
        let categoryFolder = category == .mistake ? "Mistakes" : "Unlearned Content"
        let directoryPath =
            "Flagged Questions/\(subject.filenameValue)/\(categoryFolder)/\(year)"
        let directoryURL = rootURL.appending(path: directoryPath, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let baseName = "\(subject.filenameValue)_\(school.filenameValue)_\(year)_\(questionToken)"
        var duplicateIndex = 1
        while imageFilesExist(
            baseName: baseName,
            duplicateIndex: duplicateIndex,
            hasSolution: solutionPNG != nil,
            in: directoryURL
        ) {
            duplicateIndex += 1
        }

        let suffix = duplicateIndex == 1 ? "" : "_\(duplicateIndex)"
        let questionFilename = "\(baseName)\(suffix).png"
        let solutionFilename = "\(baseName)\(suffix)_sol.png"
        let questionRelativePath = "\(directoryPath)/\(questionFilename)"
        let solutionRelativePath = solutionPNG.map { _ in
            "\(directoryPath)/\(solutionFilename)"
        }
        let questionURL = rootURL.appending(path: questionRelativePath)

        do {
            try questionPNG.write(to: questionURL, options: .atomic)
            if let solutionPNG, let solutionRelativePath {
                try solutionPNG.write(
                    to: rootURL.appending(path: solutionRelativePath),
                    options: .atomic
                )
            }
        } catch {
            try? FileManager.default.removeItem(at: questionURL)
            if let solutionRelativePath {
                try? FileManager.default.removeItem(
                    at: rootURL.appending(path: solutionRelativePath)
                )
            }
            throw error
        }

        return SavedFlaggedQuestionImages(
            questionRelativePath: questionRelativePath,
            solutionRelativePath: solutionRelativePath
        )
    }

    func deleteImages(for question: FlaggedQuestion) throws {
        let paths = [
            question.questionImageRelativePath,
            question.solutionImageRelativePath
        ].compactMap { $0 }

        for path in Set(paths) {
            let url = try StoredFilePath(path).url(relativeTo: rootURL)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    private func imageFilesExist(
        baseName: String,
        duplicateIndex: Int,
        hasSolution: Bool,
        in directoryURL: URL
    ) -> Bool {
        let suffix = duplicateIndex == 1 ? "" : "_\(duplicateIndex)"
        let questionFilename = "\(baseName)\(suffix).png"
        if FileManager.default.fileExists(
            atPath: directoryURL.appending(path: questionFilename).path
        ) {
            return true
        }

        guard hasSolution else { return false }
        let solutionFilename = "\(baseName)\(suffix)_sol.png"
        return FileManager.default.fileExists(
            atPath: directoryURL.appending(path: solutionFilename).path
        )
    }

    private func normalizedQuestionToken(_ rawValue: String) throws -> String {
        var value = rawValue.filter { $0.isLetter || $0.isNumber }
        if value.first == "q" || value.first == "Q" {
            value.removeFirst()
        }
        guard !value.isEmpty else {
            throw CaptureError.invalidQuestionNumber
        }
        return "Q\(value)"
    }
}
