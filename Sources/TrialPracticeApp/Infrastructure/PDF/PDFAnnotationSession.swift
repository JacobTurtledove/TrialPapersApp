import Combine
import Foundation
import PDFKit

@MainActor
final class PDFAnnotationSession: ObservableObject {
    @Published private(set) var document: PDFDocument?
    @Published private(set) var didAttemptLoad = false
    private(set) var url: URL?
    private var isDirty = false
    private var autosaveTask: Task<Void, Never>?

    func load(url: URL?) {
        guard self.url != url else { return }
        autosaveTask?.cancel()
        autosaveTask = nil
        self.url = url
        didAttemptLoad = url != nil
        document = url.flatMap { PDFDocument(url: $0) }
        isDirty = false
    }

    func markDirty() {
        isDirty = true
    }

    func saveIfNeeded() throws {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard isDirty, let document, let url else { return }
        guard document.write(to: url) else {
            throw PDFAnnotationPersistenceError.couldNotWriteDocument
        }
        isDirty = false
    }

    func makeDeferredSaveRequestIfNeeded() -> PDFAnnotationSaveRequest? {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard isDirty, let document, let url else { return nil }
        isDirty = false
        return PDFAnnotationSaveRequest(document: document, url: url)
    }

    func scheduleAutosave(
        enqueue: @escaping @MainActor (PDFAnnotationSaveRequest) -> Void
    ) {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1_500))
            guard
                !Task.isCancelled,
                let request = self?.makeDeferredSaveRequestIfNeeded()
            else { return }
            enqueue(request)
        }
    }
}

struct PDFAnnotationSaveRequest: Identifiable {
    let id = UUID()
    let document: PDFDocument
    let url: URL

    func save() throws {
        guard document.write(to: url) else {
            throw PDFAnnotationPersistenceError.couldNotWriteDocument
        }
    }
}

struct PDFAnnotationSaveFailure: Identifiable {
    let id = UUID()
    let message: String
}

@MainActor
final class PDFAnnotationSaveCoordinator: ObservableObject {
    @Published private(set) var saveFailure: PDFAnnotationSaveFailure?
    @Published private(set) var pendingSaveURLs: Set<URL> = []

    private var pendingRequests: [PDFAnnotationSaveRequest] = []
    private var activeRequest: PDFAnnotationSaveRequest?
    private var failedRequest: PDFAnnotationSaveRequest?
    private var saveTask: Task<Void, Never>?

    func enqueue(_ requests: [PDFAnnotationSaveRequest]) {
        guard !requests.isEmpty else { return }
        for request in requests where !hasRequestQueued(for: request.url) {
            pendingRequests.append(request)
        }
        refreshPendingSaveURLs()
        startSavingIfNeeded()
    }

    func hasPendingSave(for url: URL) -> Bool {
        pendingSaveURLs.contains(normalized(url))
    }

    func clearFailure() {
        saveFailure = nil
        failedRequest = nil
        refreshPendingSaveURLs()
        startSavingIfNeeded()
    }

    func retryFailedSave() {
        guard let failedRequest else { return }
        self.failedRequest = nil
        saveFailure = nil
        pendingRequests.insert(failedRequest, at: 0)
        refreshPendingSaveURLs()
        startSavingIfNeeded()
    }

    private func startSavingIfNeeded() {
        guard saveTask == nil, failedRequest == nil else { return }
        saveTask = Task { @MainActor [weak self] in
            await Task.yield()
            self?.processPendingRequests()
        }
    }

    private func processPendingRequests() {
        defer {
            saveTask = nil
        }

        while !pendingRequests.isEmpty {
            let request = pendingRequests.removeFirst()
            activeRequest = request
            refreshPendingSaveURLs()
            do {
                try request.save()
                activeRequest = nil
                refreshPendingSaveURLs()
            } catch {
                failedRequest = request
                activeRequest = nil
                saveFailure = PDFAnnotationSaveFailure(
                    message: "Annotations for \(request.url.lastPathComponent) could not be saved. \(error.localizedDescription)"
                )
                refreshPendingSaveURLs()
                return
            }
        }
    }

    private func hasRequestQueued(for url: URL) -> Bool {
        let normalizedURL = normalized(url)
        return pendingRequests.contains { normalized($0.url) == normalizedURL } ||
            activeRequest.map { normalized($0.url) == normalizedURL } == true ||
            failedRequest.map { normalized($0.url) == normalizedURL } == true
    }

    private func refreshPendingSaveURLs() {
        var urls = Set(pendingRequests.map { normalized($0.url) })
        if let activeRequest {
            urls.insert(normalized(activeRequest.url))
        }
        if let failedRequest {
            urls.insert(normalized(failedRequest.url))
        }
        pendingSaveURLs = urls
    }

    private func normalized(_ url: URL) -> URL {
        url.standardizedFileURL
    }
}

enum PDFAnnotationPersistenceError: LocalizedError {
    case couldNotOpenDocument
    case couldNotWriteDocument

    var errorDescription: String? {
        switch self {
        case .couldNotOpenDocument:
            "The PDF could not be opened for annotation."
        case .couldNotWriteDocument:
            "The PDF annotations could not be saved."
        }
    }
}
