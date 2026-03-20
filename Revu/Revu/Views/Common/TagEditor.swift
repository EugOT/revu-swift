import SwiftUI

struct TagEditor: View {
    @Binding var tags: [String]
    var suggestions: [String]

    @State private var newTag: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Label(tag, systemImage: "number")
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .overlay(
                            HStack {
                                Spacer(minLength: 4)
                                Button {
                                    remove(tag)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.trailing, 4)
                        )
                        .accessibilityLabel("Tag \(tag)")
                }
            }

            HStack {
                TextField("Add tag", text: $newTag)
                    .onSubmit(addTagFromInput)
                    .textFieldStyle(.roundedBorder)
                if !filteredSuggestions.isEmpty {
                    Menu("Suggestions") {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                newTag = suggestion
                                addTagFromInput()
                            }
                        }
                    }
                    .menuIndicator(.hidden)
                }
                Button("Add") {
                    addTagFromInput()
                }
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var filteredSuggestions: [String] {
        suggestions
            .filter { suggestion in
                let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return false }
                guard !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return false }
                return newTag.isEmpty || trimmed.lowercased().contains(newTag.lowercased())
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func addTagFromInput() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        if !tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            tags.append(tag)
        }
        newTag = ""
    }

    private func remove(_ tag: String) {
        tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if width + size.width > maxWidth {
                height += rowHeight + spacing
                width = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            width += size.width + spacing
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#if DEBUG
private struct TagEditorPreview: View {
    @State private var tags: [String] = ["math", "language"]

    var body: some View {
        TagEditor(
            tags: $tags,
            suggestions: ["math", "linear-algebra", "language", "french", "spanish", "anki", "fsrs"]
        )
        .padding()
        .frame(width: 520)
        .background(DesignSystem.Colors.window)
    }
}

#Preview("TagEditor") {
    TagEditorPreview()
}
#endif
