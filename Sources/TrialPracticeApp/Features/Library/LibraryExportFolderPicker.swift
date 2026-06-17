import AppKit
import UniformTypeIdentifiers

@MainActor
func chooseLibraryExportFolder() -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.folder]
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Export"
    return panel.runModal() == .OK ? panel.url : nil
}
