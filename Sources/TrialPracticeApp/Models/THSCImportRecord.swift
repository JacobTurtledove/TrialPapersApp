import Foundation
import SwiftData

@Model
final class THSCImportRecord {
    @Attribute(.unique) var sourceIdentifier: String
    var sourceTitle: String
    var sourcePageURL: String
    var paperID: UUID?
    var importedAt: Date

    init(
        sourceIdentifier: String,
        sourceTitle: String,
        sourcePageURL: String,
        paperID: UUID?,
        importedAt: Date = .now
    ) {
        self.sourceIdentifier = sourceIdentifier
        self.sourceTitle = sourceTitle
        self.sourcePageURL = sourcePageURL
        self.paperID = paperID
        self.importedAt = importedAt
    }
}
