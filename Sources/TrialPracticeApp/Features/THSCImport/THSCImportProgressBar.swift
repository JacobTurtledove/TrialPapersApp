import SwiftUI

struct THSCImportProgressBar: View {
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
