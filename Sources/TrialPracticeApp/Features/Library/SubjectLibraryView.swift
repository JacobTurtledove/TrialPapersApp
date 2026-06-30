import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum SubjectPaperDisplayMode: String, CaseIterable, Identifiable {
    case schoolFolders
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schoolFolders: "Folders"
        case .list: "List"
        }
    }

    var systemImage: String {
        switch self {
        case .schoolFolders: "folder"
        case .list: "list.bullet"
        }
    }
}

struct SubjectLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationCoordinator: AppNavigationCoordinator
    @EnvironmentObject private var paperImportProgressStore: PaperImportProgressStore
    @Query(sort: \School.displayName) private var schools: [School]
    @Query(sort: \Paper.year, order: .reverse) private var papers: [Paper]
    @Query private var flaggedQuestions: [FlaggedQuestion]

    let subject: Subject
    @State private var isAddingPaper = false
    @State private var exportMessage: String?
    @State private var exportedCSVURL: URL?
    @State private var crestErrorMessage: String?
    @State private var paperErrorMessage: String?
    @State private var curatedCrests: [UUID: NSImage] = [:]
    @State private var curatedCrestSources: [UUID: URL] = [:]
    @AppStorage("library.subjectPaperDisplayMode") private var paperDisplayModeRawValue =
        SubjectPaperDisplayMode.schoolFolders.rawValue

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 20)
    ]

    private var subjectPapers: [Paper] {
        papers.filter { $0.subjectID == subject.id && $0.deletedAt == nil }
    }

    private var optimisticImports: [OptimisticPaperImport] {
        paperImportProgressStore.imports(forSubjectID: subject.id)
    }

    private var hasVisiblePapers: Bool {
        !subjectPapers.isEmpty || !optimisticImports.isEmpty
    }

    private var activeFlaggedQuestions: [FlaggedQuestion] {
        let paperIDs = Set(subjectPapers.map(\.id))
        return flaggedQuestions.filter {
            $0.deletedAt == nil && $0.subjectID == subject.id && paperIDs.contains($0.paperID)
        }
    }

    private var schoolFolders: [(school: School, papers: [Paper])] {
        schools.compactMap { school in
            let matching = subjectPapers.filter { $0.schoolID == school.id }
            return matching.isEmpty ? nil : (school, matching)
        }
    }

    private var optimisticImportGroups: [(schoolID: UUID, schoolName: String, imports: [OptimisticPaperImport])] {
        Dictionary(grouping: optimisticImports, by: \.schoolID)
            .map { schoolID, imports in
                (
                    schoolID: schoolID,
                    schoolName: imports.first?.schoolName ?? "New School",
                    imports: imports.sorted { $0.startedAt < $1.startedAt }
                )
            }
            .sorted { $0.schoolName.localizedCaseInsensitiveCompare($1.schoolName) == .orderedAscending }
    }

    private var optimisticImportGroupsForNewSchools: [(schoolID: UUID, schoolName: String, imports: [OptimisticPaperImport])] {
        let existingSchoolIDs = Set(schoolFolders.map(\.school.id))
        return optimisticImportGroups.filter { !existingSchoolIDs.contains($0.schoolID) }
    }

    private var displayMode: SubjectPaperDisplayMode {
        SubjectPaperDisplayMode(rawValue: paperDisplayModeRawValue) ?? .schoolFolders
    }

    private var displayModeBinding: Binding<SubjectPaperDisplayMode> {
        Binding(
            get: { displayMode },
            set: { paperDisplayModeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Group {
            if !hasVisiblePapers {
                ContentUnavailableView {
                    Label("No Schools Yet", systemImage: "folder")
                } description: {
                    Text("Add a paper to create its school folder.")
                } actions: {
                    HStack {
                        Button("Add Paper") {
                            isAddingPaper = true
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            navigationCoordinator.showTHSCImport()
                        } label: {
                            Label("Import from THSC instead", systemImage: "arrow.down.doc.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else if displayMode == .list {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(subjectPapers) { paper in
                            PaperListRow(
                                paper: paper,
                                subject: subject,
                                school: school(for: paper),
                                flaggedCount: flaggedCount(for: paper),
                                errorMessage: $paperErrorMessage,
                                completionBinding: completionBinding(for: paper)
                            )
                            .contextMenu {
                                Button("Show in Finder") {
                                    reveal(paper)
                                }
                                Button("Export PDF") {
                                    exportPaper(paper)
                                }
                            }
                        }
                        ForEach(optimisticImports) { importRecord in
                            ImportingPaperListRow(importRecord: importRecord)
                        }
                    }
                    .padding(28)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(schoolFolders, id: \.school.id) { folder in
                            NavigationLink {
                                SchoolLibraryView(
                                    subject: subject,
                                    school: folder.school
                                )
                            } label: {
                                SchoolFolderCard(
                                    school: folder.school,
                                    paperCount: folder.papers.count +
                                        optimisticImportCount(for: folder.school),
                                    fallbackColor: subject.folderColor,
                                    curatedCrest: curatedCrests[folder.school.id]
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Show Papers in Finder") {
                                    revealSchoolFolder(folder.school)
                                }
                                Button("Export School Folder") {
                                    exportSchoolFolder(folder.school)
                                }
                                Button("Use Curated Crest") {
                                    useCuratedCrest(for: folder.school)
                                }
                                .disabled(curatedCrests[folder.school.id] == nil)

                                Button(
                                    folder.school.crestImageData == nil
                                        ? "Choose School Crest"
                                        : "Replace School Crest"
                                ) {
                                    chooseCrest(for: folder.school)
                                }
                                if folder.school.crestImageData != nil {
                                    Button("Remove Custom Crest", role: .destructive) {
                                        removeCrest(from: folder.school)
                                    }
                                }
                                if let sourceURL = curatedCrestSources[folder.school.id] {
                                    Link("View Crest Source", destination: sourceURL)
                                }
                                Button("Move School to Bin", role: .destructive) {
                                    moveSchoolToBin(folder.school)
                                }
                            }
                        }
                        ForEach(optimisticImportGroupsForNewSchools, id: \.schoolID) { group in
                            ImportingSchoolFolderCard(
                                schoolName: group.schoolName,
                                paperCount: group.imports.count,
                                fallbackColor: subject.folderColor
                            )
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle(subject.displayName)
        .toolbar {
            HStack {
                Picker("Paper display", selection: displayModeBinding) {
                    ForEach(SubjectPaperDisplayMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)

                Button {
                    exportSubject()
                } label: {
                    Label("Export Subject", systemImage: "square.and.arrow.up")
                }
                .disabled(subjectPapers.isEmpty && activeFlaggedQuestions.isEmpty)

                Button {
                    exportCSV()
                } label: {
                    Label("Export CSV", systemImage: "tablecells")
                }
                .disabled(subjectPapers.isEmpty)

                Button {
                    isAddingPaper = true
                } label: {
                    Label("Add Paper", systemImage: "doc.badge.plus")
                }

                Button {
                    navigationCoordinator.showTHSCImport()
                } label: {
                    Label("Import from THSC instead", systemImage: "arrow.down.doc.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $isAddingPaper) {
            AddPaperView(initialSubjectID: subject.id)
        }
        .task {
            loadCuratedCrests()
        }
        .alert(
            "CSV Export",
            isPresented: Binding(
                get: { exportMessage != nil },
                set: { if !$0 { exportMessage = nil } }
            )
        ) {
            if let exportedCSVURL {
                Button("Show in Finder") {
                    FinderRevealService.reveal(exportedCSVURL)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
        .alert(
            "School Crest Error",
            isPresented: Binding(
                get: { crestErrorMessage != nil },
                set: { if !$0 { crestErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(crestErrorMessage ?? "")
        }
        .alert(
            "Paper Error",
            isPresented: Binding(
                get: { paperErrorMessage != nil },
                set: { if !$0 { paperErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(paperErrorMessage ?? "")
        }
    }

    private func school(for paper: Paper) -> School? {
        schools.first { $0.id == paper.schoolID }
    }

    private func flaggedCount(for paper: Paper) -> Int {
        flaggedQuestions.filter {
            $0.paperID == paper.id && $0.deletedAt == nil
        }.count
    }

    private func optimisticImportCount(for school: School) -> Int {
        paperImportProgressStore.imports(
            forSubjectID: subject.id,
            schoolID: school.id
        ).count
    }

    private func revealSchoolFolder(_ school: School) {
        revealStoredItem(
            "Papers/\(subject.filenameValue)/\(school.filenameValue)"
        )
    }

    private func revealStoredItem(_ relativePath: String) {
        guard let rootURL = appState.rootFolderURL else {
            crestErrorMessage = "The app storage folder is unavailable."
            return
        }
        do {
            try FinderRevealService.revealStoredItem(
                relativePath: relativePath,
                rootURL: rootURL
            )
        } catch {
            crestErrorMessage = error.localizedDescription
        }
    }

    private func reveal(_ paper: Paper) {
        guard let rootURL = appState.rootFolderURL else {
            paperErrorMessage = "The app storage folder is unavailable."
            return
        }
        do {
            try FinderRevealService.revealStoredItem(
                relativePath: paper.primaryPDFRelativePath,
                rootURL: rootURL
            )
        } catch {
            paperErrorMessage = error.localizedDescription
        }
    }

    private func completionBinding(for paper: Paper) -> Binding<Bool> {
        Binding(
            get: { paper.isCompleted },
            set: { isCompleted in
                let oldValue = paper.isCompleted
                paper.isCompleted = isCompleted
                do {
                    try modelContext.save()
                } catch {
                    paper.isCompleted = oldValue
                    modelContext.rollback()
                    paperErrorMessage = error.localizedDescription
                }
            }
        )
    }

    private func chooseCrest(for school: School) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an image of \(school.displayName)'s crest or emblem."
        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let oldData = school.crestImageData
        let oldSourcePageURL = school.crestSourcePageURL
        let oldLookupAttemptedAt = school.crestLookupAttemptedAt
        do {
            school.crestImageData = try SchoolCrestService().pngData(from: sourceURL)
            school.crestSourcePageURL = nil
            school.crestLookupAttemptedAt = .now
            try modelContext.save()
        } catch {
            school.crestImageData = oldData
            school.crestSourcePageURL = oldSourcePageURL
            school.crestLookupAttemptedAt = oldLookupAttemptedAt
            modelContext.rollback()
            crestErrorMessage = error.localizedDescription
        }
    }

    private func removeCrest(from school: School) {
        let oldData = school.crestImageData
        let oldSourcePageURL = school.crestSourcePageURL
        school.crestImageData = nil
        school.crestSourcePageURL = curatedCrestSources[school.id]?.absoluteString
        do {
            try modelContext.save()
        } catch {
            school.crestImageData = oldData
            school.crestSourcePageURL = oldSourcePageURL
            modelContext.rollback()
            crestErrorMessage = error.localizedDescription
        }
    }

    private func useCuratedCrest(for school: School) {
        let oldData = school.crestImageData
        let oldSourcePageURL = school.crestSourcePageURL
        school.crestImageData = nil
        school.crestSourcePageURL = curatedCrestSources[school.id]?.absoluteString
        do {
            try modelContext.save()
        } catch {
            school.crestImageData = oldData
            school.crestSourcePageURL = oldSourcePageURL
            modelContext.rollback()
            crestErrorMessage = error.localizedDescription
        }
    }

    private func loadCuratedCrests() {
        let lookup = SchoolCrestLookupService()
        for folder in schoolFolders {
            do {
                guard let result = try lookup.findCrest(for: folder.school.displayName),
                      let image = NSImage(contentsOf: result.imageURL) else {
                    continue
                }
                curatedCrests[folder.school.id] = image
                if let sourceURL = result.sourcePageURL {
                    curatedCrestSources[folder.school.id] = sourceURL
                }
            } catch {
                crestErrorMessage = error.localizedDescription
                return
            }
        }
    }

    private func exportCSV() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(subject.filenameValue)_Papers.csv"

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        exportedCSVURL = nil
        do {
            let rows = subjectPapers.map { paper in
                SubjectPaperCSVRow(
                    schoolName: schools.first { $0.id == paper.schoolID }?.displayName
                        ?? "Unknown School",
                    year: paper.year
                )
            }
            try SubjectPaperCSVService().export(rows: rows, to: destinationURL)
            exportedCSVURL = destinationURL
            exportMessage = "Paper CSV exported successfully."
        } catch {
            exportMessage = error.localizedDescription
        }
    }

    private func exportSubject() {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        guard let destinationURL = chooseLibraryExportFolder() else { return }
        do {
            exportedCSVURL = try LibraryExportService(rootURL: rootURL).exportSubject(
                subject,
                papers: subjectPapers,
                flaggedQuestions: activeFlaggedQuestions,
                to: destinationURL
            )
            exportMessage = "Subject exported successfully."
        } catch {
            exportedCSVURL = nil
            exportMessage = error.localizedDescription
        }
    }

    private func exportSchoolFolder(_ school: School) {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        guard let destinationURL = chooseLibraryExportFolder() else { return }
        do {
            exportedCSVURL = try LibraryExportService(rootURL: rootURL).exportSchoolFolder(
                subject: subject,
                school: school,
                papers: subjectPapers,
                flaggedQuestions: activeFlaggedQuestions,
                to: destinationURL
            )
            exportMessage = "School folder exported successfully."
        } catch {
            exportedCSVURL = nil
            exportMessage = error.localizedDescription
        }
    }

    private func exportPaper(_ paper: Paper) {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        let storedPath = paper.primaryPDFRelativePath
        savePanel.nameFieldStringValue = (storedPath as NSString).lastPathComponent

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        do {
            exportedCSVURL = try LibraryExportService(rootURL: rootURL).exportPaper(
                paper,
                to: destinationURL
            )
            exportMessage = "PDF exported successfully."
        } catch {
            exportedCSVURL = nil
            exportMessage = error.localizedDescription
        }
    }

    private func moveSchoolToBin(_ school: School) {
        let affectedPapers = subjectPapers.filter {
            $0.subjectID == subject.id && $0.schoolID == school.id
        }
        let affectedPaperIDs = Set(affectedPapers.map(\.id))
        let affectedQuestions = activeFlaggedQuestions.filter {
            affectedPaperIDs.contains($0.paperID)
        }
        let deletedAt = Date.now
        let paperSnapshots = affectedPapers.map { ($0, $0.deletedAt) }
        let questionSnapshots = affectedQuestions.map { ($0, $0.deletedAt) }

        affectedPapers.forEach { $0.deletedAt = deletedAt }
        affectedQuestions.forEach { $0.deletedAt = deletedAt }

        do {
            try modelContext.save()
        } catch {
            paperSnapshots.forEach { $0.0.deletedAt = $0.1 }
            questionSnapshots.forEach { $0.0.deletedAt = $0.1 }
            modelContext.rollback()
            exportMessage = error.localizedDescription
        }
    }
}
