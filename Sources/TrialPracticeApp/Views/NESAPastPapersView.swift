import SwiftUI

struct NESAPastPapersView: View {
    @State private var searchText = ""

    private var filteredCourses: [NESAPastPaperCourse] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return NESAPastPaperCatalogue.courses }
        return NESAPastPaperCatalogue.courses.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.learningArea.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Official NESA past papers")
                        .font(.headline)
                    Text("Links open NESA pages containing papers, marking guidelines, and feedback.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Link(destination: NESAPastPaperCatalogue.allCoursesURL) {
                    Label("View All NESA Courses", systemImage: "safari")
                }
            }
            .padding(16)

            Divider()

            if filteredCourses.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(NESAPastPaperCatalogue.learningAreas, id: \.self) { area in
                        let courses = filteredCourses.filter { $0.learningArea == area }
                        if !courses.isEmpty {
                            Section(area) {
                                ForEach(courses) { course in
                                    Link(destination: course.url) {
                                        HStack {
                                            Label(course.name, systemImage: "doc.text")
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("NESA Past Papers")
        .searchable(text: $searchText, prompt: "Search subject or learning area")
    }
}
