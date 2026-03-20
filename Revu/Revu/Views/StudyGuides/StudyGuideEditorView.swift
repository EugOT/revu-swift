import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct StudyGuideEditorView: View {
    @Environment(\.storage) private var storage
    @EnvironmentObject private var storeEvents: StoreEvents

    let studyGuide: StudyGuide

    @State private var title: String
    @State private var markdownContent: String
    @State private var tagsText: String
    @State private var attachments: [StudyGuideAttachment]
    @State private var mode: EditorMode = .split
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var saveTask: Task<Void, Never>?
    @State private var hasUnsavedChanges = false
    @State private var saveState: SaveState = .idle
    @State private var isOutlineVisible = true
    @State private var isImporterPresented = false

    private static let debounceInterval: TimeInterval = 0.6

    enum EditorMode: String, CaseIterable, Identifiable {
        case edit = "Edit"
        case preview = "Preview"
        case split = "Split"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .edit: return "square.and.pencil"
            case .preview: return "eye"
            case .split: return "rectangle.split.2x1"
            }
        }
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved(Date)
        case failed(String)
    }

    struct OutlineHeading: Identifiable, Hashable {
        let id: UUID
        let level: Int
        let title: String
        let utf16Location: Int
    }

    init(studyGuide: StudyGuide) {
        self.studyGuide = studyGuide
        _title = State(initialValue: studyGuide.title)
        _markdownContent = State(initialValue: studyGuide.markdownContent)
        _tagsText = State(initialValue: studyGuide.tags.joined(separator: ", "))
        _attachments = State(initialValue: studyGuide.attachments)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            attachmentStrip
            Divider()
            content
        }
        .background(DesignSystem.Colors.window)
        .onChange(of: title) { _, _ in scheduleAutosave() }
        .onChange(of: markdownContent) { _, _ in scheduleAutosave() }
        .onChange(of: tagsText) { _, _ in scheduleAutosave() }
        .onChange(of: attachments) { _, _ in scheduleAutosave() }
        .onDisappear { saveImmediately() }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true,
            onCompletion: handleFileImport
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1: Title + save state
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                TextField("Untitled Study Guide", text: $title)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Spacer(minLength: DesignSystem.Spacing.md)

                saveStateLabel
            }
            .padding(.bottom, DesignSystem.Spacing.sm)

            // Row 2: Metadata + controls toolbar
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Metadata pills
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    metadataPill(icon: "doc.text", text: "\(wordCount) words")
                    metadataPill(icon: "clock", text: "\(readingMinutes) min read")
                }

                tagsEditor

                Spacer(minLength: DesignSystem.Spacing.sm)

                // Editor controls group
                HStack(spacing: DesignSystem.Spacing.xs) {
                    // Mode switcher
                    HStack(spacing: 2) {
                        ForEach(EditorMode.allCases) { m in
                            Button {
                                withAnimation(DesignSystem.Animation.quick) {
                                    mode = m
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: m.icon)
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(m.rawValue)
                                        .font(DesignSystem.Typography.captionMedium)
                                }
                                .foregroundStyle(mode == m ? Color.white : DesignSystem.Colors.secondaryText)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                        .fill(mode == m ? DesignSystem.Colors.studyAccentMid : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(2)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .fill(DesignSystem.Colors.hoverBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .stroke(DesignSystem.Colors.separator.opacity(0.6), lineWidth: 1)
                    )

                    // Outline toggle
                    Button {
                        withAnimation(DesignSystem.Animation.layout) {
                            isOutlineVisible.toggle()
                        }
                    } label: {
                        Image(systemName: isOutlineVisible ? "sidebar.leading" : "sidebar.left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isOutlineVisible ? DesignSystem.Colors.studyAccentBright : DesignSystem.Colors.secondaryText)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                                    .fill(isOutlineVisible ? DesignSystem.Colors.studyAccentDeep.opacity(0.14) : DesignSystem.Colors.hoverBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                                    .stroke(isOutlineVisible ? DesignSystem.Colors.studyAccentBorder.opacity(0.5) : DesignSystem.Colors.separator.opacity(0.6), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.top, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    private func metadataPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(DesignSystem.Typography.caption)
        }
        .foregroundStyle(DesignSystem.Colors.tertiaryText)
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, 4)
    }

    private var tagsEditor: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            TextField("Add tags…", text: $tagsText)
                .textFieldStyle(.plain)
                .frame(width: 140)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.hoverBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
        )
    }

    private var saveStateLabel: some View {
        HStack(spacing: 4) {
            switch saveState {
            case .idle:
                if hasUnsavedChanges {
                    Circle()
                        .fill(DesignSystem.Colors.secondaryText.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text("Edited")
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                    Text("Saved")
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
            case .saving:
                ProgressView()
                    .controlSize(.mini)
                Text("Saving")
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            case .saved(let date):
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                Text("Saved \(date.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                Text("Failed")
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
        }
        .font(DesignSystem.Typography.caption)
    }

    @ViewBuilder
    private var attachmentStrip: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(attachments) { attachment in
                        Button {
                            open(attachment: attachment)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: attachment.mimeType.hasPrefix("image/") ? "photo" : "paperclip")
                                Text(attachment.filename)
                                    .lineLimit(1)
                            }
                            .font(DesignSystem.Typography.caption)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(DesignSystem.Colors.subtleOverlay)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(DesignSystem.Colors.separator.opacity(0.7), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        isImporterPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                            .padding(8)
                            .background(Circle().fill(DesignSystem.Colors.studyAccentDeep.opacity(0.14)))
                            .overlay(
                                Circle()
                                    .stroke(DesignSystem.Colors.studyAccentBorder.opacity(0.8), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
            .background(DesignSystem.Colors.subtleOverlay)
        }
    }

    private func proposalPreviewColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title.uppercased())
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            ScrollView {
                Text(text.isEmpty ? "—" : text)
                    .font(DesignSystem.Typography.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(DesignSystem.Colors.window)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var content: some View {
        HStack(spacing: 0) {
            if isOutlineVisible {
                outlinePanel
                Divider()
            }

            switch mode {
            case .edit:
                editorPane
            case .preview:
                previewPane
            case .split:
                HStack(spacing: 0) {
                    editorPane
                    Divider()
                    previewPane
                }
            }
        }
    }

    private var editorPane: some View {
        StudyGuideMarkdownEditorView(
            text: $markdownContent,
            selectedRange: $selectedRange,
            onDropURLs: importDroppedURLs(_:),
            onPasteImageData: importPastedImage(data:filename:)
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.window)
    }

    private var previewPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                if markdownContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No content")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                } else {
                    StudyGuidePreviewView(markdownContent: markdownContent)
                }
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.window)
    }

    private var outlinePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                Text("OUTLINE")
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .tracking(0.6)
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)

            Divider()

            if outlineHeadings.isEmpty {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("No headings")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    Text("Use # to create headings")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DesignSystem.Spacing.md)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(outlineHeadings) { heading in
                            Button {
                                selectedRange = NSRange(location: heading.utf16Location, length: 0)
                            } label: {
                                Text(heading.title)
                                    .lineLimit(1)
                                    .font(heading.level <= 2 ? DesignSystem.Typography.captionMedium : DesignSystem.Typography.caption)
                                    .foregroundStyle(heading.level <= 2 ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                                    .padding(.leading, CGFloat(max(0, heading.level - 1)) * 12)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, DesignSystem.Spacing.xs)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
        }
        .frame(width: 200)
        .background(DesignSystem.Colors.window)
    }

    private var wordCount: Int {
        markdownContent.split(whereSeparator: \.isWhitespace).count
    }

    private var readingMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 220)))
    }

    private var outlineHeadings: [OutlineHeading] {
        var headings: [OutlineHeading] = []
        var utf16Offset = 0
        for line in markdownContent.split(separator: "\n", omittingEmptySubsequences: false) {
            let stringLine = String(line)
            let trimmed = stringLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let level = min(trimmed.prefix(while: { $0 == "#" }).count, 6)
                let title = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    headings.append(
                        OutlineHeading(
                            id: UUID(),
                            level: level,
                            title: title,
                            utf16Location: utf16Offset
                        )
                    )
                }
            }
            utf16Offset += stringLine.utf16.count + 1
        }
        return headings
    }

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func scheduleAutosave() {
        hasUnsavedChanges = true
        saveTask?.cancel()
        saveState = .saving
        saveTask = Task {
            try? await Task.sleep(for: .seconds(Self.debounceInterval))
            guard !Task.isCancelled else { return }
            await performSave()
        }
    }

    private func saveImmediately() {
        saveTask?.cancel()
        Task { await performSave() }
    }

    @MainActor
    private func performSave() async {
        let sameContent =
            title == studyGuide.title &&
            markdownContent == studyGuide.markdownContent &&
            attachments == studyGuide.attachments &&
            parsedTags == studyGuide.tags
        if sameContent {
            hasUnsavedChanges = false
            saveState = .idle
            return
        }

        var updated = studyGuide
        updated.title = title
        updated.markdownContent = markdownContent
        updated.attachments = attachments
        updated.tags = parsedTags
        updated.lastEditedAt = Date()

        do {
            try await storage.upsert(studyGuide: updated.toDTO())
            hasUnsavedChanges = false
            saveState = .saved(Date())
            storeEvents.notify()
        } catch {
            saveState = .failed(error.localizedDescription)
            print("StudyGuideEditorView: Failed to save - \(error)")
        }
    }

    private func importDroppedURLs(_ urls: [URL]) -> [String] {
        let imported = urls.compactMap { importAttachment(from: $0) }
        if !imported.isEmpty {
            attachments.append(contentsOf: imported)
        }
        return imported.map(markdownSnippet(for:))
    }

    private func importPastedImage(data: Data, filename: String) -> String? {
        guard let attachment = importAttachment(data: data, filename: filename, mimeType: "image/png") else { return nil }
        attachments.append(attachment)
        return markdownSnippet(for: attachment)
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        let imported = urls.compactMap { importAttachment(from: $0) }
        if imported.isEmpty { return }
        attachments.append(contentsOf: imported)
        let snippets = imported.map(markdownSnippet(for:)).joined(separator: "\n")
        markdownContent += markdownContent.hasSuffix("\n") || markdownContent.isEmpty ? snippets : "\n\(snippets)"
    }

    private func importAttachment(from url: URL) -> StudyGuideAttachment? {
        do {
            let service = try StudyGuideAttachmentService(storage: storage)
            return try service.importFile(from: url, guideId: studyGuide.id)
        } catch {
            print("StudyGuideEditorView: Failed to import attachment \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    private func importAttachment(data: Data, filename: String, mimeType: String) -> StudyGuideAttachment? {
        do {
            let service = try StudyGuideAttachmentService(storage: storage)
            return try service.save(data: data, filename: filename, mimeType: mimeType, guideId: studyGuide.id)
        } catch {
            print("StudyGuideEditorView: Failed to import pasted image: \(error)")
            return nil
        }
    }

    private func markdownSnippet(for attachment: StudyGuideAttachment) -> String {
        let path = attachment.relativePath.replacingOccurrences(of: " ", with: "%20")
        if attachment.mimeType.hasPrefix("image/") {
            return "![\(attachment.filename)](\(path))"
        }
        return "[\(attachment.filename)](\(path))"
    }

    private func open(attachment: StudyGuideAttachment) {
        do {
            let service = try StudyGuideAttachmentService(storage: storage)
            NSWorkspace.shared.open(service.url(for: attachment))
        } catch {
            print("StudyGuideEditorView: Failed to open attachment \(attachment.filename): \(error)")
        }
    }
}

#if DEBUG
#Preview("StudyGuideEditorView") {
    let guide = StudyGuide(
        title: "Cell Biology Notes",
        markdownContent: """
        # Cell Structure
        ## Organelles
        - **Mitochondria**: Powerhouse of the cell
        - **Nucleus**: Stores DNA
        """
    )
    StudyGuideEditorView(studyGuide: guide)
        .frame(width: 980, height: 700)
        .environmentObject(StoreEvents())
}
#endif
