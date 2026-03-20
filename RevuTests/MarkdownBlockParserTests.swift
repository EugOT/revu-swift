import Testing
@testable import Revu

@Suite("Markdown block parser")
struct MarkdownBlockParserTests {
    @Test("Parses task lists and tables")
    func parsesTaskListsAndTables() {
        let input = """
        - [x] Reviewed chapter 1
        - [ ] Review chapter 2

        | Topic | Status |
        | --- | --- |
        | Cells | done |
        | DNA | next |
        """

        let blocks = MarkdownBlockParser.parse(input)
        #expect(blocks.count >= 2)

        guard case .taskList(let tasks) = blocks[0] else {
            Issue.record("Expected task list in first block")
            return
        }
        #expect(tasks.count == 2)
        #expect(tasks[0].checked == true)
        #expect(tasks[1].checked == false)

        guard case .table(let headers, let rows) = blocks[1] else {
            Issue.record("Expected markdown table in second block")
            return
        }
        #expect(headers == ["Topic", "Status"])
        #expect(rows.count == 2)
    }

    @Test("Parses nested lists, images, and footnotes")
    func parsesNestedListsImagesAndFootnotes() {
        let input = """
        - Parent
          - Child
        1. First
           2. Second

        ![diagram](study-guides/guide-1/diagram.png)
        [^1]: Footnote detail.
        """

        let blocks = MarkdownBlockParser.parse(input)
        #expect(blocks.count >= 4)

        guard case .bulletList(let bulletItems) = blocks[0] else {
            Issue.record("Expected bullet list first")
            return
        }
        #expect(bulletItems.count == 2)
        #expect(bulletItems[1].hasPrefix("  "))

        guard case .numberedList(let numberedItems) = blocks[1] else {
            Issue.record("Expected numbered list second")
            return
        }
        #expect(numberedItems.count == 2)
        #expect(numberedItems[1].hasPrefix("  "))

        guard case .image(_, let source) = blocks[2] else {
            Issue.record("Expected image block third")
            return
        }
        #expect(source.contains("diagram.png"))

        guard case .footnote(let id, let content) = blocks[3] else {
            Issue.record("Expected footnote block fourth")
            return
        }
        #expect(id == "1")
        #expect(content.contains("Footnote"))
    }
}
