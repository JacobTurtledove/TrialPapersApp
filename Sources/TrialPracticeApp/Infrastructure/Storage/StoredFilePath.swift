import Foundation

struct StoredFilePath: Hashable, Codable, Sendable, CustomStringConvertible {
    enum ValidationError: Error, Equatable {
        case empty
        case absolute
        case emptyComponent
        case currentDirectoryComponent
        case parentDirectoryComponent
        case outsideRoot
    }

    let rawValue: String

    var description: String {
        rawValue
    }

    init(_ rawValue: String) throws {
        try Self.validate(rawValue)
        self.rawValue = rawValue
    }

    func url(relativeTo rootURL: URL) throws -> URL {
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        var candidate = root

        for component in rawValue.split(separator: "/") {
            candidate = candidate
                .appending(path: String(component))
                .standardizedFileURL
                .resolvingSymlinksInPath()

            guard Self.isContained(candidate, in: root) else {
                throw ValidationError.outsideRoot
            }
        }

        return candidate
    }

    private static func isContained(_ url: URL, in root: URL) -> Bool {
        url.path == root.path || url.path.hasPrefix(root.path + "/")
    }

    private static func validate(_ rawValue: String) throws {
        guard !rawValue.isEmpty else {
            throw ValidationError.empty
        }
        guard !rawValue.hasPrefix("/") else {
            throw ValidationError.absolute
        }

        let components = rawValue.split(separator: "/", omittingEmptySubsequences: false)
        for component in components {
            switch component {
            case "":
                throw ValidationError.emptyComponent
            case ".":
                throw ValidationError.currentDirectoryComponent
            case "..":
                throw ValidationError.parentDirectoryComponent
            default:
                continue
            }
        }
    }
}
