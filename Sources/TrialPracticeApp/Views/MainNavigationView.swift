import AppKit
import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case library = "Library"
    case thscImport = "Import from THSC"
    case nesaPastPapers = "NESA Past Papers"
    case studyQueue = "Study Queue"
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
        case .studyQueue: "target"
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
    @Published var splitViewVisibility: NavigationSplitViewVisibility = .automatic

    func showTHSCImport() {
        selection = .thscImport
    }

    func focusDetailColumn() {
        if SidebarVisibilityController.collapseSidebarIfVisible() {
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            splitViewVisibility = .detailOnly
        }
    }

    func restoreAutomaticSplitViewVisibility() {
        if SidebarVisibilityController.expandSidebarIfCollapsed() {
            splitViewVisibility = .automatic
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            splitViewVisibility = .automatic
        }
    }
}

@MainActor
private enum SidebarVisibilityController {
    static func collapseSidebarIfVisible() -> Bool {
        guard let splitViewController else {
            return false
        }
        guard let sidebarItem = splitViewController.splitViewItems.first else {
            return false
        }
        guard !sidebarItem.isCollapsed else {
            return true
        }
        splitViewController.toggleSidebar(nil)
        return true
    }

    static func expandSidebarIfCollapsed() -> Bool {
        guard let splitViewController else {
            return false
        }
        guard let sidebarItem = splitViewController.splitViewItems.first else {
            return false
        }
        guard sidebarItem.isCollapsed else {
            return false
        }
        splitViewController.toggleSidebar(nil)
        return true
    }

    private static var splitViewController: NSSplitViewController? {
        if let actionTarget = NSApp.target(
            forAction: #selector(NSSplitViewController.toggleSidebar(_:)),
            to: nil,
            from: nil
        ) as? NSSplitViewController {
            return actionTarget
        }

        let activeWindows = [NSApp.keyWindow, NSApp.mainWindow].compactMap { $0 }
        for window in activeWindows + NSApp.windows {
            if let splitViewController = findSplitViewController(
                in: window.contentViewController
            ) {
                return splitViewController
            }
        }
        return nil
    }

    private static func findSplitViewController(
        in viewController: NSViewController?
    ) -> NSSplitViewController? {
        guard let viewController else {
            return nil
        }
        if let splitViewController = viewController as? NSSplitViewController {
            return splitViewController
        }
        for child in viewController.children {
            if let splitViewController = findSplitViewController(in: child) {
                return splitViewController
            }
        }
        return nil
    }
}

struct MainNavigationView: View {
    @State private var detailPath = NavigationPath()
    @StateObject private var navigationCoordinator = AppNavigationCoordinator()
    @StateObject private var thscImportCoordinator = THSCImportCoordinator()
    @StateObject private var pdfViewportStore = PDFViewerViewportStore()
    @StateObject private var annotationSaveCoordinator = PDFAnnotationSaveCoordinator()

    var body: some View {
        NavigationSplitView(columnVisibility: $navigationCoordinator.splitViewVisibility) {
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
                case .studyQueue:
                    StudyQueueView()
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
            navigationCoordinator.restoreAutomaticSplitViewVisibility()
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
