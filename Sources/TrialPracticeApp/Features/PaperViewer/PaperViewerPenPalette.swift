struct PDFPenColorChoice: Identifiable {
    let name: String
    let hex: String

    var id: String { hex }
}

let pdfPenColorChoices: [PDFPenColorChoice] = [
    PDFPenColorChoice(name: "Black", hex: "#000000"),
    PDFPenColorChoice(name: "Red", hex: "#D92D20"),
    PDFPenColorChoice(name: "Blue", hex: "#2563EB"),
    PDFPenColorChoice(name: "Green", hex: "#16A34A"),
    PDFPenColorChoice(name: "Purple", hex: "#7C3AED"),
    PDFPenColorChoice(name: "Orange", hex: "#EA580C"),
    PDFPenColorChoice(name: "Yellow", hex: "#FACC15"),
    PDFPenColorChoice(name: "Gray", hex: "#6B7280")
]
