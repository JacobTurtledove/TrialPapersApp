import SwiftUI

extension THSCImportView {
    @ViewBuilder
    var paperList: some View {
        if activeSubjects.isEmpty {
            ContentUnavailableView(
                "Create a Subject First",
                systemImage: "folder.badge.plus",
                description: Text("THSC papers need a subject folder in your library.")
            )
        } else if isLoading {
            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)

                Text("Loading Papers from THSC…")
                    .font(.title2.bold())

                Text("THSC is often very slow. Keep this page open while the website responds.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }
            .padding(36)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.tint.opacity(0.35), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if listings.isEmpty {
            ContentUnavailableView {
                Label("No Papers Loaded", systemImage: "arrow.down.doc")
            } description: {
                Text("Load the selected THSC collection to view its available papers.")
            } actions: {
                Button {
                    startLoadingPapers()
                } label: {
                    Label("Load Papers", systemImage: "arrow.down.doc.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedSource == nil || importCoordinator.isImporting)
            }
        } else if schoolGroups.isEmpty {
            ContentUnavailableView(
                "No Papers to Show",
                systemImage: "tray",
                description: Text(showAlreadyImported ? "No papers match the current filters." : "All matching papers have already been imported or no papers match the current filters.")
            )
        } else {
            List {
                ForEach(schoolGroups) { group in
                    schoolGroupRow(group)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                    if expandedSchoolIDs.contains(group.id) {
                        ForEach(group.papers) { paper in
                            paperRow(paper)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .transition(.opacity)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    func schoolGroupRow(_ group: THSCSchoolPaperGroup) -> some View {
        let isExpanded = expandedSchoolIDs.contains(group.id)
        let selectedCount = group.papers.filter { selection.contains($0.id) }.count

        return HStack(spacing: 10) {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeOut(duration: 0.12), value: isExpanded)
                .frame(width: 14)

            Image(systemName: isExpanded ? "folder.fill.badge.minus" : "folder.fill")
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.schoolName)
                    .font(.headline)
                Text("\(group.papers.count) paper\(group.papers.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if selectedCount > 0 {
                Text("\(selectedCount) selected")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSchoolGroup(group.id)
        }
    }

    func paperRow(_ paper: THSCPaperListing) -> some View {
        let imported = isImported(paper)
        let conflict = hasLocalPaperConflict(paper)

        return HStack(spacing: 12) {
            Button {
                toggleSelection(paper)
            } label: {
                Image(systemName: selection.contains(paper.id) ? "checkmark.square.fill" : "square")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(imported || conflict || importCoordinator.isImporting)

            Text(paper.title)
                .lineLimit(1)

            Spacer()

            Group {
                if imported {
                    Label("Imported", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if conflict {
                    Text("Already in library")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .frame(width: 125, alignment: .trailing)
        }
        .padding(.leading, 30)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 40)
        .contentShape(Rectangle())
        .onTapGesture {
            if !imported, !conflict, !importCoordinator.isImporting {
                toggleSelection(paper)
            }
        }
    }
}
