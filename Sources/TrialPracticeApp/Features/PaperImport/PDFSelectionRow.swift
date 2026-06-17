import SwiftUI

struct PDFSelectionRow: View {
    let title: String
    let url: URL?
    let choose: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(url?.lastPathComponent ?? "No file selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(url == nil ? "Choose…" : "Replace…", action: choose)
        }
    }
}
