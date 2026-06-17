import SwiftUI

extension THSCImportView {
    var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("Save to subject", selection: $selectedSubjectIDString) {
                    Text("Select subject").tag("")
                    ForEach(activeSubjects) { subject in
                        Text(subject.displayName).tag(subject.id.uuidString)
                    }
                }
                .frame(maxWidth: 320)

                Picker("THSC collection", selection: $selectedSourceIDString) {
                    Text("Select collection").tag("")
                    ForEach(THSCSource.presets) { source in
                        Text(source.name).tag(source.id)
                    }
                }
                .frame(maxWidth: 340)

                Button(listings.isEmpty ? "Load Papers" : "Reload Papers") {
                    startLoadingPapers()
                }
                .disabled(selectedSource == nil || isLoading || importCoordinator.isImporting)

                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Contacting THSC…")
                            .font(.callout.weight(.medium))
                    }
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.tint.opacity(0.1), in: Capsule())
                }
            }

            if !listings.isEmpty {
                HStack {
                    TextField("Search school or year", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)

                    Picker("Solutions", selection: $solutionsFilter) {
                        ForEach(THSCSolutionsFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 340)

                    Text("\(selection.count) of 10 selected")
                        .foregroundStyle(selection.count == 10 ? .orange : .secondary)
                    Spacer()
                    Text(showAlreadyImported ? "Previously imported papers cannot be selected again." : "Previously imported papers are hidden.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }
}
