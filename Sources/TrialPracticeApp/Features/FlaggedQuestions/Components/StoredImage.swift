import AppKit
import SwiftUI

struct StoredImage: View {
    let relativePath: String
    let rootURL: URL?

    var body: some View {
        if
            let rootURL,
            let url = try? StoredFilePath(relativePath).url(relativeTo: rootURL),
            let image = NSImage(contentsOf: url)
        {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ContentUnavailableView("Image Missing", systemImage: "photo.badge.exclamationmark")
        }
    }
}
