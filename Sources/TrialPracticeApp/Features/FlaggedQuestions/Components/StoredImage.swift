import AppKit
import SwiftUI

struct StoredImage: View {
    let relativePath: String
    let rootURL: URL?

    @State private var image: NSImage?
    @State private var didAttemptLoad = false

    var body: some View {
        Group {
            if let image {
                loadedImage(image)
            } else if didAttemptLoad {
                ContentUnavailableView("Image Missing", systemImage: "photo.badge.exclamationmark")
            } else {
                loadingPlaceholder
            }
        }
        .task(id: loadIdentifier) {
            await loadImage()
        }
    }

    private var loadIdentifier: String {
        "\(rootURL?.path ?? "missing-root")/\(relativePath)"
    }

    private func loadedImage(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
    }

    private var loadingPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(0.10))

            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary.opacity(0.75))
                ProgressView()
                    .controlSize(.small)
            }
            .padding(12)
        }
        .aspectRatio(1.35, contentMode: .fit)
    }

    @MainActor
    private func loadImage() async {
        image = nil
        didAttemptLoad = false

        guard
            let rootURL,
            let url = try? StoredFilePath(relativePath).url(relativeTo: rootURL)
        else {
            didAttemptLoad = true
            return
        }

        let result = await Task.detached(priority: .userInitiated) {
            LoadedStoredImage(image: NSImage(contentsOf: url))
        }.value

        guard !Task.isCancelled else { return }
        image = result.image
        didAttemptLoad = true
    }
}

private struct LoadedStoredImage: @unchecked Sendable {
    let image: NSImage?
}
