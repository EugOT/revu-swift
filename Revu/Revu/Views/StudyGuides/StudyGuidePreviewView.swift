import SwiftUI
import AppKit

/// Renders markdown content using the existing MarkdownText component.
/// Used by StudyGuideEditorView in Preview mode.
struct StudyGuidePreviewView: View {
    @Environment(\.storage) private var storage
    let markdownContent: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            MarkdownText(resolvedMarkdownContent)
                .font(DesignSystem.Typography.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.openURL, OpenURLAction { url in
                    NSWorkspace.shared.open(url)
                    return .handled
                })
        }
    }

    private var resolvedMarkdownContent: String {
        guard let provider = storage as? AttachmentDirectoryProviding else {
            return markdownContent
        }
        let root = provider.attachmentsDirectory
        let pattern = #"\((study-guides/[^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return markdownContent
        }
        let matches = regex.matches(
            in: markdownContent,
            range: NSRange(location: 0, length: (markdownContent as NSString).length)
        )
        guard !matches.isEmpty else { return markdownContent }

        var output = markdownContent
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: output) else { continue }
            let relativePath = String(output[range])
            let absolute = root.appendingPathComponent(relativePath).absoluteString
            output.replaceSubrange(range, with: absolute)
        }
        return output
    }
}

#if DEBUG
#Preview("StudyGuidePreviewView") {
    ScrollView {
        StudyGuidePreviewView(markdownContent: """
        # Cell Biology Notes

        ## Organelles

        - **Mitochondria**: The powerhouse of the cell
        - **Nucleus**: Contains genetic material
        - **Ribosomes**: Protein synthesis

        ## Cell Membrane

        The cell membrane is a phospholipid bilayer that controls what enters and exits the cell.

        ### Key Functions

        1. Selective permeability
        2. Signal transduction
        3. Cell communication

        ## Mathematical Model

        The diffusion rate can be modeled by:

        $$
        J = -D \\frac{dC}{dx}
        $$

        Where $J$ is the flux, $D$ is the diffusion coefficient, and $\\frac{dC}{dx}$ is the concentration gradient.

        ```swift
        let cell = Cell()
        cell.divide()
        ```
        """)
        .padding()
    }
    .frame(width: 600, height: 500)
    .background(DesignSystem.Colors.window)
}
#endif
