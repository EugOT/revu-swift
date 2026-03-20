import SwiftUI
import AppKit

struct StudyGuideMarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    var onDropURLs: (([URL]) -> [String])?
    var onPasteImageData: ((Data, String) -> String?)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        // Build a proper text system for the scroll view
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(containerSize: NSSize(
            width: contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = StudyGuideNSTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator

        // Sizing: fill scroll view width, grow vertically
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.usesFontPanel = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.clear
        textView.string = text
        textView.onDroppedURLs = { (urls: [URL]) in
            guard let onDropURLs else { return }
            let links = onDropURLs(urls)
            guard !links.isEmpty else { return }
            textView.insertText(links.joined(separator: "\n"), replacementRange: textView.selectedRange())
        }
        textView.onPastedImageData = { data, filename in
            guard let onPasteImageData else { return false }
            guard let markdown = onPasteImageData(data, filename) else { return false }
            textView.insertText(markdown, replacementRange: textView.selectedRange())
            return true
        }
        textView.selectedRanges = [NSValue(range: selectedRange)]

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        // Don't push state back into the text view while it's driving the update
        guard !context.coordinator.isUpdatingFromTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        if textView.selectedRange() != selectedRange {
            textView.setSelectedRange(selectedRange)
            textView.scrollRangeToVisible(selectedRange)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: StudyGuideMarkdownEditorView
        weak var textView: StudyGuideNSTextView?
        var isUpdatingFromTextView = false

        init(_ parent: StudyGuideMarkdownEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            isUpdatingFromTextView = true
            if parent.text != textView.string {
                parent.text = textView.string
            }
            let range = textView.selectedRange()
            if parent.selectedRange != range {
                parent.selectedRange = range
            }
            isUpdatingFromTextView = false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            isUpdatingFromTextView = true
            let range = textView.selectedRange()
            if parent.selectedRange != range {
                parent.selectedRange = range
            }
            isUpdatingFromTextView = false
        }
    }
}

final class StudyGuideNSTextView: NSTextView {
    var onDroppedURLs: (([URL]) -> Void)?
    var onPastedImageData: ((Data, String) -> Bool)?

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        if event.charactersIgnoringModifiers == "b" {
            wrapSelection(prefix: "**", suffix: "**")
            return true
        }
        if event.charactersIgnoringModifiers == "i" {
            wrapSelection(prefix: "_", suffix: "_")
            return true
        }
        if event.charactersIgnoringModifiers == "7", event.modifierFlags.contains(.shift) {
            prefixLineSelection(with: "- ")
            return true
        }
        if event.charactersIgnoringModifiers == "8", event.modifierFlags.contains(.shift) {
            prefixLineSelection(with: "1. ")
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 { // tab
            if event.modifierFlags.contains(.shift) {
                unindentSelection()
            } else {
                indentSelection()
            }
            return
        }
        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        if let fileURLs = readPastedFileURLs(), !fileURLs.isEmpty {
            onDroppedURLs?(fileURLs)
            return
        }
        if let imageData = readPastedImageData() {
            let handled = onPastedImageData?(imageData, "pasted-image.png") ?? false
            if handled { return }
        }
        super.paste(sender)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self]) {
            return .copy
        }
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !items.isEmpty else {
            return false
        }
        onDroppedURLs?(items)
        return true
    }

    private func wrapSelection(prefix: String, suffix: String) {
        let range = selectedRange()
        guard let textRange = Range(range, in: string) else { return }
        let selected = String(string[textRange])
        let replacement = "\(prefix)\(selected)\(suffix)"
        insertText(replacement, replacementRange: range)
    }

    private func prefixLineSelection(with prefix: String) {
        let nsText = string as NSString
        let selected = selectedRange()
        let lineRange = nsText.lineRange(for: selected)
        let block = nsText.substring(with: lineRange)
        let updated = block
            .components(separatedBy: .newlines)
            .map { line in
                line.isEmpty ? line : "\(prefix)\(line)"
            }
            .joined(separator: "\n")
        insertText(updated, replacementRange: lineRange)
    }

    private func indentSelection() {
        prefixLineSelection(with: "    ")
    }

    private func unindentSelection() {
        let nsText = string as NSString
        let selected = selectedRange()
        let lineRange = nsText.lineRange(for: selected)
        let block = nsText.substring(with: lineRange)
        let updated = block
            .components(separatedBy: .newlines)
            .map { line in
                if line.hasPrefix("    ") {
                    return String(line.dropFirst(4))
                }
                if line.hasPrefix("\t") {
                    return String(line.dropFirst())
                }
                return line
            }
            .joined(separator: "\n")
        insertText(updated, replacementRange: lineRange)
    }

    private func readPastedFileURLs() -> [URL]? {
        let pasteboard = NSPasteboard.general
        guard let items = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !items.isEmpty else {
            return nil
        }
        return items
    }

    private func readPastedImageData() -> Data? {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .png) {
            return data
        }
        if let data = pasteboard.data(forType: .tiff),
           let image = NSImage(data: data),
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            return pngData
        }
        return nil
    }
}
