import SwiftUI

struct ImportFormatGuideView: View {
    let activeFormatID: String?

    private let entries = ImportFormatGuideEntry.supported

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supported import formats")
                .font(.headline)
            Text("Pick the file type that matches how your material is organised. Each importer handles decks, basic flashcards, cloze deletions, and multiple choice questions.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(entries) { entry in
                FormatGuideRow(entry: entry, isActive: entry.id == activeFormatID)
            }
        }
    }
}

private struct FormatGuideRow: View {
    let entry: ImportFormatGuideEntry
    let isActive: Bool

    private var background: some ShapeStyle {
        if isActive {
            Color.accentColor.opacity(0.12)
        } else {
            Color.primary.opacity(0.04)
        }
    }

    private var border: some ShapeStyle {
        if isActive {
            Color.accentColor
        } else {
            Color.primary.opacity(0.08)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                if isActive {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.2))
                        .overlay(
                            Text("Currently selected")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                        )
                        .fixedSize()
                }
            }

            Text(entry.subtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(entry.highlights, id: \.self) { highlight in
                    Label {
                        Text(highlight)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .renderingMode(.template)
                            .foregroundStyle(Color.accentColor)
                    }
                    .labelStyle(.leadingIcon)
                }
            }

            if let example = entry.example {
                CodeExampleView(example: example, caption: entry.exampleCaption)
            }

            if let footnote = entry.footnote {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(border, lineWidth: isActive ? 2 : 1)
        )
    }
}

private struct CodeExampleView: View {
    let example: String
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(example)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
        }
    }
}

struct ImportFormatGuideEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let highlights: [String]
    let example: String?
    let exampleCaption: String?
    let footnote: String?

    static let supported: [ImportFormatGuideEntry] = [
        ImportFormatGuideEntry(
            id: "anki",
            title: "Anki package (.apkg)",
            subtitle: "The fastest path from Anki → Revu while keeping decks, tags, scheduling, and media.",
            highlights: [
                "Imports every deck (including sub-decks) from the exported package.",
                "Brings tags, cloze cards, suspended state, due dates, intervals, and ease factors.",
                "Copies referenced media into Revu’s local attachments folder so it stays offline-ready.",
                "Uses stable identifiers so re-importing updates instead of duplicating."
            ],
            example: nil,
            exampleCaption: nil,
            footnote: "Export from Anki Desktop: File → Export… → select “All decks” and enable scheduling + media."
        ),
        ImportFormatGuideEntry(
            id: "json",
            title: "Revu JSON",
            subtitle: "Best when moving data between Revu or keeping a full-fidelity backup.",
            highlights: [
                "Keeps existing deck and card identifiers so subsequent imports merge instead of duplicating.",
                "Preserves tags, attachments, and timestamps.",
                "Accepts optional deck-level `dueDate` values so deadlines travel with your backups.",
                "Great hand-off format for other tools or LLMs that can emit structured JSON.",
                "Starts with `schema`, `version`, and `exportedAt` fields exactly as shown in the snippet."
            ],
            example: """
            {
              "schema": "revu.flashcards",
              "version": 2,
              "exportedAt": "2025-10-04T00:00:00Z",
              "decks": [
                {
                  "id": "F65C2E7E-3AC6-49C2-9733-202C4B8B202D",
                  "name": "Biology",
                  "dueDate": "2025-11-18T23:59:59Z",
                  "cards": [
                    {
                      "id": "3F8A20E2-6D1A-4A6F-99AF-74AB9D3AAF61",
                      "kind": "basic",
                      "front": "What is the powerhouse of the cell?",
                      "back": "Mitochondria"
                    }
                  ]
                }
              ]
            }
            """,
            exampleCaption: "Example snippet from an exported deck",
            footnote: "Export from Revu to get a template or share this header with an LLM so it returns the correct schema."
        ),
        ImportFormatGuideEntry(
            id: "csv",
            title: "CSV / TSV spreadsheets",
            subtitle: "Perfect for quick edits in Numbers, Excel, Google Sheets, or tools that export tabular data.",
            highlights: [
                "One row per card. Provide at least `deck`, `kind`, and the fields required for that card type.",
                "`choices` can contain newline, `;`, or `|`-separated options for multiple choice cards.",
                "`correct` accepts either the matching choice text or a 1-based index."
            ],
            example: """
            deck,kind,front,back,tags,choices,correct
            Biology,basic,"Cell powerhouse?","Mitochondria","science;bio",,
            Biology,multipleChoice,"Primary colors?","Red + blue + yellow","art","Red|Blue|Yellow|Green","green"
            """,
            exampleCaption: "CSV with basic and multiple choice cards",
            footnote: "If your tool exports TSV, the importer automatically detects tabs instead of commas."
        ),
        ImportFormatGuideEntry(
            id: "markdown",
            title: "Markdown blocks",
            subtitle: "Optimised for writing by hand or prompting LLMs—each block of key/value pairs represents a card.",
            highlights: [
                "Separate cards with `---` and include `deck:` on every block.",
                "Use `front:` + `back:`, `cloze:`, or `prompt:` + `choices:` depending on the card type.",
                "Lists like `tags:` or `choices:` can be comma separated or written as bullet lists.",
                "Math is supported with LaTeX: inline `$...$` or block `$$...$$` renders on cards."
            ],
            example: """
            deck: Biology
            kind: basic
            front: What is the powerhouse of the cell?
            back: Mitochondria ($\\text{ATP}$ factory)
            tags:
              - science
              - biology
            ---
            deck: Biology
            kind: cloze
            cloze: The powerhouse of the cell is the {{c1::mitochondria}}.
            back: mitochondria
            """,
            exampleCaption: "Two cards expressed with block-delimited Markdown",
            footnote: "Great for drafting in plain text or asking an LLM to produce study material. Math uses LaTeX syntax across study and previews."
        )
    ]
}

#if DEBUG
#Preview("ImportFormatGuideView") {
    ImportFormatGuideView(activeFormatID: "csv")
        .padding()
        .frame(width: 720, height: 680)
}
#endif

private extension LabelStyle where Self == LeadingIconLabelStyle {
    static var leadingIcon: LeadingIconLabelStyle { LeadingIconLabelStyle() }
}

private struct LeadingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon
                .font(.caption)
            configuration.title
        }
    }
}
