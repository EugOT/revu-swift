import SwiftUI

/// Branded header used throughout the workspace surfaces. Inspired by Notion's calm aesthetic.
struct WorkspaceBrandHeader<Trailing: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let trailing: Trailing
    private let compact: Bool

    init(compact: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.compact = compact
        self.trailing = trailing()
    }

    @ViewBuilder
    private var brandIcon: some View {
        // Explicitly switch based on the environment's color scheme
        // This ensures it responds to app settings, not just system appearance
        Image(colorScheme == .dark ? "BrandMarkDark" : "BrandMarkLight")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
    }

    private var logoContainerBackground: Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.04) 
            : Color.black.opacity(0.02)
    }

    private var logoStrokeColor: Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.12) 
            : Color.black.opacity(0.06)
    }

    private var cardBackground: Color {
        colorScheme == .dark 
            ? DesignSystem.Colors.window.opacity(0.5)
            : DesignSystem.Colors.window.opacity(0.95)
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            // Logo container with subtle glass morphism effect
            ZStack {
                // Soft glow for dark mode
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color.accentColor.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 35
                            )
                        )
                        .frame(width: 56, height: 56)
                }
                
                // Main logo container
                brandIcon
                    .id(colorScheme) // Force re-render when color scheme changes
                    .frame(width: compact ? 32 : 38, height: compact ? 32 : 38)
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                            .fill(logoContainerBackground)
                            .shadow(
                                color: colorScheme == .dark 
                                    ? Color.black.opacity(0.3) 
                                    : Color.black.opacity(0.04),
                                radius: colorScheme == .dark ? 8 : 4,
                                x: 0,
                                y: 2
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        logoStrokeColor,
                                        logoStrokeColor.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }

            if !compact {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Revu")
                        .font(DesignSystem.Typography.subheading)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .tracking(-0.3)

                    Text("A calm space for spaced repetition.")
                        .font(DesignSystem.Typography.small)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            trailing
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(cardBackground)
                .shadow(
                    color: colorScheme == .dark 
                        ? Color.black.opacity(0.4) 
                        : Color.black.opacity(0.03),
                    radius: colorScheme == .dark ? 12 : 6,
                    x: 0,
                    y: colorScheme == .dark ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.borderOverlay.opacity(0.5),
                            DesignSystem.Colors.borderOverlay.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }
}

extension WorkspaceBrandHeader where Trailing == EmptyView {
    init(compact: Bool = false) {
        self.compact = compact
        self.trailing = EmptyView()
    }
}

struct WorkspaceBrandHeader_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WorkspaceBrandHeader()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Light")

            WorkspaceBrandHeader()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
        .padding()
        .background(DesignSystem.Colors.sidebarBackground)
    }
}
