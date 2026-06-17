import AppKit
import SwiftUI

struct SolutionsStartPagePickerSheet: View {
    let url: URL
    let pageCount: Int
    @Binding var selectedPage: Int
    @FocusState private var isKeyboardNavigationFocused: Bool
    let allowsCancel: Bool
    let cancel: () -> Void
    let markNoSolutions: () -> Void
    let confirm: () -> Void

    private var canMoveBackward: Bool {
        selectedPage > 1
    }

    private var canMoveForward: Bool {
        selectedPage < pageCount
    }

    private var sliderValue: Binding<Double> {
        Binding(
            get: { Double(selectedPage) },
            set: { selectedPage = clampedPage(Int($0.rounded())) }
        )
    }

    private var pageTextValue: Binding<Int> {
        Binding(
            get: { selectedPage },
            set: { selectedPage = clampedPage($0) }
        )
    }

    private func previousPage() {
        selectedPage = clampedPage(selectedPage - 1)
    }

    private func nextPage() {
        selectedPage = clampedPage(selectedPage + 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select the first page with solutions")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            PDFPagePreviewView(url: url, pageNumber: selectedPage)
                .frame(width: 540, height: 620)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Button {
                        previousPage()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canMoveBackward)
                    .help("Previous page")

                    Text("Page")
                        .foregroundStyle(.secondary)

                    TextField("Page", value: pageTextValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 72)

                    Text("of \(pageCount)")
                        .foregroundStyle(.secondary)

                    Button {
                        nextPage()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canMoveForward)
                    .help("Next page")

                    Slider(
                        value: sliderValue,
                        in: 1...Double(max(pageCount, 1))
                    )
                }

                HStack {
                    Button("This Paper Has No Solutions", action: markNoSolutions)

                    Spacer()

                    if allowsCancel {
                        Button("Cancel", role: .cancel, action: cancel)
                    }

                    Button("This is the first solutions page", action: confirm)
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedPage <= 1)
                }
            }
            .padding(20)
        }
        .frame(width: 580)
        .focusable()
        .focused($isKeyboardNavigationFocused)
        .onAppear {
            isKeyboardNavigationFocused = true
        }
        .onMoveCommand { direction in
            switch direction {
            case .left, .up:
                previousPage()
            case .right, .down:
                nextPage()
            @unknown default:
                break
            }
        }
    }

    private func clampedPage(_ page: Int) -> Int {
        min(max(page, 1), max(pageCount, 1))
    }
}
