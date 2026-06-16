import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Subject.displayName) private var allSubjects: [Subject]
    @Query private var papers: [Paper]
    @Query private var flaggedQuestions: [FlaggedQuestion]

    @State private var isAddingSubject = false
    @State private var subjectToRename: Subject?
    @State private var errorMessage: String?
    @State private var exportMessage: String?
    @State private var exportedURL: URL?

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 20)
    ]

    private var activeSubjects: [Subject] {
        allSubjects.filter { $0.deletedAt == nil }
    }

    private var activePapers: [Paper] {
        let subjectIDs = Set(activeSubjects.map(\.id))
        return papers.filter { $0.deletedAt == nil && subjectIDs.contains($0.subjectID) }
    }

    private var activeFlaggedQuestions: [FlaggedQuestion] {
        let paperIDs = Set(activePapers.map(\.id))
        return flaggedQuestions.filter {
            $0.deletedAt == nil && paperIDs.contains($0.paperID)
        }
    }

    var body: some View {
        Group {
            if activeSubjects.isEmpty {
                ContentUnavailableView {
                    Label("Library is Empty", systemImage: "folder")
                } description: {
                    Text("Create a subject folder to begin organising trial papers.")
                } actions: {
                    Button("New Subject") {
                        isAddingSubject = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(activeSubjects) { subject in
                            NavigationLink {
                                SubjectLibraryView(subject: subject)
                            } label: {
                                LibraryFolderCard(
                                    title: subject.displayName,
                                    subtitle: paperCountDescription(for: subject),
                                    icon: "folder.fill",
                                    color: subject.folderColor
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Show Papers in Finder") {
                                    revealFolder("Papers/\(subject.filenameValue)")
                                }
                                Button("Export Subject") {
                                    exportSubject(subject)
                                }
                                Button("Rename Subject") {
                                    subjectToRename = subject
                                }
                                Button("Move to Bin", role: .destructive) {
                                    moveToBin(subject)
                                }
                            }
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            HStack {
                Button {
                    exportLibrary()
                } label: {
                    Label("Export Library", systemImage: "square.and.arrow.up")
                }
                .disabled(activePapers.isEmpty && activeFlaggedQuestions.isEmpty)

                Button {
                    isAddingSubject = true
                } label: {
                    Label("New Subject", systemImage: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $isAddingSubject) {
            SubjectEditor(title: "New Subject") {
                createSubject($0, colorHex: $1)
            }
        }
        .sheet(item: $subjectToRename) { subject in
            SubjectEditor(
                title: "Edit Subject",
                initialName: subject.displayName,
                initialColorHex: subject.colorHex
            ) {
                rename(subject, to: $0, colorHex: $1)
            }
        }
        .alert(
            "Library Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            "Library Export",
            isPresented: Binding(
                get: { exportMessage != nil },
                set: { if !$0 { exportMessage = nil } }
            )
        ) {
            if let exportedURL {
                Button("Show in Finder") {
                    FinderRevealService.reveal(exportedURL)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private func revealFolder(_ relativePath: String) {
        guard let rootURL = appState.rootFolderURL else {
            errorMessage = "The app storage folder is unavailable."
            return
        }
        do {
            try FinderRevealService.revealStoredItem(
                relativePath: relativePath,
                rootURL: rootURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func paperCountDescription(for subject: Subject) -> String {
        let count = activePapers.filter { $0.subjectID == subject.id }.count
        return "\(count) paper\(count == 1 ? "" : "s")"
    }

    private func createSubject(_ input: String, colorHex: String) -> String? {
        let displayName = NameNormalizer.displayName(from: input)
        let filenameValue = NameNormalizer.filenameValue(from: displayName)
        guard !displayName.isEmpty else { return "Enter a subject name." }
        guard !filenameValue.isEmpty else {
            return "A subject name must contain at least one letter."
        }
        guard !allSubjects.contains(where: {
            $0.displayName.localizedCaseInsensitiveCompare(displayName) == .orderedSame ||
            $0.filenameValue.localizedCaseInsensitiveCompare(filenameValue) == .orderedSame
        }) else {
            return "A subject with this name already exists."
        }
        guard let rootURL = appState.rootFolderURL else {
            return "The app storage folder is unavailable."
        }

        let subject = Subject(
            displayName: displayName,
            filenameValue: filenameValue,
            colorHex: colorHex
        )
        do {
            try LocalFileStore(rootURL: rootURL).prepareSubjectFolders(subject)
            modelContext.insert(subject)
            try modelContext.save()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func rename(_ subject: Subject, to input: String, colorHex: String) -> String? {
        let displayName = NameNormalizer.displayName(from: input)
        let filenameValue = NameNormalizer.filenameValue(from: displayName)
        guard !displayName.isEmpty else { return "Enter a subject name." }
        guard !filenameValue.isEmpty else {
            return "A subject name must contain at least one letter."
        }
        guard !allSubjects.contains(where: {
            $0.id != subject.id &&
            (
                $0.displayName.localizedCaseInsensitiveCompare(displayName) == .orderedSame ||
                $0.filenameValue.localizedCaseInsensitiveCompare(filenameValue) == .orderedSame
            )
        }) else {
            return "A subject with this name already exists."
        }
        guard let rootURL = appState.rootFolderURL else {
            return "The app storage folder is unavailable."
        }

        let oldDisplayName = subject.displayName
        let oldFilename = subject.filenameValue
        let oldColorHex = subject.colorHex
        let affectedPapers = papers.filter { $0.subjectID == subject.id }
        let affectedQuestions = flaggedQuestions.filter { $0.subjectID == subject.id }
        let paperSnapshots = affectedPapers.map {
            (
                $0,
                $0.questionPDFRelativePath,
                $0.solutionsPDFRelativePath,
                $0.combinedPDFRelativePath
            )
        }
        let questionSnapshots = affectedQuestions.map {
            ($0, $0.questionImageRelativePath, $0.solutionImageRelativePath)
        }

        do {
            try LocalFileStore(rootURL: rootURL).renameSubjectFolders(
                from: oldFilename,
                to: filenameValue
            )
            subject.displayName = displayName
            subject.filenameValue = filenameValue
            subject.colorHex = colorHex

            for paper in affectedPapers {
                paper.questionPDFRelativePath = replaceSubjectFolder(
                    in: paper.questionPDFRelativePath,
                    topLevel: "Papers",
                    from: oldFilename,
                    to: filenameValue
                )
                paper.solutionsPDFRelativePath = replaceSubjectFolder(
                    in: paper.solutionsPDFRelativePath,
                    topLevel: "Papers",
                    from: oldFilename,
                    to: filenameValue
                )
                if let path = paper.combinedPDFRelativePath {
                    paper.combinedPDFRelativePath = replaceSubjectFolder(
                        in: path,
                        topLevel: "Papers",
                        from: oldFilename,
                        to: filenameValue
                    )
                }
            }
            for question in affectedQuestions {
                question.questionImageRelativePath = replaceSubjectFolder(
                    in: question.questionImageRelativePath,
                    topLevel: "Flagged Questions",
                    from: oldFilename,
                    to: filenameValue
                )
                if let path = question.solutionImageRelativePath {
                    question.solutionImageRelativePath = replaceSubjectFolder(
                        in: path,
                        topLevel: "Flagged Questions",
                        from: oldFilename,
                        to: filenameValue
                    )
                }
            }
            try modelContext.save()
            return nil
        } catch {
            subject.displayName = oldDisplayName
            subject.filenameValue = oldFilename
            subject.colorHex = oldColorHex
            for snapshot in paperSnapshots {
                snapshot.0.questionPDFRelativePath = snapshot.1
                snapshot.0.solutionsPDFRelativePath = snapshot.2
                snapshot.0.combinedPDFRelativePath = snapshot.3
            }
            for snapshot in questionSnapshots {
                snapshot.0.questionImageRelativePath = snapshot.1
                snapshot.0.solutionImageRelativePath = snapshot.2
            }
            try? LocalFileStore(rootURL: rootURL).renameSubjectFolders(
                from: filenameValue,
                to: oldFilename
            )
            return error.localizedDescription
        }
    }

    private func moveToBin(_ subject: Subject) {
        subject.deletedAt = .now
        do {
            try modelContext.save()
        } catch {
            subject.deletedAt = nil
            errorMessage = error.localizedDescription
        }
    }

    private func exportLibrary() {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        guard let destinationURL = chooseExportFolder() else { return }
        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportLibrary(
                subjects: activeSubjects,
                papers: activePapers,
                flaggedQuestions: activeFlaggedQuestions,
                to: destinationURL
            )
            exportMessage = "Library exported successfully."
        } catch {
            exportedURL = nil
            exportMessage = error.localizedDescription
        }
    }

    private func exportSubject(_ subject: Subject) {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        guard let destinationURL = chooseExportFolder() else { return }
        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportSubject(
                subject,
                papers: activePapers,
                flaggedQuestions: activeFlaggedQuestions,
                to: destinationURL
            )
            exportMessage = "Subject exported successfully."
        } catch {
            exportedURL = nil
            exportMessage = error.localizedDescription
        }
    }

    private func replaceSubjectFolder(
        in relativePath: String,
        topLevel: String,
        from oldFilename: String,
        to newFilename: String
    ) -> String {
        let prefix = "\(topLevel)/\(oldFilename)/"
        guard relativePath.hasPrefix(prefix) else { return relativePath }
        return "\(topLevel)/\(newFilename)/" + relativePath.dropFirst(prefix.count)
    }
}

private struct SubjectLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationCoordinator: AppNavigationCoordinator
    @Query(sort: \School.displayName) private var schools: [School]
    @Query(sort: \Paper.year, order: .reverse) private var papers: [Paper]
    @Query private var flaggedQuestions: [FlaggedQuestion]

    let subject: Subject
    @State private var isAddingPaper = false
    @State private var exportMessage: String?
    @State private var exportedCSVURL: URL?
    @State private var crestErrorMessage: String?
    @State private var curatedCrests: [UUID: NSImage] = [:]
    @State private var curatedCrestSources: [UUID: URL] = [:]

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 20)
    ]

    private var subjectPapers: [Paper] {
        papers.filter { $0.subjectID == subject.id && $0.deletedAt == nil }
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

    var body: some View {
        Group {
            if schoolFolders.isEmpty {
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
                                    paperCount: folder.papers.count,
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
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle(subject.displayName)
        .toolbar {
            HStack {
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
        do {
            school.crestImageData = try SchoolCrestService().pngData(from: sourceURL)
            school.crestSourcePageURL = nil
            school.crestLookupAttemptedAt = .now
            try modelContext.save()
        } catch {
            school.crestImageData = oldData
            school.crestSourcePageURL = oldSourcePageURL
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
                    year: paper.year,
                    mark: paper.mark
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
        guard let destinationURL = chooseExportFolder() else { return }
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
        guard let destinationURL = chooseExportFolder() else { return }
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

private struct SchoolLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationCoordinator: AppNavigationCoordinator
    @Query(sort: \Paper.year, order: .reverse) private var allPapers: [Paper]
    @Query private var flaggedQuestions: [FlaggedQuestion]
    @Query private var importRecords: [THSCImportRecord]

    let subject: Subject
    let school: School

    @State private var isAddingPaper = false
    @State private var paperToDelete: Paper?
    @State private var deletionError: String?
    @State private var exportMessage: String?
    @State private var exportedURL: URL?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 290), spacing: 20)
    ]

    private var papers: [Paper] {
        allPapers.filter {
            $0.subjectID == subject.id && $0.schoolID == school.id && $0.deletedAt == nil
        }
    }

    private var activeFlaggedQuestions: [FlaggedQuestion] {
        let paperIDs = Set(papers.map(\.id))
        return flaggedQuestions.filter {
            $0.deletedAt == nil && paperIDs.contains($0.paperID)
        }
    }

    var body: some View {
        Group {
            if papers.isEmpty {
                ContentUnavailableView {
                    Label("No Papers", systemImage: "doc")
                } description: {
                    Text("Add a paper for \(school.displayName).")
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
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(papers) { paper in
                            ZStack(alignment: .bottomLeading) {
                                NavigationLink {
                                    PaperViewerScreen(
                                        paper: paper,
                                        subject: subject,
                                        school: school
                                    )
                                } label: {
                                    PaperLibraryCard(
                                        paper: paper,
                                        flaggedCount: flaggedQuestions.filter {
                                            $0.paperID == paper.id && $0.deletedAt == nil
                                        }.count
                                    )
                                }
                                .buttonStyle(.plain)

                                Toggle(
                                    "Completed",
                                    isOn: completionBinding(for: paper)
                                )
                                .toggleStyle(.checkbox)
                                .padding(.leading, 18)
                                .padding(.bottom, 16)
                            }
                            .contextMenu {
                                Button("Show in Finder") {
                                    reveal(paper)
                                }
                                Button("Export PDF") {
                                    exportPaper(paper)
                                }
                                Button("Delete Paper", role: .destructive) {
                                    paperToDelete = paper
                                }
                            }
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle(school.displayName)
        .toolbar {
            HStack {
                Button {
                    exportSchoolFolder()
                } label: {
                    Label("Export School Folder", systemImage: "square.and.arrow.up")
                }
                .disabled(papers.isEmpty && activeFlaggedQuestions.isEmpty)

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
            AddPaperView(
                initialSubjectID: subject.id,
                initialSchoolName: school.displayName
            )
        }
        .confirmationDialog(
            "Delete this paper?",
            isPresented: Binding(
                get: { paperToDelete != nil },
                set: { if !$0 { paperToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Paper", role: .destructive) {
                deletePaper()
            }
        } message: {
            Text("The paper and its flagged questions will move to the Bin. Stored files will remain in Application Support.")
        }
        .alert(
            "Paper Error",
            isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "")
        }
        .alert(
            "Export",
            isPresented: Binding(
                get: { exportMessage != nil },
                set: { if !$0 { exportMessage = nil } }
            )
        ) {
            if let exportedURL {
                Button("Show in Finder") {
                    FinderRevealService.reveal(exportedURL)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private func reveal(_ paper: Paper) {
        guard let rootURL = appState.rootFolderURL else {
            deletionError = "The app storage folder is unavailable."
            return
        }
        do {
            try FinderRevealService.revealStoredItem(
                relativePath: paper.combinedPDFRelativePath
                    ?? paper.questionPDFRelativePath,
                rootURL: rootURL
            )
        } catch {
            deletionError = error.localizedDescription
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
                    deletionError = error.localizedDescription
                }
            }
        )
    }

    private func deletePaper() {
        guard let paper = paperToDelete else {
            return
        }
        let relatedQuestions = flaggedQuestions.filter { $0.paperID == paper.id }
        let oldPaperDeletedAt = paper.deletedAt
        let questionSnapshots = relatedQuestions.map { ($0, $0.deletedAt) }
        let deletedAt = Date.now
        do {
            paper.deletedAt = deletedAt
            relatedQuestions.forEach { $0.deletedAt = deletedAt }
            try modelContext.save()
            paperToDelete = nil
        } catch {
            paper.deletedAt = oldPaperDeletedAt
            questionSnapshots.forEach { $0.0.deletedAt = $0.1 }
            modelContext.rollback()
            deletionError = error.localizedDescription
        }
    }

    private func exportSchoolFolder() {
        guard let rootURL = appState.rootFolderURL else {
            exportMessage = "The app storage folder is unavailable."
            return
        }
        guard let destinationURL = chooseExportFolder() else { return }
        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportSchoolFolder(
                subject: subject,
                school: school,
                papers: papers,
                flaggedQuestions: activeFlaggedQuestions,
                to: destinationURL
            )
            exportMessage = "School folder exported successfully."
        } catch {
            exportedURL = nil
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
        let storedPath = paper.combinedPDFRelativePath ?? paper.questionPDFRelativePath
        savePanel.nameFieldStringValue = (storedPath as NSString).lastPathComponent

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        do {
            exportedURL = try LibraryExportService(rootURL: rootURL).exportPaper(
                paper,
                to: destinationURL
            )
            exportMessage = "PDF exported successfully."
        } catch {
            exportedURL = nil
            exportMessage = error.localizedDescription
        }
    }
}

private struct LibraryFolderCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 58))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 165, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct SchoolFolderCard: View {
    let school: School
    let paperCount: Int
    let fallbackColor: Color
    let curatedCrest: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let curatedCrest {
                Image(nsImage: curatedCrest)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "folder.fill")
                    .font(.system(size: 58))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(fallbackColor)
                    .frame(height: 64)
            }

            Text(school.displayName)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text("\(paperCount) paper\(paperCount == 1 ? "" : "s")")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 165, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct PaperLibraryCard: View {
    let paper: Paper
    let flaggedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                Spacer()
                Text(paper.year)
                    .font(.title2.bold())
            }

            Text("\(paper.year) Trial Paper")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack {
                if let mark = paper.mark {
                    Label(
                        "\(mark.formatted(.number.precision(.fractionLength(0...2))))%",
                        systemImage: "percent"
                    )
                } else {
                    Label("No mark", systemImage: "minus.circle")
                }
                Spacer()
                Label("\(flaggedCount)", systemImage: "flag")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Spacer()
                .frame(height: 24)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 165, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct SubjectEditor: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: (String, String) -> String?
    @State private var name: String
    @State private var color: Color
    @State private var validationMessage: String?

    init(
        title: String,
        initialName: String = "",
        initialColorHex: String = "#4A90E2",
        onSave: @escaping (String, String) -> String?
    ) {
        self.title = title
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _color = State(initialValue: Color(subjectHex: initialColorHex))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title2.bold())
            TextField("e.g. Maths Advanced", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            ColorPicker("Folder Colour", selection: $color, supportsOpacity: false)

            if let validationMessage {
                Text(validationMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func save() {
        validationMessage = onSave(name, color.subjectHex)
        if validationMessage == nil {
            dismiss()
        }
    }
}

@MainActor
private func chooseExportFolder() -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.folder]
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Export"
    return panel.runModal() == .OK ? panel.url : nil
}
