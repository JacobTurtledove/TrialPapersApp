import AppKit
import SwiftUI

extension PaperViewerScreen {
    var viewerToolbar: some View {
        HStack(spacing: 12) {
            Button {
                saveAnnotationsAndDismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .keyboardShortcut(.cancelAction)
            .help("Close this PDF and return to the paper list")

            Divider()
                .frame(height: 22)

            Picker("Viewing mode", selection: $viewingMode) {
                ForEach(PaperViewingMode.allCases) { mode in
                    if paper.hasSolutions != false || mode == .questions {
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
            .disabled(isFlaggingQuestion)

            Divider()
                .frame(height: 34)

            penToolControls

            Toggle("Completed", isOn: completionBinding)
                .toggleStyle(.checkbox)

            Button {
                beginFlagging()
            } label: {
                Label("Flag Question", systemImage: "flag")
            }
            .disabled(
                isFlaggingQuestion ||
                subject == nil ||
                school == nil ||
                questionURL == nil
            )
            .help("Capture a question for revision")

            Button {
                performOnVisibleControllers { $0.fitWidth() }
            } label: {
                Label("Fit Width", systemImage: "arrow.left.and.right")
            }
            .labelStyle(.iconOnly)
            .help("Fit pages to the viewer")

            Menu {
                Button {
                    viewingMode = .questions
                    presentSolutionsStartPicker()
                } label: {
                    Label("Set First Page of Solutions", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(isFlaggingQuestion || questionURL == nil)

                Button {
                    revealPaper()
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }

                Button {
                    exportPaper()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
                .disabled(questionURL == nil)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help("More actions")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    var penToolControls: some View {
        HStack(spacing: 10) {
            penPresetControl(
                index: 0,
                colorHex: $pen1ColorHex,
                lineWidth: $pen1LineWidth
            )
            penPresetControl(
                index: 1,
                colorHex: $pen2ColorHex,
                lineWidth: $pen2LineWidth
            )

            Button {
                selectedDrawingTool = selectedDrawingTool == .eraser ? .none : .eraser
            } label: {
                Image(systemName: "eraser")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        selectedDrawingTool == .eraser
                            ? Color.accentColor
                            : Color.clear,
                        lineWidth: 2
                    )
            )
            .disabled(isFlaggingQuestion)
            .help("Erase drawn strokes")

            Spacer()
        }
    }

    func penPresetControl(
        index: Int,
        colorHex: Binding<String>,
        lineWidth: Binding<Double>
    ) -> some View {
        VStack(spacing: 3) {
            Button {
                let tool: PDFDrawingTool = .pen(index)
                selectedDrawingTool = selectedDrawingTool == tool ? .none : tool
            } label: {
                PenCircle(
                    colorHex: colorHex.wrappedValue,
                    lineWidth: clampedPenWidth(lineWidth.wrappedValue)
                )
                .frame(width: 28, height: 24)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        selectedDrawingTool == .pen(index)
                            ? Color.accentColor
                            : Color.clear,
                        lineWidth: 2
                    )
            )

            penOptionsMenu(
                colorHex: colorHex,
                lineWidth: lineWidth
            )
        }
        .frame(width: 38)
        .disabled(isFlaggingQuestion)
        .help(index == 0 ? "Pen preset 1" : "Pen preset 2")
    }

    func penOptionsMenu(
        colorHex: Binding<String>,
        lineWidth: Binding<Double>
    ) -> some View {
        Menu {
            Section("Color") {
                ForEach(pdfPenColorChoices) { choice in
                    Button {
                        colorHex.wrappedValue = choice.hex
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(nsColor: NSColor(hexRGB: choice.hex) ?? .black))
                                .frame(width: 9, height: 9)
                            Text(choice.name)
                            if colorHex.wrappedValue == choice.hex {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                ColorPicker(
                    "More Colors",
                    selection: colorBinding(for: colorHex),
                    supportsOpacity: false
                )
            }

            Section("Size") {
                Picker("Size", selection: lineWidth) {
                    ForEach(2...18, id: \.self) { size in
                        Text("\(size) pt").tag(Double(size))
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.down.circle")
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
        .frame(width: 26, height: 18)
    }

    func colorBinding(for colorHex: Binding<String>) -> Binding<Color> {
        Binding(
            get: {
                Color(nsColor: NSColor(hexRGB: colorHex.wrappedValue) ?? .black)
            },
            set: { color in
                let nsColor = NSColor(color)
                colorHex.wrappedValue = (
                    nsColor.usingColorSpace(.deviceRGB) ?? nsColor
                ).hexRGBString
            }
        )
    }
}
