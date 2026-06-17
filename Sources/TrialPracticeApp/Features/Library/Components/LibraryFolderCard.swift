import SwiftUI

struct LibraryFolderCard: View {
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
