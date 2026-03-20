import SwiftUI

/// Unified navigation capsule: sidebar toggle + back/forward arrows in a shared surface.
struct TopBarNavCluster: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let onToggleSidebar: () -> Void
    let onBack: () -> Void
    let onForward: () -> Void

    @State private var hoveredButton: ButtonID?

    private enum ButtonID {
        case sidebar, back, forward
    }

    var body: some View {
        HStack(spacing: 0) {
            clusterButton(
                id: .sidebar,
                icon: "sidebar.leading",
                help: "Toggle Sidebar",
                disabled: false,
                action: onToggleSidebar
            )

            clusterDivider()

            clusterButton(
                id: .back,
                icon: "chevron.left",
                help: "Go Back",
                disabled: !canGoBack,
                action: onBack
            )

            clusterButton(
                id: .forward,
                icon: "chevron.right",
                help: "Go Forward",
                disabled: !canGoForward,
                action: onForward
            )
        }
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.subtleOverlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(DesignSystem.Colors.borderOverlay.opacity(0.18), lineWidth: 0.5)
        )
    }

    private func clusterButton(
        id: ButtonID,
        icon: String,
        help: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    disabled
                        ? DesignSystem.Colors.tertiaryText.opacity(0.35)
                        : hoveredButton == id
                            ? DesignSystem.Colors.primaryText
                            : DesignSystem.Colors.secondaryText
                )
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                        .fill(hoveredButton == id && !disabled ? DesignSystem.Colors.lightOverlay : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.snappy) {
                hoveredButton = hovering ? id : nil
            }
        }
    }

    private func clusterDivider() -> some View {
        Rectangle()
            .fill(DesignSystem.Colors.borderOverlay.opacity(0.25))
            .frame(width: 1, height: 14)
    }
}

#if DEBUG
#Preview("TopBarNavCluster") {
    ZStack {
        DesignSystem.Colors.topBarBackground
        HStack {
            TopBarNavCluster(
                canGoBack: true,
                canGoForward: false,
                onToggleSidebar: {},
                onBack: {},
                onForward: {}
            )
            Spacer()
        }
        .padding()
    }
    .frame(width: 400, height: 44)
}
#endif
