import SwiftUI

/// Provides the scrollable central canvas surface with unified spacing.
struct WorkspaceCanvas<Content: View>: View {
    private let content: (CGFloat) -> Content

    init(@ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: responsiveSpacing(for: geometry.size.width)) {
                    content(geometry.size.width)
                }
                .padding(.horizontal, responsivePadding(for: geometry.size.width))
                .padding(.vertical, responsivePadding(for: geometry.size.width))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
        }
    }
    
    private func responsivePadding(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<500:
            return DesignSystem.Spacing.md // 16
        case 500..<800:
            return DesignSystem.Spacing.lg // 24
        default:
            return DesignSystem.Spacing.xl // 32
        }
    }
    
    private func responsiveSpacing(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<500:
            return DesignSystem.Spacing.lg // 24
        default:
            return DesignSystem.Spacing.xl // 32
        }
    }
}

/// Shared block styling used within the workspace canvas.
struct CanvasBlock<Content: View>: View {
    private let title: String?
    private let subtitle: String?
    private let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            if let title {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .font(DesignSystem.Typography.heading)
                        .foregroundStyle(.primary)
                    
                    if let subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            content
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .shadow(
            color: Color(light: Color.black.opacity(0.03), dark: Color.black.opacity(0.3)),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}
