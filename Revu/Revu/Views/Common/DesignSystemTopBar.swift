import SwiftUI

// MARK: - Icon Button

struct DesignSystemTopBarIconButton: View {
    let icon: String
    let action: () -> Void
    let help: String
    let isDisabled: Bool

    @State private var isHovered = false

    init(
        icon: String,
        action: @escaping () -> Void,
        help: String,
        isDisabled: Bool = false
    ) {
        self.icon = icon
        self.action = action
        self.help = help
        self.isDisabled = isDisabled
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    isDisabled
                        ? DesignSystem.Colors.tertiaryText.opacity(0.35)
                        : isHovered
                            ? DesignSystem.Colors.primaryText
                            : DesignSystem.Colors.secondaryText
                )
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                        .fill(isHovered && !isDisabled ? DesignSystem.Colors.lightOverlay : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(help)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.snappy) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Breadcrumb Tab (Page Item)

struct DesignSystemTopBarTab: View {
    let title: String
    let isActive: Bool
    let icon: String?

    @State private var isHovered = false

    init(title: String, isActive: Bool, icon: String? = nil) {
        self.title = title
        self.isActive = isActive
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        isActive
                            ? DesignSystem.Colors.studyAccentBright
                            : DesignSystem.Colors.tertiaryText
                    )
            }

            Text(title)
                .font(isActive ? DesignSystem.Typography.captionMedium : DesignSystem.Typography.caption)
                .foregroundStyle(
                    isActive
                        ? DesignSystem.Colors.primaryText
                        : isHovered
                            ? DesignSystem.Colors.secondaryText
                            : DesignSystem.Colors.tertiaryText
                )
                .lineLimit(1)
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .frame(height: 24)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .fill(
                    isActive
                        ? DesignSystem.Colors.subtleOverlay
                        : isHovered
                            ? DesignSystem.Colors.lightOverlay
                            : Color.clear
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .strokeBorder(
                    isActive ? DesignSystem.Colors.borderOverlay.opacity(0.2) : Color.clear,
                    lineWidth: 0.5
                )
        )
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.snappy) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Quick Find Pill

struct DesignSystemTopBarQuickFindTab: View {
    let action: () -> Void

    @State private var isHovered = false

    private enum Keycap {
        static var horizontalPadding: CGFloat { DesignSystem.Spacing.xs - 2 }
        static var verticalPadding: CGFloat { 1 }
        static var cornerRadius: CGFloat { DesignSystem.Radius.xs }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        isHovered
                            ? DesignSystem.Colors.secondaryText
                            : DesignSystem.Colors.tertiaryText
                    )

                Text("Quick Find")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(
                        isHovered
                            ? DesignSystem.Colors.secondaryText
                            : DesignSystem.Colors.tertiaryText
                    )

                Spacer(minLength: 0)

                Text("\u{2318}K")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText.opacity(0.7))
                    .padding(.horizontal, Keycap.horizontalPadding)
                    .padding(.vertical, Keycap.verticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: Keycap.cornerRadius, style: .continuous)
                            .fill(DesignSystem.Colors.subtleOverlay)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Keycap.cornerRadius, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.borderOverlay.opacity(0.3), lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .frame(height: 26)
            .frame(width: 180, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(
                        isHovered
                            ? DesignSystem.Colors.subtleOverlay
                            : DesignSystem.Colors.lightOverlay
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .strokeBorder(
                        isHovered
                            ? DesignSystem.Colors.borderOverlay.opacity(0.3)
                            : DesignSystem.Colors.borderOverlay.opacity(0.15),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .help("Quick Find (\u{2318}K)")
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.snappy) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Thin Vertical Separator

struct TopBarDivider: View {
    var height: CGFloat = 14

    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.borderOverlay.opacity(0.25))
            .frame(width: 1, height: height)
            .padding(.horizontal, DesignSystem.Spacing.xxs)
    }
}

// MARK: - Action Cluster (shared background for grouped actions)

struct TopBarActionCluster<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 2) {
            content()
        }
        .padding(.horizontal, DesignSystem.Spacing.xxs)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.subtleOverlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(DesignSystem.Colors.borderOverlay.opacity(0.12), lineWidth: 0.5)
        )
    }
}

// MARK: - Center Tabs (kept for backward compatibility)

struct DesignSystemTopBarCenterTabs: View {
    let title: String?
    let onQuickFind: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if let title, !title.isEmpty {
                DesignSystemTopBarTab(title: title, isActive: true)
                    .frame(maxWidth: 420, alignment: .leading)
            }
            DesignSystemTopBarQuickFindTab(action: onQuickFind)
        }
        .padding(.vertical, 0)
    }
}

#if DEBUG
#Preview("DesignSystemTopBarCenterTabs") {
    ZStack {
        DesignSystem.Colors.topBarBackground
        DesignSystemTopBarCenterTabs(title: "Linear Algebra 1", onQuickFind: {})
    }
    .frame(width: 860, height: 36)
}
#endif
