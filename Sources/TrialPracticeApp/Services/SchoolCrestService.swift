import AppKit
import Foundation

struct SchoolCrestService {
    enum CrestError: LocalizedError {
        case unreadableImage
        case pngCreationFailed

        var errorDescription: String? {
            switch self {
            case .unreadableImage:
                "The selected file is not a readable image."
            case .pngCreationFailed:
                "The school crest could not be converted to PNG."
            }
        }
    }

    func pngData(from sourceURL: URL) throws -> Data {
        try pngData(from: Data(contentsOf: sourceURL))
    }

    func pngData(from data: Data) throws -> Data {
        guard let image = NSImage(data: data) else {
            throw CrestError.unreadableImage
        }
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw CrestError.pngCreationFailed
        }
        return pngData
    }
}
