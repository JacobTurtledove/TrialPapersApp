import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case library = "Library"
    case thscImport = "Import from THSC"
    case nesaPastPapers = "NESA Past Papers"
    case flaggedQuestions = "Flagged Questions"
    case booklets = "Revision Booklets"
    case bin = "Bin"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .library: "folder"
        case .thscImport: "arrow.down.doc"
        case .nesaPastPapers: "doc.text.magnifyingglass"
        case .flaggedQuestions: "flag"
        case .booklets: "book.pages"
        case .bin: "trash"
        case .settings: "gearshape"
        }
    }
}

@MainActor
final class AppNavigationCoordinator: ObservableObject {
    @Published var selection: NavigationItem? = .library

    func showTHSCImport() {
        selection = .thscImport
    }
}

struct MainNavigationView: View {
    @State private var detailPath = NavigationPath()
    @StateObject private var navigationCoordinator = AppNavigationCoordinator()
    @StateObject private var thscImportCoordinator = THSCImportCoordinator()
    @StateObject private var pdfViewportStore = PDFViewerViewportStore()
    @StateObject private var annotationSaveCoordinator = PDFAnnotationSaveCoordinator()

    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, selection: $navigationCoordinator.selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("Trial Revision")
            .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 200)
        } detail: {
            NavigationStack(path: $detailPath) {
                switch navigationCoordinator.selection ?? .library {
                case .library:
                    LibraryView()
                case .thscImport:
                    THSCImportView()
                case .nesaPastPapers:
                    NESAPastPapersView()
                case .bin:
                    SubjectBinView()
                case .flaggedQuestions:
                    FlaggedQuestionsView()
                case .booklets:
                    RevisionBookletsView()
                case .settings:
                    SettingsView()
                }
            }
        }
        .onChange(of: navigationCoordinator.selection) {
            detailPath = NavigationPath()
        }
        .environmentObject(navigationCoordinator)
        .environmentObject(thscImportCoordinator)
        .environmentObject(pdfViewportStore)
        .environmentObject(annotationSaveCoordinator)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if thscImportCoordinator.isImporting {
                THSCImportProgressBar(coordinator: thscImportCoordinator)
            }
        }
        .alert(
            "Could Not Save PDF Annotations",
            isPresented: Binding(
                get: { annotationSaveCoordinator.saveFailure != nil },
                set: { if !$0 { annotationSaveCoordinator.clearFailure() } }
            )
        ) {
            Button("Retry") {
                annotationSaveCoordinator.retryFailedSave()
            }
            Button("OK", role: .cancel) {
                annotationSaveCoordinator.clearFailure()
            }
        } message: {
            Text(annotationSaveCoordinator.saveFailure?.message ?? "")
        }
        .background(WindowTitleSetter(title: AppBuild.windowTitle))
    }
}
