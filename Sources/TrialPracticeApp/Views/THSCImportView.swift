import SwiftData
import SwiftUI

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

struct THSCImportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var importCoordinator: THSCImportCoordinator

    @Query(sort: \Subject.displayName) private var subjects: [Subject]
    @Query private var schools: [School]
    @Query private var papers: [Paper]
    @Query private var importRecords: [THSCImportRecord]

    @State private var subjectID: UUID?
    @State private var selectedSource = THSCSource.presets[1]
    @State private var listings: [THSCPaperListing] = []
    @State private var selection: Set<String> = []
    @State private var searchText = ""
    @State private var solutionsFilter = THSCSolutionsFilter.all
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var showSlowWebsiteWarning = false
    @State private var loadTask: Task<Void, Never>?
    @AppStorage("hasSeenTHSCSlowWebsiteWarning")
    private var hasSeenSlowWebsiteWarning = false

    private let service = THSCImportService()

    private var activeSubjects: [Subject] {
        subjects.filter { $0.deletedAt == nil }
    }

    private var importIdentifiersForSelectedSource: Set<String> {
        Set(
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
            solutionsFilter.includes($0) && (
                searchText.isEmpty ||
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.schoolName.localizedCaseInsensitiveContains(searchText) ||
                $0.year.contains(searchText)
            )
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
            subjectID = subjectID ?? activeSubjects.first?.id
            if !hasSeenSlowWebsiteWarning {
                showSlowWebsiteWarning = true
            }
        }
        .onChange(of: selectedSource) {
            loadTask?.cancel()
            loadTask = nil
            isLoading = false
            selection.removeAll()
            listings.removeAll()
            statusMessage = nil
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

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("Save to subject", selection: $subjectID) {
                    Text("Select a subject").tag(nil as UUID?)
                    ForEach(activeSubjects) { subject in
                        Text(subject.displayName).tag(subject.id as UUID?)
                    }
                }
                .frame(maxWidth: 320)

                Picker("THSC collection", selection: $selectedSource) {
                    ForEach(THSCSource.presets) { source in
                        Text(source.name).tag(source)
                    }
                }
                .frame(maxWidth: 340)

                if !listings.isEmpty {
                    Button("Reload Papers") {
                        startLoadingPapers()
                    }
                    .disabled(isLoading || importCoordinator.isImporting)
                }

                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Contacting THSC…")
                            .font(.callout.weight(.medium))
                    }
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.tint.opacity(0.1), in: Capsule())
                }
            }

            if !listings.isEmpty {
                HStack {
                    TextField("Search school or year", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)

                    Picker("Solutions", selection: $solutionsFilter) {
                        ForEach(THSCSolutionsFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 340)

                    Text("\(selection.count) of 10 selected")
                        .foregroundStyle(selection.count == 10 ? .orange : .secondary)
                    Spacer()
                    Text("Previously imported papers cannot be selected again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var paperList: some View {
        if activeSubjects.isEmpty {
            ContentUnavailableView(
                "Create a Subject First",
                systemImage: "folder.badge.plus",
                description: Text("THSC papers need a subject folder in your library.")
            )
        } else if isLoading {
            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)

                Text("Loading Papers from THSC…")
                    .font(.title2.bold())

                Text("THSC is often very slow. Keep this page open while the website responds.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }
            .padding(36)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.tint.opacity(0.35), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if listings.isEmpty {
            ContentUnavailableView {
                Label("No Papers Loaded", systemImage: "arrow.down.doc")
            } description: {
                Text("Load the selected THSC collection to view its available papers.")
            } actions: {
                Button {
                    startLoadingPapers()
                } label: {
                    Label("Load Papers", systemImage: "arrow.down.doc.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(importCoordinator.isImporting)
            }
        } else {
            List(filteredListings) { paper in
                let imported = isImported(paper)
                let conflict = hasLocalPaperConflict(paper)

                HStack(spacing: 12) {
                    Button {
                        toggleSelection(paper)
                    } label: {
                        Image(systemName: selection.contains(paper.id) ? "checkmark.square.fill" : "square")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(imported || conflict || importCoordinator.isImporting)

                    Text(paper.title)

                    Spacer()

                    Group {
                        if imported {
                            Label("Imported", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if conflict {
                            Text("Already in library")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .frame(width: 125, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !imported, !conflict, !importCoordinator.isImporting {
                        toggleSelection(paper)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }
            .listStyle(.inset)
        }
    }

    private var importBar: some View {
        HStack {
            if let message = importCoordinator.statusMessage ?? statusMessage {
                Text(message)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Import \(selection.count) Paper\(selection.count == 1 ? "" : "s")") {
                importSelectedPapers()
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                selection.isEmpty ||
                subjectID == nil ||
                importCoordinator.isImporting ||
                isLoading
            )
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func startLoadingPapers() {
        loadTask?.cancel()
        let source = selectedSource
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
        } catch {
            guard !Task.isCancelled, selectedSource == source else { return }
            errorMessage = error.localizedDescription
        }
        if selectedSource == source {
            isLoading = false
            loadTask = nil
        }
    }

    private func toggleSelection(_ paper: THSCPaperListing) {
        if selection.contains(paper.id) {
            selection.remove(paper.id)
        } else if selection.count < 10 {
            selection.insert(paper.id)
        }
    }

    private func isImported(_ listing: THSCPaperListing) -> Bool {
        importIdentifiersForSelectedSource.contains(listing.id) ||
            importIdentifiersForSelectedSource.contains(listing.legacyIdentifier)
    }

    private func hasLocalPaperConflict(_ listing: THSCPaperListing) -> Bool {
        guard let subjectID else { return false }
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

    private func importSelectedPapers() {
        guard
            let subjectID,
            let subject = activeSubjects.first(where: { $0.id == subjectID }),
            let rootURL = appState.rootFolderURL
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
