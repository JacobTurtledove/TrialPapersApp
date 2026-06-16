import AppKit
import Foundation

struct FinderRevealService {
    enum RevealError: LocalizedError {
        case missingItem
        case itemOutsideRoot

        var errorDescription: String? {
            switch self {
            case .missingItem:
                "The file or folder could not be found."
            case .itemOutsideRoot:
                "The requested item is outside the app data folder."
            }
        }
    }

    static func storedURL(relativePath: String, rootURL: URL) throws -> URL {
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = root
            .appending(path: relativePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard
            candidate.path == root.path ||
            candidate.path.hasPrefix(root.path + "/")
        else {
            throw RevealError.itemOutsideRoot
        }
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw RevealError.missingItem
        }
        return candidate
    }

    static func revealStoredItem(relativePath: String, rootURL: URL) throws {
        reveal(try storedURL(relativePath: relativePath, rootURL: rootURL))
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
