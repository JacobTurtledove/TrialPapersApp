import SwiftUI

struct NESAPastPaperCourse: Identifiable, Hashable {
    let name: String
    let learningArea: String
    let slug: String

    var id: String { slug }

    var url: URL {
        URL(
            string:
                "https://www.nsw.gov.au/education-and-training/nesa/curriculum/hsc-exam-papers/\(slug)"
        )!
    }
}

enum NESAPastPaperCatalogue {
    static let allCoursesURL = URL(
        string: "https://www.nsw.gov.au/education-and-training/nesa/curriculum/hsc-exam-papers"
    )!

    static let courses: [NESAPastPaperCourse] = [
        course("Drama", area: "Creative Arts", slug: "drama"),
        course("Music 1", area: "Creative Arts", slug: "music-1"),
        course("Music 2", area: "Creative Arts", slug: "music-2"),
        course("Music Extension", area: "Creative Arts", slug: "music-extension"),
        course("Visual Arts", area: "Creative Arts", slug: "visual-arts"),

        course("English Advanced", area: "English", slug: "english-advanced"),
        course("English EAL/D", area: "English", slug: "english-eald"),
        course("English Extension 1", area: "English", slug: "english-extension-1"),
        course("English Standard", area: "English", slug: "english-standard"),

        course("Ancient History", area: "HSIE", slug: "ancient-history"),
        course("Business Studies", area: "HSIE", slug: "business-studies"),
        course("Economics", area: "HSIE", slug: "economics"),
        course("Geography", area: "HSIE", slug: "geography"),
        course("Legal Studies", area: "HSIE", slug: "legal-studies"),
        course("Modern History", area: "HSIE", slug: "modern-history"),
        course("Society and Culture", area: "HSIE", slug: "society-and-culture"),
        course("Studies of Religion I", area: "HSIE", slug: "studies-of-religion-1"),
        course("Studies of Religion II", area: "HSIE", slug: "studies-of-religion-2"),

        course("Mathematics Advanced", area: "Mathematics", slug: "mathematics-advanced"),
        course("Mathematics Extension 1", area: "Mathematics", slug: "mathematics-extension-1"),
        course("Mathematics Extension 2", area: "Mathematics", slug: "mathematics-extension-2"),
        course("Mathematics Standard 1", area: "Mathematics", slug: "mathematics-standard-1"),
        course("Mathematics Standard 2", area: "Mathematics", slug: "mathematics-standard-2"),

        course(
            "Health and Movement Science",
            area: "PDHPE",
            slug: "health-and-movement-science"
        ),
        course(
            "Personal Development, Health and Physical Education",
            area: "PDHPE",
            slug: "personal-development-health-and-physical-education"
        ),

        course("Biology", area: "Science", slug: "biology"),
        course("Chemistry", area: "Science", slug: "chemistry"),
        course(
            "Earth and Environmental Science",
            area: "Science",
            slug: "earth-and-environmental-science"
        ),
        course("Investigating Science", area: "Science", slug: "investigating-science"),
        course("Physics", area: "Science", slug: "physics"),
        course("Science Extension", area: "Science", slug: "science-extension"),

        course("Agriculture", area: "Technology", slug: "agriculture"),
        course("Design and Technology", area: "Technology", slug: "design-and-technology"),
        course("Engineering Studies", area: "Technology", slug: "engineering-studies"),
        course("Enterprise Computing", area: "Technology", slug: "enterprise-computing"),
        course("Food Technology", area: "Technology", slug: "food-technology"),
        course("Industrial Technology", area: "Technology", slug: "industrial-technology"),
        course("Software Engineering", area: "Technology", slug: "software-engineering")
    ]

    static var learningAreas: [String] {
        Array(Set(courses.map(\.learningArea))).sorted()
    }

    private static func course(
        _ name: String,
        area: String,
        slug: String
    ) -> NESAPastPaperCourse {
        NESAPastPaperCourse(name: name, learningArea: area, slug: slug)
    }
}

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

