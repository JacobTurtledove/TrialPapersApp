import Foundation

enum THSCSolutionsFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case withSolutions = "With Solutions"
    case withoutSolutions = "Without Solutions"

    var id: Self { self }

    func includes(_ listing: THSCPaperListing) -> Bool {
        switch self {
        case .all:
            true
        case .withSolutions:
            listing.hasSolutions
        case .withoutSolutions:
            !listing.hasSolutions
        }
    }
}

struct THSCSchoolPaperGroup: Identifiable {
    let id: String
    let schoolName: String
    let papers: [THSCPaperListing]
}

extension String {
    var normalizedTHSCSchoolGroupID: String {
        split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }
}
