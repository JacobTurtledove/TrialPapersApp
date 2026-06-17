import Foundation

struct StorageMigrationService {
    enum MigrationVersion: Int, CaseIterable, Comparable {
        case legacySchoolCrestsEmbeddedData = 1

        static func < (lhs: MigrationVersion, rhs: MigrationVersion) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    struct MigrationResult {
        let didChangeModels: Bool
        let latestCompletedVersion: MigrationVersion?
    }

    static let completedMigrationVersionKey =
        "StorageMigrationService.completedMigrationVersion"

    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let crestService: SchoolCrestService

    init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        crestService: SchoolCrestService = SchoolCrestService()
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.crestService = crestService
    }

    func migrateIfNeeded(rootURL: URL, schools: [School]) throws -> MigrationResult {
        let completedRawValue = userDefaults.integer(forKey: Self.completedMigrationVersionKey)
        var didChangeModels = false
        var latestCompletedVersion: MigrationVersion?

        for version in Self.orderedVersions where version.rawValue > completedRawValue {
            switch version {
            case .legacySchoolCrestsEmbeddedData:
                didChangeModels = try migrateLegacySchoolCrests(
                    rootURL: rootURL,
                    schools: schools
                ) || didChangeModels
            }
            latestCompletedVersion = version
        }

        return MigrationResult(
            didChangeModels: didChangeModels,
            latestCompletedVersion: latestCompletedVersion
        )
    }

    func markCompleted(upThrough version: MigrationVersion) {
        userDefaults.set(version.rawValue, forKey: Self.completedMigrationVersionKey)
    }

    private static var orderedVersions: [MigrationVersion] {
        MigrationVersion.allCases.sorted()
    }

    private func migrateLegacySchoolCrests(rootURL: URL, schools: [School]) throws -> Bool {
        var didChangeModels = false

        for school in schools {
            guard let path = school.crestImageRelativePath else { continue }

            let fileURL = rootURL.appending(path: path).standardizedFileURL
            if fileManager.fileExists(atPath: fileURL.path),
               school.crestImageData == nil,
               school.crestSourcePageURL == nil {
                school.crestImageData = try crestService.pngData(
                    from: Data(contentsOf: fileURL)
                )
            }

            school.crestImageRelativePath = nil
            didChangeModels = true
        }

        return didChangeModels
    }
}
