import SwiftUI

/// A tile view for displaying folders, decks, exams, or study guides in a grid layout.
struct LibraryGridTileView: View {
    enum Item {
        case folder(Deck)
        case deck(Deck)
        case exam(Exam)
        case studyGuide(StudyGuide)

        var name: String {
            switch self {
            case .folder(let d), .deck(let d):
                return d.name
            case .exam(let e):
                return e.title
            case .studyGuide(let g):
                return g.title
            }
        }

        var isFolder: Bool {
            if case .folder = self { return true }
            return false
        }
        
        var id: UUID {
            switch self {
            case .folder(let d), .deck(let d):
                return d.id
            case .exam(let e):
                return e.id
            case .studyGuide(let g):
                return g.id
            }
        }
    }

    let item: Item
    let cardCount: Int?
    let onTap: () -> Void
    var onRename: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onExport: (() -> Void)? = nil

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Icon row
                HStack {
                    icon
                    Spacer()
                    if item.isFolder {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    }
                }

                // Title
                Text(item.name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Metadata
                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .fill(isHovered ? DesignSystem.Colors.hoverBackground : DesignSystem.Colors.subtleOverlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.separator.opacity(isHovered ? 0.8 : 0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .designSystemContextMenu {
            if let onRename = onRename {
                ContextMenuItem(icon: "pencil", label: "Rename", action: onRename)
            }
            
            if let onDuplicate = onDuplicate {
                ContextMenuItem(icon: "doc.on.doc", label: "Duplicate", action: onDuplicate)
            }
            
            if onRename != nil || onDuplicate != nil {
                ContextMenuDivider()
            }
            
            if let onExport = onExport {
                ContextMenuItem(icon: "arrow.up.doc", label: "Export", action: onExport)
            }
            
            if let onDelete = onDelete {
                if onExport != nil {
                    ContextMenuDivider()
                }
                ContextMenuItem(icon: "trash", label: "Delete", isDestructive: true, action: onDelete)
            }
        }
    }

    private var icon: some View {
        Group {
            switch item {
            case .folder:
                Image(systemName: "folder.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.accent)

            case .deck:
                // Deck icon with card stack visual
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.accent.opacity(0.15))
                        .frame(width: 28, height: 32)
                        .offset(x: 2, y: -2)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.accent.opacity(0.3))
                        .frame(width: 28, height: 32)
                        .offset(x: 1, y: -1)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: 28, height: 32)
                }

            case .exam:
                Image(systemName: "doc.questionmark.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.orange)

            case .studyGuide:
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.purple)
            }
        }
    }

    private var subtitleText: String? {
        switch item {
        case .folder:
            return nil  // Folders don't show metadata
        case .deck:
            guard let count = cardCount else { return nil }
            return "\(count) card\(count == 1 ? "" : "s")"
        case .exam(let exam):
            let count = exam.questions.count
            return "\(count) question\(count == 1 ? "" : "s")"
        case .studyGuide(let guide):
            let wordCount = guide.markdownContent.split(whereSeparator: \.isWhitespace).count
            let attachmentCount = guide.attachments.count
            let tagCount = guide.tags.count
            if wordCount == 0 && attachmentCount == 0 && tagCount == 0 {
                return "Empty"
            }

            var parts: [String] = []
            if wordCount > 0 {
                parts.append("\(wordCount) words")
            }
            if attachmentCount > 0 {
                parts.append("\(attachmentCount) file\(attachmentCount == 1 ? "" : "s")")
            }
            if tagCount > 0 {
                parts.append("\(tagCount) tag\(tagCount == 1 ? "" : "s")")
            }
            return parts.joined(separator: " • ")
        }
    }
}
