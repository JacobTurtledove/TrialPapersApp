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

    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, selection: $navigationCoordinator.selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("Trial Revision")
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if thscImportCoordinator.isImporting {
                THSCImportProgressBar(coordinator: thscImportCoordinator)
            }
        }
        .background(WindowTitleSetter(title: AppBuild.windowTitle))
    }
}

private struct THSCImportProgressBar: View {
    @ObservedObject var coordinator: THSCImportCoordinator

    var body: some View {
        HStack(spacing: 12) {
            ProgressView(
                value: Double(coordinator.completedCount),
                total: Double(max(coordinator.totalCount, 1))
            )
            .frame(width: 180)

            Text("Importing \(coordinator.completedCount) of \(coordinator.totalCount) THSC papers")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
