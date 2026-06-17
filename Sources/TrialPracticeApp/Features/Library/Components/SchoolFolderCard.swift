import AppKit
import SwiftUI

struct SchoolFolderCard: View {
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
