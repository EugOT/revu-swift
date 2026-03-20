import Testing
@testable import Revu

@Suite("Math markdown parser")
struct MathMarkdownParserTests {
    @Test("Parses inline math with surrounding text")
    func inlineMathIsIsolated() {
        let blocks = MathMarkdownParser.parse("Area of a square is $a^2$ units.")
        #expect(blocks.count == 1)

        guard case .text(let segments) = blocks.first else {
            Issue.record("Expected text block, got \(String(describing: blocks.first))")
            return
        }

        #expect(segments == [
            .text("Area of a square is "),
            .inlineMath("a^2"),
            .text(" units.")
        ])
    }

    @Test("Parses display math delimited by $$")
    func displayMathBlockIsSeparated() {
        let blocks = MathMarkdownParser.parse("Before $$x = y$$ after")
        #expect(blocks.count == 3)

        #expect(blocks[0] == .text([.text("Before ")]))
        #expect(blocks[1] == .displayMath("x = y"))
        #expect(blocks[2] == .text([.text(" after")]))
    }

    @Test("Keeps explicit line breaks in text")
    func preservesLineBreaks() {
        let blocks = MathMarkdownParser.parse("Line one\n$E=mc^2$\nLine two")
        #expect(blocks.count == 1)

        guard case .text(let segments) = blocks.first else {
            Issue.record("Expected text block")
            return
        }

        #expect(segments == [
            .text("Line one"),
            .lineBreak,
            .inlineMath("E=mc^2"),
            .lineBreak,
            .text("Line two")
        ])
    }

    @Test("Parses bracketed display math blocks")
    func parsesBracketDisplayMath() {
        let blocks = MathMarkdownParser.parse("Start \\[x^2 + y^2 = z^2\\] End")
        #expect(blocks.count == 3)
        #expect(blocks[0] == .text([.text("Start ")]))
        #expect(blocks[1] == .displayMath("x^2 + y^2 = z^2"))
        #expect(blocks[2] == .text([.text(" End")]))
    }
}
