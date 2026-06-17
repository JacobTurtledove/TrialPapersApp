import SwiftUI

struct PaperLibraryCard: View {
    let paper: Paper
    let flaggedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                Spacer()
                Text(paper.year)
                    .font(.title2.bold())
            }

            Text("\(paper.year) Trial Paper")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack {
                if let mark = paper.mark {
                    Label(
                        "\(mark.formatted(.number.precision(.fractionLength(0...2))))%",
                        systemImage: "percent"
                    )
                } else {
                    Label("No mark", systemImage: "minus.circle")
                }
                Spacer()
                Label("\(flaggedCount)", systemImage: "flag")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Spacer()
                .frame(height: 24)
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
