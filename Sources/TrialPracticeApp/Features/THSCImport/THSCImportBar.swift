import SwiftUI

extension THSCImportView {
    var importBar: some View {
        HStack {
            Toggle("Show already imported papers", isOn: $showAlreadyImported)
                .toggleStyle(.checkbox)
                .disabled(listings.isEmpty)

            Divider()
                .frame(height: 24)

            if let message = importCoordinator.statusMessage ?? statusMessage {
                Text(message)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Import \(selection.count) Paper\(selection.count == 1 ? "" : "s")") {
                importSelectedPapers()
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                selection.isEmpty ||
                selectedSubjectID == nil ||
                importCoordinator.isImporting ||
                isLoading
            )
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
