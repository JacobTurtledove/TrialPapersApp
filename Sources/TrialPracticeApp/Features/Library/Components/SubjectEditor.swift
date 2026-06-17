import SwiftUI

struct SubjectEditor: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: (String, String) -> String?
    @State private var name: String
    @State private var color: Color
    @State private var validationMessage: String?

    init(
        title: String,
        initialName: String = "",
        initialColorHex: String = "#4A90E2",
        onSave: @escaping (String, String) -> String?
    ) {
        self.title = title
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _color = State(initialValue: Color(subjectHex: initialColorHex))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title2.bold())
            TextField("e.g. Maths Advanced", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            ColorPicker("Folder Colour", selection: $color, supportsOpacity: false)

            if let validationMessage {
                Text(validationMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func save() {
        validationMessage = onSave(name, color.subjectHex)
        if validationMessage == nil {
            dismiss()
        }
    }
}
