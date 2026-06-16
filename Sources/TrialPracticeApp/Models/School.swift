import Foundation
import SwiftData

@Model
final class School {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var filenameValue: String
    @Attribute(.externalStorage) var crestImageData: Data?
    var crestImageRelativePath: String?
    var crestSourcePageURL: String?
    var crestLookupAttemptedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        filenameValue: String,
        crestImageData: Data? = nil,
        crestImageRelativePath: String? = nil,
        crestSourcePageURL: String? = nil,
        crestLookupAttemptedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.filenameValue = filenameValue
        self.crestImageData = crestImageData
        self.crestImageRelativePath = crestImageRelativePath
        self.crestSourcePageURL = crestSourcePageURL
        self.crestLookupAttemptedAt = crestLookupAttemptedAt
        self.createdAt = createdAt
    }
}
