import CryptoKit
import Foundation
import PDFKit

struct THSCSource: Identifiable, Hashable {
    let name: String
    let pageURL: URL

    var id: String { pageURL.absoluteString }
}

struct THSCPaperListing: Identifiable, Hashable, Sendable {
    let viewID: Int
    let title: String
    let schoolName: String
    let year: String
    let sourcePageURL: String?

    var hasSolutions: Bool {
        title.range(
            of: #"\bw\.\s*sol(?:s|utions?)?\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    var id: String {
        sourceScopedIdentifier ?? legacyIdentifier
    }

    var legacyIdentifier: String {
        "thsc:\(viewID):\(title.normalizedTHSCIdentifier)"
    }

    var sourceScopedIdentifier: String? {
        sourcePageURL.map {
            "thsc:\($0.normalizedTHSCIdentifier):\(viewID):\(title.normalizedTHSCIdentifier)"
        }
    }

    init(
        viewID: Int,
        title: String,
        schoolName: String,
        year: String,
        sourcePageURL: String? = nil
    ) {
        self.viewID = viewID
        self.title = title
        self.schoolName = schoolName
        self.year = year
        self.sourcePageURL = sourcePageURL
    }
}

struct THSCImportService: Sendable {
    enum ImportError: LocalizedError {
        case invalidResponse
        case invalidListing
        case invalidDownload
        case serverError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "THSC returned an invalid response."
            case .invalidListing:
                "No importable papers were found on this THSC page."
            case .invalidDownload:
                "THSC did not return a readable PDF."
            case .serverError(let statusCode):
                "THSC returned HTTP status \(statusCode)."
            }
        }
    }

    private struct DownloadPayload: Decodable {
        let data: String
        let mimetype: String
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchListing(from source: THSCSource) async throws -> [THSCPaperListing] {
        let (data, response) = try await session.data(from: source.pageURL)
        try validate(response)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidResponse
        }

        let papers = Self.parseListingHTML(html)
        guard !papers.isEmpty else {
            throw ImportError.invalidListing
        }
        return papers.map { listing in
            THSCPaperListing(
                viewID: listing.viewID,
                title: listing.title,
                schoolName: listing.schoolName,
                year: listing.year,
                sourcePageURL: source.pageURL.absoluteString
            )
        }
    }

    func downloadPDF(for paper: THSCPaperListing) async throws -> Data {
        let hash = SHA256.hash(data: Data(String(paper.viewID).utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        var components = URLComponents(
            string: "https://script.google.com/macros/s/AKfycbx69GPoJtf9sSevsUbWtPr46vpa01u4oNkHjFmkkWxmj62AZ0q-/exec"
        )
        components?.queryItems = [
            URLQueryItem(name: "export", value: "data"),
            URLQueryItem(name: "field", value: paper.title),
            URLQueryItem(name: "base", value: String(paper.viewID)),
            URLQueryItem(name: "hash", value: hash)
        ]
        guard let url = components?.url else {
            throw ImportError.invalidDownload
        }

        let (data, response) = try await session.data(from: url)
        try validate(response)
        guard
            let script = String(data: data, encoding: .utf8),
            let openBrace = script.firstIndex(of: "{"),
            let closeBrace = script.lastIndex(of: "}"),
            openBrace < closeBrace
        else {
            throw ImportError.invalidDownload
        }

        let jsonData = Data(script[openBrace...closeBrace].utf8)
        let payload = try JSONDecoder().decode(DownloadPayload.self, from: jsonData)
        guard
            payload.mimetype.localizedCaseInsensitiveContains("pdf"),
            let pdfData = Data(base64Encoded: payload.data),
            PDFDocument(data: pdfData) != nil
        else {
            throw ImportError.invalidDownload
        }
        return pdfData
    }

    static func parseListingHTML(_ html: String) -> [THSCPaperListing] {
        let pattern = #"onClick\s*=\s*["']pdf\(this,\s*(\d+)\)["'][^>]*>(.*?)</a>"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return expression.matches(in: html, range: range).compactMap { match in
            guard
                let viewRange = Range(match.range(at: 1), in: html),
                let titleRange = Range(match.range(at: 2), in: html),
                let viewID = Int(html[viewRange])
            else {
                return nil
            }

            let rawTitle = String(html[titleRange])
                .replacingOccurrences(
                    of: #"<[^>]+>"#,
                    with: "",
                    options: .regularExpression
                )
            let title = decodeHTMLEntities(rawTitle)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let metadata = parseTitle(title) else {
                return nil
            }

            return THSCPaperListing(
                viewID: viewID,
                title: title,
                schoolName: metadata.school,
                year: metadata.year
            )
        }
    }

    private static func parseTitle(_ title: String) -> (school: String, year: String)? {
        let cleaned = title.replacingOccurrences(
            of: #"\s+w\.\s*sol(?:s|utions?)?\s*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        guard let yearRange = cleaned.range(
            of: #"\b(19|20)\d{2}\b(?=\D*$)"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let school = cleaned[..<yearRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !school.isEmpty else { return nil }
        return (school, String(cleaned[yearRange]))
    }

    private static func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw ImportError.invalidResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw ImportError.serverError(response.statusCode)
        }
    }
}

private extension String {
    var normalizedTHSCIdentifier: String {
        split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }
}
