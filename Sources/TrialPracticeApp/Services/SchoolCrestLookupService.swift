import Foundation

struct SchoolCrestLookupResult: Equatable, Sendable {
    let imageURL: URL
    let sourcePageURL: URL?
}

struct SchoolCrestLookupService: Sendable {
    struct Manifest: Decodable, Sendable {
        let version: Int
        let schools: [Entry]
    }

    struct Entry: Decodable, Sendable {
        let name: String
        let file: String
        let officialName: String
        let sourceURL: String?
        let aliases: [String]

        var matchingNames: [String] {
            [name, officialName] + aliases
        }
    }

    enum LookupError: LocalizedError {
        case missingPack
        case invalidManifest
        case missingImage(String)

        var errorDescription: String? {
            switch self {
            case .missingPack:
                "The curated school crest pack is missing from the app."
            case .invalidManifest:
                "The curated school crest manifest could not be read."
            case .missingImage(let name):
                "The curated crest image for \(name) is missing."
            }
        }
    }

    private let packURL: URL?

    init(packURL: URL? = Self.bundledPackURL) {
        self.packURL = packURL
    }

    func findCrest(for schoolName: String) throws -> SchoolCrestLookupResult? {
        guard let packURL else {
            throw LookupError.missingPack
        }
        let manifest = try loadManifest(from: packURL)
        guard let entry = Self.bestEntry(for: schoolName, in: manifest.schools) else {
            return nil
        }

        let imageURL = packURL.appending(path: entry.file).standardizedFileURL
        let packPath = packURL.standardizedFileURL.path
        guard
            imageURL.path.hasPrefix(packPath + "/"),
            FileManager.default.fileExists(atPath: imageURL.path)
        else {
            throw LookupError.missingImage(entry.name)
        }

        return SchoolCrestLookupResult(
            imageURL: imageURL,
            sourcePageURL: entry.sourceURL.flatMap(URL.init(string:))
        )
    }

    func imageData(for schoolName: String) throws -> Data? {
        try findCrest(for: schoolName).map { try Data(contentsOf: $0.imageURL) }
    }

    static func bestEntry(for schoolName: String, in entries: [Entry]) -> Entry? {
        let normalizedName = normalized(schoolName)

        if let canonical = entries.first(where: { normalized($0.name) == normalizedName }) {
            return canonical
        }
        if let official = entries.first(where: {
            normalized($0.officialName) == normalizedName
        }) {
            return official
        }

        let aliasMatches = entries.filter {
            $0.aliases.contains { normalized($0) == normalizedName }
        }
        return aliasMatches.count == 1 ? aliasMatches[0] : nil
    }

    private static var bundledPackURL: URL? {
        packCandidates.first { isReadablePack(at: $0) }
    }

    private func loadManifest(from packURL: URL) throws -> Manifest {
        let manifestURL = packURL.appending(path: "manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.version == 1 else {
            throw LookupError.invalidManifest
        }
        return manifest
    }

    private static var packCandidates: [URL] {
        var urls: [URL] = []

        if let bundledURL = Bundle.main.url(
            forResource: "School Crest Pack",
            withExtension: nil
        ) {
            urls.append(bundledURL)
        }

        if let resourceURL = Bundle.main.resourceURL {
            urls.append(
                resourceURL.appending(
                    path: "School Crest Pack",
                    directoryHint: .isDirectory
                )
            )
        }

        if let executableURL = Bundle.main.executableURL {
            urls.append(contentsOf: developmentPackCandidates(from: executableURL))
        }

        urls.append(contentsOf: developmentPackCandidates(from: URL(fileURLWithPath: #filePath)))

        return urls.uniquedByStandardizedFilePath()
    }

    private static func developmentPackCandidates(from url: URL) -> [URL] {
        var candidates: [URL] = []
        var directory = url.standardizedFileURL
        if !directory.hasDirectoryPath {
            directory.deleteLastPathComponent()
        }

        while directory.path != "/" {
            candidates.append(
                directory.appending(
                    path: "School Crest Pack",
                    directoryHint: .isDirectory
                )
            )
            directory.deleteLastPathComponent()
        }

        return candidates
    }

    private static func isReadablePack(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return FileManager.default.isReadableFile(
            atPath: url.appending(path: "manifest.json").path
        )
    }

    private static func normalized(_ value: String) -> String {
        value.unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map { String($0).lowercased() }
            .joined()
    }
}

private extension Array where Element == URL {
    func uniquedByStandardizedFilePath() -> [URL] {
        var seen: Set<String> = []
        return filter { url in
            seen.insert(url.standardizedFileURL.path).inserted
        }
    }
}
