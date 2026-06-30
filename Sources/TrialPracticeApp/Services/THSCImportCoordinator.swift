import Combine
import Foundation
import SwiftData

enum THSCImportListingState: Equatable {
    case queued
    case importing
    case failed
}

@MainActor
final class THSCImportCoordinator: ObservableObject {
    @Published private(set) var isImporting = false
    @Published private(set) var completedCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var queuedListingIDs: Set<String> = []
    @Published private(set) var activeListingID: String?
    @Published private(set) var failedListingIDs: Set<String> = []

    private var importTask: Task<Void, Never>?
    private let service = THSCImportService()

    func startImport(
        listings: [THSCPaperListing],
        subject: Subject,
        rootURL: URL,
        schools: [School],
        importedIdentifiers: Set<String>,
        sourcePageURL: String,
        modelContext: ModelContext
    ) {
        guard !isImporting else { return }

        isImporting = true
        completedCount = 0
        totalCount = listings.count
        statusMessage = nil
        errorMessage = nil
        queuedListingIDs = Set(listings.map(\.id))
        activeListingID = nil
        failedListingIDs = []

        importTask = Task {
            var importedCount = 0
            var failures: [String] = []
            var schoolsByName = Dictionary(
                schools.map { (Self.schoolKey($0.displayName), $0) },
                uniquingKeysWith: { first, _ in first }
            )

            for listing in listings {
                guard !Task.isCancelled else { break }
                activeListingID = listing.id
                queuedListingIDs.remove(listing.id)
                defer {
                    completedCount += 1
                    if activeListingID == listing.id {
                        activeListingID = nil
                    }
                }
                guard
                    !importedIdentifiers.contains(listing.id),
                    !importedIdentifiers.contains(listing.legacyIdentifier)
                else { continue }

                let temporaryURL = FileManager.default.temporaryDirectory
                    .appending(path: "\(UUID().uuidString).pdf")
                defer { try? FileManager.default.removeItem(at: temporaryURL) }

                var importedFiles: ImportedPaperFiles?
                do {
                    let pdfData = try await service.downloadPDF(for: listing)
                    try pdfData.write(to: temporaryURL, options: .atomic)

                    let school = Self.resolveSchool(
                        named: listing.schoolName,
                        schoolsByName: &schoolsByName
                    )
                    let request = PaperImportRequest(
                        subject: subject,
                        school: school,
                        year: listing.year,
                        mode: .combined,
                        questionPDFURL: temporaryURL,
                        solutionsPDFURL: nil
                    )
                    let files = try PaperImportService(rootURL: rootURL).importPaper(request)
                    importedFiles = files

                    let paper = Paper(
                        subjectID: subject.id,
                        schoolID: school.id,
                        year: listing.year,
                        questionPDFRelativePath: files.combinedRelativePath,
                        solutionsPDFRelativePath: files.combinedRelativePath,
                        combinedPDFRelativePath: files.combinedRelativePath,
                        hasSolutions: listing.hasSolutions
                    )
                    if school.modelContext == nil {
                        modelContext.insert(school)
                    }
                    modelContext.insert(paper)
                    modelContext.insert(
                        THSCImportRecord(
                            sourceIdentifier: listing.id,
                            sourceTitle: listing.title,
                            sourcePageURL: sourcePageURL,
                            paperID: paper.id
                        )
                    )
                    try modelContext.save()
                    importedCount += 1
                } catch {
                    modelContext.rollback()
                    if let importedFiles {
                        PaperImportService(rootURL: rootURL).discardImportedFiles(importedFiles)
                    }
                    failedListingIDs.insert(listing.id)
                    failures.append("\(listing.title): \(error.localizedDescription)")
                }
            }

            isImporting = false
            queuedListingIDs = []
            activeListingID = nil
            statusMessage =
                "Imported \(importedCount) complete paper\(importedCount == 1 ? "" : "s")."
            errorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
            importTask = nil
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func importState(for listing: THSCPaperListing) -> THSCImportListingState? {
        if activeListingID == listing.id {
            return .importing
        }
        if queuedListingIDs.contains(listing.id) {
            return .queued
        }
        if failedListingIDs.contains(listing.id) {
            return .failed
        }
        return nil
    }

    private static func schoolKey(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func resolveSchool(
        named rawName: String,
        schoolsByName: inout [String: School]
    ) -> School {
        let displayName = NameNormalizer.displayName(from: rawName)
        let key = schoolKey(displayName)
        if let existing = schoolsByName[key] {
            return existing
        }
        let school = School(
            displayName: displayName,
            filenameValue: NameNormalizer.filenameValue(from: displayName)
        )
        schoolsByName[key] = school
        return school
    }
}
