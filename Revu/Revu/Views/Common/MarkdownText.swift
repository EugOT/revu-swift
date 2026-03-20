import SwiftUI
import SwiftMath
import AppKit

/// Renders Markdown text with full block-level layout and inline/block LaTeX support using SwiftMath.
/// 
/// Implementation approach: Native AST-based rendering
/// - Uses Apple's swift-markdown for parsing markdown into an AST
/// - Custom SwiftUI renderer for block-level elements (headings, lists, code blocks, paragraphs)
/// - Preserves existing math rendering via SwiftMath (inline: $...$ and display: $$...$$ / \[...\])
/// - Block quotes, links, and proper paragraph spacing
struct MarkdownText: View {
    let text: String
    let color: Color?

    @Environment(\.font) private var font
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ text: String, color: Color? = nil) {
        self.text = text
        self.color = color
    }

    var body: some View {
        FullMarkdownView(
            text: text,
            baseFont: font,
            foregroundColor: color ?? DesignSystem.Colors.primaryText,
            dynamicTypeSize: dynamicTypeSize
        )
    }
}

// MARK: - Full Markdown Renderer

/// Block-level markdown renderer with math support
private struct FullMarkdownView: View {
    let text: String
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize
    
    private var blocks: [RenderableMarkdownBlock] {
        MarkdownBlockParser.parse(text)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                BlockView(
                    block: block,
                    baseFont: baseFont,
                    foregroundColor: foregroundColor,
                    dynamicTypeSize: dynamicTypeSize,
                    index: index
                )
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }
}

/// Renders individual markdown blocks (headings, paragraphs, lists, code, quotes)
private struct BlockView: View {
    let block: RenderableMarkdownBlock
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize
    let index: Int
    
    var body: some View {
        switch block {
        case .heading(let level, let content):
            HeadingView(
                level: level,
                content: content,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )
            
        case .paragraph(let content):
            ParagraphView(
                content: content,
                baseFont: baseFont,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )
            
        case .bulletList(let items):
            BulletListView(
                items: items,
                baseFont: baseFont,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )
            
        case .numberedList(let items):
            NumberedListView(
                items: items,
                baseFont: baseFont,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )

        case .taskList(let items):
            TaskListView(
                items: items,
                baseFont: baseFont,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )
            
        case .codeBlock(let language, let code):
            CodeBlockView(
                language: language,
                code: code,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )
            
        case .blockQuote(let content):
            BlockQuoteView(
                content: content,
                baseFont: baseFont,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )
            
        case .displayMath(let latex):
            DisplayMathView(
                latex: latex,
                baseFont: baseFont,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )

        case .table(let headers, let rows):
            MarkdownTableView(
                headers: headers,
                rows: rows,
                baseFont: baseFont,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )

        case .footnote(let identifier, let content):
            FootnoteView(
                identifier: identifier,
                content: content,
                baseFont: baseFont,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )

        case .image(let alt, let source):
            MarkdownImageBlockView(alt: alt, source: source)
            
        case .horizontalRule:
            Divider()
                .padding(.vertical, 8)
        }
    }
}

// MARK: - Block Renderers

private struct HeadingView: View {
    let level: Int
    let content: String
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize
    
    private var font: Font {
        switch level {
        case 1: return DesignSystem.Typography.heading // title2, semibold
        case 2: return DesignSystem.Typography.heading
        case 3: return DesignSystem.Typography.subheading // title3, medium
        case 4: return DesignSystem.Typography.subheading
        default: return DesignSystem.Typography.body.weight(.semibold)
        }
    }
    
    var body: some View {
        InlineMarkdownText(content, baseFont: font, foregroundColor: foregroundColor, dynamicTypeSize: dynamicTypeSize)
            .padding(.top, level <= 2 ? 8 : 4)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Heading level \(level): \(content)")
    }
}

private struct ParagraphView: View {
    let content: String
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize
    
    var body: some View {
        InlineMarkdownText(
            content,
            baseFont: baseFont ?? DesignSystem.Typography.body,
            foregroundColor: foregroundColor,
            dynamicTypeSize: dynamicTypeSize
        )
    }
}

private struct BulletListView: View {
    let items: [String]
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(baseFont ?? DesignSystem.Typography.body)
                        .foregroundStyle(foregroundColor)
                    InlineMarkdownText(
                        item,
                        baseFont: baseFont ?? DesignSystem.Typography.body,
                        foregroundColor: foregroundColor,
                        dynamicTypeSize: dynamicTypeSize
                    )
                }
            }
        }
        .padding(.leading, 8)
    }
}

private struct NumberedListView: View {
    let items: [String]
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(baseFont ?? DesignSystem.Typography.body)
                        .foregroundStyle(foregroundColor)
                        .frame(minWidth: 20, alignment: .trailing)
                    InlineMarkdownText(
                        item,
                        baseFont: baseFont ?? DesignSystem.Typography.body,
                        foregroundColor: foregroundColor,
                        dynamicTypeSize: dynamicTypeSize
                    )
                }
            }
        }
        .padding(.leading, 8)
    }
}

private struct TaskListView: View {
    let items: [TaskListItem]
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                        .foregroundStyle(item.checked ? DesignSystem.Colors.accent : foregroundColor)
                    InlineMarkdownText(
                        item.content,
                        baseFont: baseFont ?? DesignSystem.Typography.body,
                        foregroundColor: foregroundColor,
                        dynamicTypeSize: dynamicTypeSize
                    )
                }
            }
        }
        .padding(.leading, 8)
    }
}

private struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(columns: gridColumns, spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    InlineMarkdownText(
                        header,
                        baseFont: (baseFont ?? DesignSystem.Typography.body).weight(.semibold),
                        foregroundColor: foregroundColor,
                        dynamicTypeSize: dynamicTypeSize
                    )
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Colors.window)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        InlineMarkdownText(
                            cell,
                            baseFont: baseFont ?? DesignSystem.Typography.body,
                            foregroundColor: foregroundColor,
                            dynamicTypeSize: dynamicTypeSize
                        )
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Colors.sidebarBackground.opacity(0.35))
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 80), spacing: 0, alignment: .topLeading), count: max(headers.count, 1))
    }
}

private struct FootnoteView: View {
    let identifier: String
    let content: String
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("[^\(identifier)]")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            InlineMarkdownText(
                content,
                baseFont: baseFont ?? DesignSystem.Typography.caption,
                foregroundColor: foregroundColor,
                dynamicTypeSize: dynamicTypeSize
            )
        }
        .padding(.top, 4)
    }
}

private struct MarkdownImageBlockView: View {
    let alt: String
    let source: String

    var body: some View {
        Group {
            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                    case .failure:
                        fallbackLabel
                    case .empty:
                        ProgressView()
                    @unknown default:
                        fallbackLabel
                    }
                }
            } else {
                fallbackLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var resolvedURL: URL? {
        if let absolute = URL(string: source), absolute.scheme != nil {
            return absolute
        }
        return URL(fileURLWithPath: source)
    }

    private var fallbackLabel: some View {
        Label(alt.isEmpty ? source : alt, systemImage: "photo")
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.secondaryText)
    }
}

private struct CodeBlockView: View {
    let language: String?
    let code: String
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = language, !language.isEmpty {
                Text(language)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DesignSystem.Colors.window)
            }
            
            Text(code)
                .font(DesignSystem.Typography.mono)
                .foregroundStyle(foregroundColor)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.hoverBackground)
                .cornerRadius(6)
        }
        .accessibilityLabel("Code block\(language.map { " in \($0)" } ?? "")")
    }
}

private struct BlockQuoteView: View {
    let content: String
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(DesignSystem.Colors.accent.opacity(0.5))
                .frame(width: 4)
            
            InlineMarkdownText(
                content,
                baseFont: baseFont ?? DesignSystem.Typography.body,
                foregroundColor: DesignSystem.Colors.secondaryText,
                dynamicTypeSize: dynamicTypeSize
            )
            .padding(.leading, 12)
            .padding(.vertical, 4)
        }
        .accessibilityLabel("Quote: \(content)")
    }
}

private struct DisplayMathView: View {
    let latex: String
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize
    
    private var fontSize: CGFloat {
        let base = MathFontSizeResolver.pointSize(for: baseFont, defaultSize: 17, dynamicTypeSize: dynamicTypeSize)
        return base * 1.1
    }
    
    var body: some View {
        MathLabelView(
            latex: latex,
            mode: .display,
            fontSize: fontSize,
            color: foregroundColor
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityLabel("Math expression")
    }
}

/// Renders inline markdown with math support (for use within blocks)
private struct InlineMarkdownText: View {
    let text: String
    let baseFont: Font
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize
    
    init(_ text: String, baseFont: Font, foregroundColor: Color, dynamicTypeSize: DynamicTypeSize) {
        self.text = text
        self.baseFont = baseFont
        self.foregroundColor = foregroundColor
        self.dynamicTypeSize = dynamicTypeSize
    }
    
    private var segments: [MathInlineSegment] {
        MathMarkdownParser.inlineSegments(from: text)
    }
    
    var body: some View {
        MathInlineLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                MathInlineSegmentView(
                    segment: segment,
                    baseFont: baseFont,
                    color: foregroundColor,
                    dynamicTypeSize: dynamicTypeSize
                )
            }
        }
    }
}

// MARK: - Legacy Renderer (kept for backward compatibility)

private struct MathMarkdownView: View {
    let text: String
    let baseFont: Font?
    let foregroundColor: Color
    let dynamicTypeSize: DynamicTypeSize

    private var blocks: [MathMarkdownBlock] {
        MathMarkdownParser.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                switch block {
                case .displayMath(let latex):
                    MathLabelView(
                        latex: latex,
                        mode: .display,
                        fontSize: resolvedDisplayFontSize,
                        color: foregroundColor
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .accessibilityLabel("Math expression \(index + 1)")
                case .text(let segments):
                    MathInlineLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { inlineIndex, segment in
                            MathInlineSegmentView(
                                segment: segment,
                                baseFont: baseFont,
                                color: foregroundColor,
                                dynamicTypeSize: dynamicTypeSize
                            )
                            .accessibilityLabel(accessibilityLabel(for: segment, index: inlineIndex))
                        }
                    }
                }
            }
        }
    }

    private var resolvedInlineFontSize: CGFloat {
        MathFontSizeResolver.pointSize(for: baseFont, defaultSize: 17, dynamicTypeSize: dynamicTypeSize)
    }

    private var resolvedDisplayFontSize: CGFloat {
        resolvedInlineFontSize * 1.1
    }

    private func accessibilityLabel(for segment: MathInlineSegment, index: Int) -> String {
        switch segment {
        case .inlineMath:
            return "Inline math expression \(index + 1)"
        case .text(let value):
            return value
        case .lineBreak:
            return "Line break"
        }
    }
}

// MARK: - Inline Segment View

private struct MathInlineSegmentView: View {
    let segment: MathInlineSegment
    let baseFont: Font?
    let color: Color
    let dynamicTypeSize: DynamicTypeSize

    private var inlineFontSize: CGFloat {
        MathFontSizeResolver.pointSize(for: baseFont, defaultSize: 17, dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        switch segment {
        case .text(let value):
            if let attributed = try? AttributedString(markdown: value) {
                Text(attributed)
                    .font(baseFont)
                    .foregroundStyle(color)
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(baseFont)
                    .foregroundStyle(color)
                    .textSelection(.enabled)
            }
        case .inlineMath(let latex):
            MathLabelView(
                latex: latex,
                mode: .text,
                fontSize: inlineFontSize,
                color: color
            )
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[VerticalAlignment.center]
            }
            .alignmentGuide(.lastTextBaseline) { dimensions in
                dimensions[VerticalAlignment.center]
            }
        case .lineBreak:
            Spacer()
                .frame(width: 0, height: 0)
                .layoutValue(key: LineBreakKey.self, value: true)
        }
    }
}

// MARK: - SwiftMath Bridge

private struct MathLabelView: NSViewRepresentable {
    var latex: String
    var mode: MTMathUILabelMode
    var fontSize: CGFloat
    var color: Color
    var textAlignment: MTTextAlignment = .left
    var insets: MTEdgeInsets = MTEdgeInsets()

    func makeNSView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.contentInsets = insets
        label.textAlignment = textAlignment
        label.displayErrorInline = true
        return label
    }

    func updateNSView(_ view: MTMathUILabel, context: Context) {
        view.labelMode = mode
        view.textAlignment = textAlignment
        view.font = Self.fontManager.font(withName: MathFont.latinModernFont.rawValue, size: fontSize)
        view.textColor = MTColor(color)
        view.contentInsets = insets
        view.latex = latex
    }

    private static let fontManager = MTFontManager()
}

// MARK: - Block Parser

/// Markdown block types
enum RenderableMarkdownBlock: Equatable {
    case heading(level: Int, content: String)
    case paragraph(String)
    case bulletList([String])
    case numberedList([String])
    case taskList([TaskListItem])
    case codeBlock(language: String?, code: String)
    case blockQuote(String)
    case displayMath(String)
    case table(headers: [String], rows: [[String]])
    case footnote(identifier: String, content: String)
    case image(alt: String, source: String)
    case horizontalRule
}

struct TaskListItem: Equatable {
    let checked: Bool
    let content: String
}

/// Parses markdown into block-level elements
enum MarkdownBlockParser {
    static func parse(_ input: String) -> [RenderableMarkdownBlock] {
        // First, extract display math blocks ($$...$$ and \[...\])
        let (textWithPlaceholders, mathBlocks) = extractDisplayMath(input)
        
        // Split into lines for block parsing
        let lines = textWithPlaceholders.components(separatedBy: .newlines)
        
        var blocks: [RenderableMarkdownBlock] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty {
                i += 1
                continue
            }
            
            // Check for math placeholder
            if trimmed.hasPrefix("__MATH_BLOCK_") {
                if let mathIndex = Int(trimmed.dropFirst(13).dropLast(2)),
                   mathIndex < mathBlocks.count {
                    blocks.append(.displayMath(mathBlocks[mathIndex]))
                }
                i += 1
                continue
            }
            
            // Headings: # Header
            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let content = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: min(level, 6), content: content))
                i += 1
                continue
            }
            
            // Horizontal rule: --- or ***
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // Footnote definition: [^id]: content
            if let footnote = parseFootnote(from: trimmed) {
                blocks.append(.footnote(identifier: footnote.identifier, content: footnote.content))
                i += 1
                continue
            }

            // Image block: ![alt](source)
            if let image = parseImageLine(trimmed) {
                blocks.append(.image(alt: image.alt, source: image.source))
                i += 1
                continue
            }

            // Table block
            if i + 1 < lines.count, isTableHeaderLine(trimmed), isTableSeparatorLine(lines[i + 1].trimmingCharacters(in: .whitespaces)) {
                let headers = parseTableCells(trimmed)
                i += 2
                var rows: [[String]] = []
                while i < lines.count {
                    let rowTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                    if rowTrimmed.isEmpty || !rowTrimmed.contains("|") {
                        break
                    }
                    rows.append(parseTableCells(rowTrimmed))
                    i += 1
                }
                blocks.append(.table(headers: headers, rows: rows))
                continue
            }
            
            // Code block: ```language
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                i += 1
                var codeLines: [String] = []
                while i < lines.count {
                    let codeLine = lines[i]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        break
                    }
                    codeLines.append(codeLine)
                    i += 1
                }
                blocks.append(.codeBlock(
                    language: language.isEmpty ? nil : language,
                    code: codeLines.joined(separator: "\n")
                ))
                i += 1
                continue
            }
            
            // Block quote: > text
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count {
                    let quoteLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if !quoteLine.hasPrefix(">") {
                        break
                    }
                    quoteLines.append(String(quoteLine.dropFirst(1)).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.blockQuote(quoteLines.joined(separator: " ")))
                continue
            }

            // Task list: - [ ] item or - [x] item
            if isTaskListItem(trimmed) {
                var items: [TaskListItem] = []
                while i < lines.count {
                    let itemLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if itemLine.isEmpty {
                        break
                    }
                    if let parsed = parseTaskListItem(itemLine) {
                        items.append(parsed)
                        i += 1
                    } else {
                        break
                    }
                }
                if !items.isEmpty {
                    blocks.append(.taskList(items))
                }
                continue
            }
            
            // Bullet list: - item or * item
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                var items: [String] = []
                while i < lines.count {
                    let rawLine = lines[i]
                    let itemLine = rawLine.trimmingCharacters(in: .whitespaces)
                    if itemLine.isEmpty {
                        break
                    }
                    if itemLine.hasPrefix("- ") || itemLine.hasPrefix("* ") || itemLine.hasPrefix("+ ") {
                        let level = indentationLevel(of: rawLine)
                        let content = String(itemLine.dropFirst(2))
                        let prefix = String(repeating: "  ", count: level)
                        items.append("\(prefix)\(content)")
                        i += 1
                    } else {
                        break
                    }
                }
                if !items.isEmpty {
                    blocks.append(.bulletList(items))
                }
                continue
            }
            
            // Numbered list: 1. item
            if isNumberedListItem(trimmed) {
                var items: [String] = []
                while i < lines.count {
                    let rawLine = lines[i]
                    let itemLine = rawLine.trimmingCharacters(in: .whitespaces)
                    if itemLine.isEmpty {
                        break
                    }
                    if let content = extractNumberedListContent(itemLine) {
                        let level = indentationLevel(of: rawLine)
                        let prefix = String(repeating: "  ", count: level)
                        items.append("\(prefix)\(content)")
                        i += 1
                    } else {
                        break
                    }
                }
                if !items.isEmpty {
                    blocks.append(.numberedList(items))
                }
                continue
            }
            
            // Paragraph: collect until empty line
            var paragraphLines: [String] = []
            while i < lines.count {
                let paraLine = lines[i]
                let paraTrimmed = paraLine.trimmingCharacters(in: .whitespaces)
                
                // Stop at empty line or block marker
                if paraTrimmed.isEmpty ||
                   paraTrimmed.hasPrefix("#") ||
                   paraTrimmed.hasPrefix("```") ||
                   paraTrimmed.hasPrefix(">") ||
                   paraTrimmed.hasPrefix("- ") ||
                   paraTrimmed.hasPrefix("* ") ||
                   paraTrimmed.hasPrefix("+ ") ||
                   paraTrimmed.hasPrefix("__MATH_BLOCK_") ||
                   parseFootnote(from: paraTrimmed) != nil ||
                   parseImageLine(paraTrimmed) != nil ||
                   isTaskListItem(paraTrimmed) ||
                   (i + 1 < lines.count && isTableHeaderLine(paraTrimmed) && isTableSeparatorLine(lines[i + 1].trimmingCharacters(in: .whitespaces))) ||
                   isNumberedListItem(paraTrimmed) {
                    break
                }
                
                paragraphLines.append(paraTrimmed)
                i += 1
            }
            
            if !paragraphLines.isEmpty {
                blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
            }
        }
        
        return blocks.isEmpty ? [.paragraph("")] : blocks
    }
    
    /// Helper to check if line is a numbered list item
    private static func isNumberedListItem(_ line: String) -> Bool {
        let pattern = "^\\d+\\.\\s+"
        return line.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Helper to extract numbered list content
    private static func extractNumberedListContent(_ line: String) -> String? {
        let pattern = "^\\d+\\.\\s+(.+)"
        guard let range = line.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let match = String(line[range])
        // Remove the number and period
        if let dotIndex = match.firstIndex(of: ".") {
            let content = match[match.index(after: dotIndex)...]
            return content.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func indentationLevel(of line: String) -> Int {
        let leading = line.prefix { $0 == " " || $0 == "\t" }
        let spaces = leading.reduce(into: 0) { partial, ch in
            partial += (ch == "\t") ? 4 : 1
        }
        return max(0, spaces / 2)
    }

    private static func isTaskListItem(_ line: String) -> Bool {
        line.range(of: #"^[-*+]\s+\[(x|X| )\]\s+.+$"#, options: .regularExpression) != nil
    }

    private static func parseTaskListItem(_ line: String) -> TaskListItem? {
        let pattern = #"^[-*+]\s+\[(x|X| )\]\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges == 3,
              let checkedRange = Range(match.range(at: 1), in: line),
              let contentRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        let checkedToken = String(line[checkedRange])
        let content = String(line[contentRange]).trimmingCharacters(in: .whitespaces)
        return TaskListItem(checked: checkedToken.lowercased() == "x", content: content)
    }

    private static func isTableHeaderLine(_ line: String) -> Bool {
        line.contains("|")
    }

    private static func isTableSeparatorLine(_ line: String) -> Bool {
        let cleaned = line.replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty && line.contains("-")
    }

    private static func parseTableCells(_ line: String) -> [String] {
        let normalized = line.trimmingCharacters(in: .whitespaces)
        return normalized
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseFootnote(from line: String) -> (identifier: String, content: String)? {
        let pattern = #"^\[\^([^\]]+)\]:\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges == 3,
              let idRange = Range(match.range(at: 1), in: line),
              let contentRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return (String(line[idRange]), String(line[contentRange]))
    }

    private static func parseImageLine(_ line: String) -> (alt: String, source: String)? {
        let pattern = #"^!\[(.*)\]\(([^)]+)\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges == 3,
              let altRange = Range(match.range(at: 1), in: line),
              let sourceRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return (String(line[altRange]), String(line[sourceRange]))
    }
    
    /// Extract display math blocks and replace with placeholders
    private static func extractDisplayMath(_ input: String) -> (text: String, mathBlocks: [String]) {
        var result = input
        var mathBlocks: [String] = []
        var blockIndex = 0
        
        // Extract $$...$$ blocks using manual search
        var searchStart = result.startIndex
        while let dollarRange = result.range(of: "$$", range: searchStart..<result.endIndex) {
            let afterDollar = result.index(dollarRange.upperBound, offsetBy: 0)
            if let closingRange = result.range(of: "$$", range: afterDollar..<result.endIndex) {
                let latex = String(result[dollarRange.upperBound..<closingRange.lowerBound])
                let placeholder = "__MATH_BLOCK_\(blockIndex)__"
                let fullRange = dollarRange.lowerBound..<closingRange.upperBound
                result.replaceSubrange(fullRange, with: placeholder)
                mathBlocks.append(latex.trimmingCharacters(in: .whitespacesAndNewlines))
                blockIndex += 1
                searchStart = result.index(result.startIndex, offsetBy: placeholder.count, limitedBy: result.endIndex) ?? result.endIndex
            } else {
                break
            }
        }
        
        // Extract \[...\] blocks
        searchStart = result.startIndex
        while let openRange = result.range(of: "\\[", range: searchStart..<result.endIndex) {
            let afterOpen = openRange.upperBound
            if let closeRange = result.range(of: "\\]", range: afterOpen..<result.endIndex) {
                let latex = String(result[afterOpen..<closeRange.lowerBound])
                let placeholder = "__MATH_BLOCK_\(blockIndex)__"
                let fullRange = openRange.lowerBound..<closeRange.upperBound
                result.replaceSubrange(fullRange, with: placeholder)
                mathBlocks.append(latex.trimmingCharacters(in: .whitespacesAndNewlines))
                blockIndex += 1
                searchStart = result.index(result.startIndex, offsetBy: placeholder.count, limitedBy: result.endIndex) ?? result.endIndex
            } else {
                break
            }
        }
        
        return (result, mathBlocks)
    }
}

// MARK: - Legacy Math Parser (for inline rendering)

enum MathMarkdownBlock: Equatable {
    case text([MathInlineSegment])
    case displayMath(String)
}

enum MathInlineSegment: Equatable {
    case text(String)
    case inlineMath(String)
    case lineBreak
}

enum MathMarkdownParser {
    static func parse(_ input: String) -> [MathMarkdownBlock] {
        var blocks: [MathMarkdownBlock] = []
        var buffer = ""
        var index = input.startIndex

        while index < input.endIndex {
            if input[index...].hasPrefix("$$") {
                let searchStart = input.index(index, offsetBy: 2)
                if let close = input.range(of: "$$", range: searchStart..<input.endIndex) {
                    if !buffer.isEmpty {
                        blocks.append(.text(inlineSegments(from: buffer)))
                        buffer.removeAll()
                    }

                    let latex = String(input[searchStart..<close.lowerBound])
                    blocks.append(.displayMath(latex.trimmingCharacters(in: .whitespacesAndNewlines)))
                    index = close.upperBound
                    continue
                } else {
                    buffer.append("$$")
                    index = searchStart
                    continue
                }
            }

            if input[index...].hasPrefix("\\[") {
                let searchStart = input.index(index, offsetBy: 2)
                if let close = input.range(of: "\\]", range: searchStart..<input.endIndex) {
                    if !buffer.isEmpty {
                        blocks.append(.text(inlineSegments(from: buffer)))
                        buffer.removeAll()
                    }

                    let latex = String(input[searchStart..<close.lowerBound])
                    blocks.append(.displayMath(latex.trimmingCharacters(in: .whitespacesAndNewlines)))
                    index = close.upperBound
                    continue
                } else {
                    buffer.append("\\[")
                    index = searchStart
                    continue
                }
            }

            buffer.append(input[index])
            index = input.index(after: index)
        }

        if !buffer.isEmpty {
            blocks.append(.text(inlineSegments(from: buffer)))
        }

        if blocks.isEmpty {
            return [.text([])]
        }

        return blocks
    }

    static func inlineSegments(from text: String) -> [MathInlineSegment] {
        var segments: [MathInlineSegment] = []
        var buffer = ""
        var index = text.startIndex

        func flushBuffer() {
            if !buffer.isEmpty {
                segments.append(contentsOf: splitTextPreservingLineBreaks(buffer))
                buffer.removeAll()
            }
        }

        while index < text.endIndex {
            let nextIndex = text.index(after: index)

            if text[index] == "\\" && nextIndex < text.endIndex && text[nextIndex] == "$" {
                buffer.append("$")
                index = text.index(after: nextIndex)
                continue
            }

            if text[index...].hasPrefix("\\("), let close = text.range(of: "\\)", range: nextIndex..<text.endIndex) {
                flushBuffer()
                let latexStart = nextIndex
                let latex = String(text[latexStart..<close.lowerBound])
                segments.append(.inlineMath(latex))
                index = close.upperBound
                continue
            }

            if text[index] == "$" {
                if nextIndex < text.endIndex, text[nextIndex] == "$" {
                    buffer.append("$$")
                    index = text.index(after: nextIndex)
                    continue
                }

                if let close = text.range(of: "$", range: nextIndex..<text.endIndex) {
                    flushBuffer()
                    let latex = String(text[nextIndex..<close.lowerBound])
                    segments.append(.inlineMath(latex))
                    index = close.upperBound
                    continue
                }
            }

            buffer.append(text[index])
            index = nextIndex
        }

        flushBuffer()
        return segments
    }

    private static func splitTextPreservingLineBreaks(_ text: String) -> [MathInlineSegment] {
        let parts = text.split(separator: "\n", omittingEmptySubsequences: false)
        var segments: [MathInlineSegment] = []

        for (idx, part) in parts.enumerated() {
            if !part.isEmpty {
                segments.append(.text(String(part)))
            }

            if idx < parts.count - 1 {
                segments.append(.lineBreak)
            }
        }

        return segments
    }
}

// MARK: - Layout

private struct MathInlineLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let maxWidth = proposal.width ?? 800
        let layoutData = buildLayout(maxWidth: maxWidth, subviews: subviews)
        cache.lines = layoutData.lines
        return layoutData.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let maxWidth = bounds.width > 0 ? bounds.width : (proposal.width ?? 800)
        cache.lines = buildLayout(maxWidth: maxWidth, subviews: subviews).lines

        var currentY = bounds.minY

        for line in cache.lines {
            var currentX = bounds.minX

            for item in line.items {
                let subview = subviews[item.index]
                let proposal = ProposedViewSize(width: item.size.width, height: item.size.height)
                subview.place(at: CGPoint(x: currentX, y: currentY), proposal: proposal)

                currentX += item.size.width + spacing
            }

            currentY += line.height + lineSpacing
        }
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {}

    private func buildLayout(maxWidth: CGFloat, subviews: Subviews) -> (lines: [Line], size: CGSize) {
        var lines: [Line] = []
        var currentLine = Line()

        func commitLine() {
            if !currentLine.items.isEmpty {
                lines.append(currentLine)
                currentLine = Line()
            }
        }

        for (index, subview) in subviews.enumerated() {
            if subview[LineBreakKey.self] {
                commitLine()
                continue
            }

            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))

            if currentLine.width > 0, currentLine.width + spacing + size.width > maxWidth {
                commitLine()
            }

            currentLine.addItem(index: index, size: size, spacing: spacing)
        }

        commitLine()

        let totalHeight = lines.reduce(CGFloat(0)) { partial, line in
            partial + line.height
        } + max(0, CGFloat(lines.count - 1) * lineSpacing)

        let maxLineWidth = lines.map(\.width).max() ?? 0
        return (lines, CGSize(width: maxLineWidth, height: totalHeight))
    }

    struct Cache {
        var lines: [Line] = []
    }

    struct Line {
        var items: [LineItem] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func addItem(index: Int, size: CGSize, spacing: CGFloat) {
            if width > 0 {
                width += spacing
            }
            width += size.width

            height = max(height, size.height)

            items.append(LineItem(index: index, size: size))
        }
    }

    struct LineItem {
        let index: Int
        let size: CGSize
    }
}

private struct LineBreakKey: LayoutValueKey {
    static let defaultValue: Bool = false
}

// MARK: - Helpers

private enum MathFontSizeResolver {
    static func pointSize(for font: Font?, defaultSize: CGFloat, dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let baseSize = guessPointSize(for: font) ?? defaultSize
        return baseSize * dynamicTypeSize.designSystemSpacingMultiplier
    }

    private static func guessPointSize(for font: Font?) -> CGFloat? {
        guard let font else { return nil }
        let description = String(describing: font).lowercased()

        if description.contains("largetitle") { return 34 }
        if description.contains("title3") { return 20 }
        if description.contains("title2") { return 22 }
        if description.contains("title") { return 28 }
        if description.contains("headline") { return 17 }
        if description.contains("subheadline") { return 15 }
        if description.contains("callout") { return 16 }
        if description.contains("footnote") { return 13 }
        if description.contains("caption2") { return 11 }
        if description.contains("caption") { return 12 }
        if description.contains("body") { return 17 }

        return nil
    }
}

#if DEBUG
#Preview("MarkdownText") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            MarkdownText("""
            ## Markdown + LaTeX

            Inline: $e^{i\\pi} + 1 = 0$.

            Display:
            $$
            \\int_0^\\infty e^{-x^2}\\,dx = \\frac{\\sqrt{\\pi}}{2}
            $$

            - Bullets
            - **Bold**
            - `Code`
            """)
            .font(DesignSystem.Typography.body)
        }
        .padding()
    }
    .frame(width: 560, height: 520)
    .background(DesignSystem.Colors.window)
}
#endif
