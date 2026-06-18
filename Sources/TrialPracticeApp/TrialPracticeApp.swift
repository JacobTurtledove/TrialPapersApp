import AppKit
import SwiftData
import SwiftUI

enum AppBuild {
    static let windowTitle = "HSC Trial Revision"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppIconInstaller.applyDockIcon()
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct TrialPracticeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            Subject.self,
            School.self,
            Paper.self,
            FlaggedQuestion.self,
            FlaggedQuestionAttempt.self,
            THSCImportRecord.self
        ])

        do {
            let configuration = ModelConfiguration(
                schema: schema,
                url: try AppDirectories.swiftDataStoreURL,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Unable to create the local database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup(AppBuild.windowTitle) {
            RootView()
                .environmentObject(appState)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1120, height: 720)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 600, height: 520)
        }
        .modelContainer(modelContainer)
    }
}

private enum AppIconInstaller {
    @MainActor
    static func applyDockIcon() {
        if let assetIcon = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = assetIcon
            return
        }

        if
            let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let bundledIcon = NSImage(contentsOf: iconURL)
        {
            NSApplication.shared.applicationIconImage = bundledIcon
        }
    }
}

struct WindowTitleSetter: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.title = title
        }
    }
}
