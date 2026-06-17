import SwiftData
import SwiftUI

struct THSCImportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject var importCoordinator: THSCImportCoordinator

    @Query(sort: \Subject.displayName) private var subjects: [Subject]
    @Query private var schools: [School]
    @Query private var papers: [Paper]
    @Query private var importRecords: [THSCImportRecord]

    @State var listings: [THSCPaperListing] = []
    @State var selection: Set<String> = []
    @State var expandedSchoolIDs: Set<String> = []
    @State var searchText = ""
    @State var solutionsFilter = THSCSolutionsFilter.all
    @State var showAlreadyImported = false
    @State var isLoading = false
    @State var statusMessage: String?
    @State private var errorMessage: String?
    @State private var showSlowWebsiteWarning = false
    @State private var loadTask: Task<Void, Never>?
    @AppStorage("hasSeenTHSCSlowWebsiteWarning")
    private var hasSeenSlowWebsiteWarning = false
    @AppStorage("lastTHSCImportSubjectID")
    var selectedSubjectIDString = ""
    @AppStorage("lastTHSCImportSourceID")
    var selectedSourceIDString = ""

    private let service = THSCImportService()

    var activeSubjects: [Subject] {
        subjects.filter { $0.deletedAt == nil }
    }

    var selectedSubjectID: UUID? {
        UUID(uuidString: selectedSubjectIDString)
    }

    var selectedSource: THSCSource? {
        THSCSource.presets.first { $0.id == selectedSourceIDString }
    }

    private var importIdentifiersForSelectedSource: Set<String> {
        guard let selectedSource else { return [] }
        return Set(
            importRecords.flatMap { record in
                if record.sourceIdentifier.hasPrefix("thsc:http") {
                    return [record.sourceIdentifier]
                }
                if record.sourcePageURL == selectedSource.pageURL.absoluteString {
                    return [record.sourceIdentifier]
                }
                return []
            }
        )
    }

    private var filteredListings: [THSCPaperListing] {
        return listings.filter {
            (showAlreadyImported || !isImported($0)) &&
            solutionsFilter.includes($0) && (
                searchText.isEmpty ||
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.schoolName.localizedCaseInsensitiveContains(searchText) ||
                $0.year.contains(searchText)
            )
        }
    }

    var schoolGroups: [THSCSchoolPaperGroup] {
        Dictionary(grouping: filteredListings) { listing in
            NameNormalizer.displayName(from: listing.schoolName)
        }
        .map { schoolName, papers in
            THSCSchoolPaperGroup(
                id: schoolName.normalizedTHSCSchoolGroupID,
                schoolName: schoolName,
                papers: papers.sorted {
                    if $0.year != $1.year { return $0.year > $1.year }
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
            )
        }
        .sorted {
            $0.schoolName.localizedStandardCompare($1.schoolName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            paperList
            importBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Import from THSC")
        .task {
            if !selectedSubjectIDString.isEmpty,
               !activeSubjects.contains(where: { $0.id.uuidString == selectedSubjectIDString }) {
                selectedSubjectIDString = ""
            }
            if !selectedSourceIDString.isEmpty,
               !THSCSource.presets.contains(where: { $0.id == selectedSourceIDString }) {
                selectedSourceIDString = ""
            }
            if !hasSeenSlowWebsiteWarning {
                showSlowWebsiteWarning = true
            }
        }
        .onChange(of: selectedSourceIDString) {
            loadTask?.cancel()
            loadTask = nil
            isLoading = false
            selection.removeAll()
            expandedSchoolIDs.removeAll()
            listings.removeAll()
            statusMessage = nil
        }
        .onChange(of: selectedSubjectIDString) {
            selection.removeAll()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
            isLoading = false
        }
        .alert("THSC Can Be Very Slow", isPresented: $showSlowWebsiteWarning) {
            Button("Continue") {
                hasSeenSlowWebsiteWarning = true
            }
        } message: {
            Text(
                "THSC sometimes takes a long time to return its paper lists and downloads. The app may appear to wait while the website responds."
            )
        }
        .alert(
            "THSC Import Error",
            isPresented: Binding(
                get: { errorMessage != nil || importCoordinator.errorMessage != nil },
                set: {
                    if !$0 {
                        errorMessage = nil
                        importCoordinator.clearError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? importCoordinator.errorMessage ?? "")
        }
    }

    func startLoadingPapers() {
        guard let source = selectedSource else { return }
        loadTask?.cancel()
        loadTask = Task {
            await loadPapers(from: source)
        }
    }

    private func loadPapers(from source: THSCSource) async {
        isLoading = true
        statusMessage = nil

        do {
            let loadedListings = try await service.fetchListing(from: source)
                .sorted {
                    if $0.year != $1.year { return $0.year > $1.year }
                    return $0.schoolName.localizedStandardCompare($1.schoolName) == .orderedAscending
                }
            guard !Task.isCancelled, selectedSource == source else { return }
            listings = loadedListings
            expandedSchoolIDs.removeAll()
        } catch {
            guard !Task.isCancelled, selectedSource == source else { return }
            errorMessage = error.localizedDescription
        }
        if selectedSource == source {
            isLoading = false
            loadTask = nil
        }
    }

    func toggleSelection(_ paper: THSCPaperListing) {
        if selection.contains(paper.id) {
            selection.remove(paper.id)
        } else if selection.count < 10 {
            selection.insert(paper.id)
        }
    }

    func isImported(_ listing: THSCPaperListing) -> Bool {
        importIdentifiersForSelectedSource.contains(listing.id) ||
            importIdentifiersForSelectedSource.contains(listing.legacyIdentifier)
    }

    func toggleSchoolGroup(_ id: String) {
        withAnimation(.easeOut(duration: 0.12)) {
            if expandedSchoolIDs.contains(id) {
                expandedSchoolIDs.remove(id)
            } else {
                expandedSchoolIDs.insert(id)
            }
        }
    }

    func hasLocalPaperConflict(_ listing: THSCPaperListing) -> Bool {
        guard let subjectID = selectedSubjectID else { return false }
        let normalizedSchool = NameNormalizer.displayName(from: listing.schoolName)
        guard let school = schools.first(where: {
            $0.displayName.localizedCaseInsensitiveCompare(normalizedSchool) == .orderedSame
        }) else {
            return false
        }
        return papers.contains {
            $0.subjectID == subjectID &&
            $0.schoolID == school.id &&
            $0.year == listing.year
        }
    }

    func importSelectedPapers() {
        guard
            let subjectID = selectedSubjectID,
            let subject = activeSubjects.first(where: { $0.id == subjectID }),
            let rootURL = appState.rootFolderURL,
            let selectedSource
        else {
            errorMessage = "Select a subject and reconnect the app data folder."
            return
        }

        let selectedPapers = listings.filter { selection.contains($0.id) }
        guard selectedPapers.count <= 10 else {
            errorMessage = "Select no more than 10 papers."
            return
        }

        statusMessage = nil
        importCoordinator.startImport(
            listings: selectedPapers,
            subject: subject,
            rootURL: rootURL,
            schools: schools,
            importedIdentifiers: importIdentifiersForSelectedSource,
            sourcePageURL: selectedSource.pageURL.absoluteString,
            modelContext: modelContext
        )
        selection.removeAll()
    }
}
