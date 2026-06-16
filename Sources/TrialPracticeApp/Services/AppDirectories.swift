import Foundation

enum AppDirectories {
    static var applicationSupport: URL {
        get throws {
            try appDirectory(for: .applicationSupportDirectory)
        }
    }

    static var caches: URL {
        get throws {
            try appDirectory(for: .cachesDirectory)
        }
    }

    static var swiftDataStoreURL: URL {
        get throws {
            let storeURL = try applicationSupport.appending(path: "Database.sqlite")
            try migrateLegacyDefaultSwiftDataStoreIfNeeded(to: storeURL)
            return storeURL
        }
    }

    static var fileStorageURL: URL {
        get throws {
            let url = try applicationSupport.appending(path: "Files", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
    }

    static func removeCaches() throws {
        try removeContents(of: caches)
    }

    static func removeLegacyDefaultSwiftDataStore() throws {
        let legacyURL = try applicationSupport
            .deletingLastPathComponent()
            .appending(path: "default.store")
        let fileManager = FileManager.default
        for url in [
            legacyURL,
            sqliteSidecarURL(for: legacyURL, suffix: "-wal"),
            sqliteSidecarURL(for: legacyURL, suffix: "-shm")
        ] where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    static func appDirectory(
        for directory: FileManager.SearchPathDirectory,
        fileManager: FileManager = .default,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) throws -> URL {
        let baseURL = try fileManager.url(
            for: directory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return try appDirectory(
            in: baseURL,
            fileManager: fileManager,
            bundleIdentifier: bundleIdentifier
        )
    }

    static func appDirectory(
        in baseURL: URL,
        fileManager: FileManager = .default,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) throws -> URL {
        let appFolderName = bundleIdentifier ?? "App"
        let appURL = baseURL.appending(path: appFolderName, directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: appURL,
            withIntermediateDirectories: true
        )
        return appURL
    }

    private static func migrateLegacyDefaultSwiftDataStoreIfNeeded(
        to destinationURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard !fileManager.fileExists(atPath: destinationURL.path) else { return }

        let legacyURL = destinationURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "default.store")
        guard fileManager.fileExists(atPath: legacyURL.path) else { return }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let filePairs = [
            (legacyURL, destinationURL),
            (
                sqliteSidecarURL(for: legacyURL, suffix: "-wal"),
                sqliteSidecarURL(for: destinationURL, suffix: "-wal")
            ),
            (
                sqliteSidecarURL(for: legacyURL, suffix: "-shm"),
                sqliteSidecarURL(for: destinationURL, suffix: "-shm")
            )
        ]

        for (source, destination) in filePairs where fileManager.fileExists(atPath: source.path) {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    private static func sqliteSidecarURL(for storeURL: URL, suffix: String) -> URL {
        URL(fileURLWithPath: storeURL.path + suffix)
    }

    private static func removeContents(of directoryURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}
