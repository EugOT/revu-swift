import SwiftUI
#if os(iOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif

/// Centralized design tokens used to steer the Notion-inspired workspace refresh.
enum DesignSystem {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        /// Modern card radius — slightly larger for grid cards
        static let card: CGFloat = 14
    }
    
    enum Typography {
        /// Extra large display style used for prominent headings (scales with `.largeTitle`)
        static var hero: Font {
            Font.system(.largeTitle, design: .default).weight(.bold)
        }

        /// Primary title style (scales with `.title`)
        static var title: Font {
            Font.system(.title, design: .default).weight(.semibold)
        }

        /// Secondary title style (scales with `.title2`)
        static var heading: Font {
            Font.system(.title2, design: .default).weight(.semibold)
        }

        /// Subheading style for section titles (scales with `.title3`)
        static var subheading: Font {
            Font.system(.title3, design: .default).weight(.medium)
        }

        /// Default body text (scales with `.body`)
        static var body: Font {
            Font.system(.body, design: .default)
        }

        /// Medium-weight body text (scales with `.body`)
        static var bodyMedium: Font {
            Font.system(.body, design: .default).weight(.medium)
        }

        /// Caption text for supplemental information (scales with `.caption1`)
        static var caption: Font {
            Font.system(.caption, design: .default)
        }

        /// Medium-weight caption (scales with `.caption1`)
        static var captionMedium: Font {
            Font.system(.caption, design: .default).weight(.medium)
        }

        /// Small supplemental text (scales with `.footnote`)
        static var small: Font {
            Font.system(.footnote, design: .default)
        }

        /// Medium-weight variant of the small supplemental text (scales with `.footnote`)
        static var smallMedium: Font {
            Font.system(.footnote, design: .default).weight(.medium)
        }

        /// Monospaced body font for timers and code snippets (scales with `.body`)
        static var mono: Font {
            Font.system(.body, design: .monospaced).weight(.medium)
        }
    }

    enum Colors {
        // Notion-inspired adaptive color palette
        // Light mode: warm off-whites and subtle grays
        // Dark mode: true blacks with proper contrast ratios for WCAG AA compliance
        
        // Main background - the canvas where content lives
        static var canvasBackground: Color {
            Color(light: Color(hex: "F8F9FB"), dark: Color(hex: "0D0D0D"))
        }
        
        // Sidebar background - slightly recessed from canvas
        static var sidebarBackground: Color {
            Color(light: Color(hex: "F0F1F3"), dark: Color(hex: "1A1A1A"))
        }
        
        // Window/card background - elevated surfaces
        static var window: Color {
            Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1E1E1E"))
        }
        
        // Inspector/panel background
        static var inspectorBackground: Color {
            Color(light: Color(hex: "F0F1F3"), dark: Color(hex: "141414"))
        }

        // Top bar background (thin, solid — no liquid glass)
        static var topBarBackground: Color {
            Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "121315"))
        }
        
        // Hover/interactive surface
        static var hoverBackground: Color {
            Color(light: Color(hex: "E8EAED"), dark: Color(hex: "2A2A2A"))
        }
        
        // Pressed state background (slightly darker than hover)
        static var pressedBackground: Color {
            Color(light: Color(hex: "DCDFE3"), dark: Color(hex: "242424"))
        }
        
        // Selected state background (subtle accent tint)
        static var selectedBackground: Color {
            Color.accentColor.opacity(0.1)
        }
        
        // Separator lines - higher contrast for better definition
        static var separator: Color {
            Color(light: Color(hex: "C9CDD2"), dark: Color(hex: "404040"))
        }
        
        // Text colors with proper contrast ratios (WCAG AA compliant)
        static var primaryText: Color {
            Color(light: Color(hex: "11181C"), dark: Color(hex: "EFEFEF"))
        }
        
        static var secondaryText: Color {
            Color(light: Color(hex: "687076"), dark: Color(hex: "A0A0A0"))
        }
        
        static var tertiaryText: Color {
            Color(light: Color(hex: "7E868C"), dark: Color(hex: "707070"))
        }
        
        // Accent color
        static let accent = studyAccentBright

        // Deck study accent palette (dark emerald, used sparingly for progress + primary study CTA)
        static var studyAccentDeep: Color {
            Color(light: Color(hex: "084639"), dark: Color(hex: "082F29"))
        }

        static var studyAccentMid: Color {
            Color(light: Color(hex: "0A6550"), dark: Color(hex: "0C5E4A"))
        }

        static var studyAccentBright: Color {
            Color(light: Color(hex: "12996F"), dark: Color(hex: "1FC397"))
        }

        static var studyAccentBorder: Color {
            Color(light: Color(hex: "31A98A").opacity(0.62), dark: Color(hex: "31A98A").opacity(0.82))
        }

        static var studyAccentGlow: Color {
            Color(light: Color(hex: "159070"), dark: Color(hex: "179D79"))
        }

        // Flashcard surface — elevated card, clearly lifted from canvas
        static var flashcardSurface: Color {
            Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "#2E2E2E"))
        }

        // Flashcard border — crisp edge definition
        static var flashcardBorder: Color {
            Color(light: Color(hex: "D8DAE0"), dark: Color(hex: "2E2E2E"))
        }

        // Flashcard footer — recessed bottom band
        static var flashcardFooter: Color {
            Color(light: Color(hex: "F3F4F6"), dark: Color(hex: "2E2E2E"))
        }

        // Flashcard inner divider — subtle rule line
        static var flashcardDivider: Color {
            Color(light: Color(hex: "E2E4E9"), dark: Color(hex: "484848"))
        }

        // Semantic feedback colors
        static var feedbackSuccess: Color {
            Color(light: Color(hex: "2E8B72"), dark: Color(hex: "57D2B4"))
        }

        static var feedbackError: Color {
            Color(light: Color(hex: "C25C47"), dark: Color(hex: "E68F7A"))
        }

        static var feedbackWarning: Color {
            Color(light: Color(hex: "C2850F"), dark: Color(hex: "F0B847"))
        }

        static var feedbackInfo: Color {
            Color(light: Color(hex: "3B7DD8"), dark: Color(hex: "6BA6F0"))
        }

        /// Maps a 0–1 score to error → warning → success
        static func scoreColor(for value: Double) -> Color {
            if value < 0.4 { return feedbackError }
            if value < 0.7 { return feedbackWarning }
            return feedbackSuccess
        }

        // Distinct bottom band for deck cards.
        static var cardProgressSectionBackground: Color {
            Color(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.05))
        }

        static var cardProgressTrack: Color {
            Color(light: Color.black.opacity(0.11), dark: Color.white.opacity(0.11))
        }
        
        // Subtle background overlays for badges, tags, and UI elements
        static var subtleOverlay: Color {
            Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.1))
        }
        
        static var prominentOverlay: Color {
            Color(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.12))
        }
        
        static var lightOverlay: Color {
            Color(light: Color.black.opacity(0.03), dark: Color.white.opacity(0.05))
        }
        
        static var mediumOverlay: Color {
            Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.06))
        }
        
        // Border overlay for better definition
        static var borderOverlay: Color {
            Color(light: Color.black.opacity(0.10), dark: Color.white.opacity(0.15))
        }
        
	        // Legacy names for compatibility
	        static var primaryBackground: Color { canvasBackground }
	        static var secondaryBackground: Color { sidebarBackground }
	        static var groupedBackground: Color { sidebarBackground }
	        static var groupedSecondaryBackground: Color { window }
	        static var groupedTertiaryBackground: Color { hoverBackground }
	        static var border: Color { borderOverlay }
	    }

    enum Gradients {
        static var studyAccent: LinearGradient {
            LinearGradient(
                colors: [
                    DesignSystem.Colors.studyAccentDeep,
                    DesignSystem.Colors.studyAccentMid,
                    DesignSystem.Colors.studyAccentBright
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        // Softer variant used on dense surfaces (e.g. card grid bars) to avoid harsh contrast.
        static var studyAccentSoft: LinearGradient {
            LinearGradient(
                colors: [
                    DesignSystem.Colors.studyAccentMid.opacity(0.78),
                    DesignSystem.Colors.studyAccentBright.opacity(0.92)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        static var studyAccentDiagonal: LinearGradient {
            LinearGradient(
                colors: [
                    DesignSystem.Colors.studyAccentDeep,
                    DesignSystem.Colors.studyAccentMid,
                    DesignSystem.Colors.studyAccentBright
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    enum Animation {
        static let layout = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.85)
        static let quick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.88)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.22)
        static let snappy = SwiftUI.Animation.spring(response: 0.18, dampingFraction: 0.90)
        static let ambientPulse = SwiftUI.Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)
        static let ambientSweep = SwiftUI.Animation.linear(duration: 2.5).repeatForever(autoreverses: false)
        /// Card elevation transition (120ms ease-out)
        static let elevation = SwiftUI.Animation.easeOut(duration: 0.12)
        /// Spring-based card flip
        static let cardFlip = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.78)
    }
    
    enum Shadow {
        static func card(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            colorScheme == .dark
                ? (Color.black.opacity(0.5), 16, 0, 6)
                : (Color.black.opacity(0.08), 12, 0, 4)
        }
        
        static func elevated(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            colorScheme == .dark
                ? (Color.black.opacity(0.6), 24, 0, 12)
                : (Color.black.opacity(0.10), 20, 0, 8)
        }
        
        static func subtle(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            colorScheme == .dark
                ? (Color.black.opacity(0.4), 8, 0, 2)
                : (Color.black.opacity(0.05), 6, 0, 2)
        }
    }
}

// MARK: - Color Helpers

extension Color {
    /// Creates a color that adapts to light and dark mode
    init(light: Color, dark: Color) {
        #if os(iOS) || os(tvOS)
        self.init(uiColor: UIColor(light: UIColor(light), dark: UIColor(dark)))
        #else
        self.init(nsColor: NSColor(light: NSColor(light), dark: NSColor(dark)))
        #endif
    }
    
    /// Creates a color from a hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

#if os(iOS) || os(tvOS)
extension UIColor {
    convenience init(light: UIColor, dark: UIColor) {
        self.init { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return dark
            default:
                return light
            }
        }
    }
}
#else
extension NSColor {
    convenience init(light: NSColor, dark: NSColor) {
        self.init(name: nil) { appearance in
            let appearanceName = appearance.bestMatch(from: [.aqua, .darkAqua])
            return appearanceName == .darkAqua ? dark : light
        }
    }
}
#endif

extension View {
    /// Applies the shared sidebar surface styling.
    func workspaceSidebarSurface() -> some View {
        background(DesignSystem.Colors.sidebarBackground)
    }

    /// Applies the shared canvas surface styling.
    func workspaceCanvasSurface() -> some View {
        background(DesignSystem.Colors.window)
    }

    /// Applies the shared inspector surface styling.
    func workspaceInspectorSurface() -> some View {
        background(DesignSystem.Colors.inspectorBackground)
    }

    /// Rounds corners according to the default medium radius.
    func workspaceCardStyle() -> some View {
        clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .shadow(
                color: Color(light: Color.black.opacity(0.04), dark: Color.black.opacity(0.5)),
                radius: 12,
                x: 0,
                y: 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .strokeBorder(
                        Color(light: Color.clear, dark: Color.white.opacity(0.05)),
                        lineWidth: 1
                    )
            )
    }
    
    /// Applies a primary button style with accent color
    func primaryButtonStyle() -> some View {
        self
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(Color.accentColor)
            )
            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    func destructiveButtonStyle() -> some View {
        self
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(Color.red)
            )
            .shadow(color: Color.red.opacity(0.25), radius: 8, x: 0, y: 4)
    }
    
    /// Applies a secondary button style
    func secondaryButtonStyle() -> some View {
        self
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundStyle(.primary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(DesignSystem.Colors.hoverBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
    }
    
    /// Applies a ghost button style
    func ghostButtonStyle() -> some View {
        self
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    /// Applies an icon button style
    func iconButtonStyle(size: CGFloat = 32) -> some View {
        self
            .frame(width: size, height: size)
            .background(DesignSystem.Colors.hoverBackground, in: Circle())
            .overlay(
                Circle()
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
    }
    
    /// Applies a badge style
    func badgeStyle(color: Color = DesignSystem.Colors.subtleOverlay) -> some View {
        self
            .font(DesignSystem.Typography.captionMedium)
            .foregroundStyle(.primary)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(color, in: Capsule())
    }
    
    /// Session item card chrome: xxl radius, window fill, separator stroke, card shadow.
    func sessionItemCardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xxl, style: .continuous)
                    .fill(DesignSystem.Colors.window)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xxl, style: .continuous)
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
            .shadow(
                color: Color(light: Color.black.opacity(0.04), dark: Color.black.opacity(0.5)),
                radius: 20,
                x: 0,
                y: 8
            )
    }

    /// Keyboard hint badge style: mono text, lightOverlay bg, separator border
    func keyboardHintStyle() -> some View {
        self
            .font(.system(.caption2, design: .monospaced).weight(.medium))
            .foregroundStyle(DesignSystem.Colors.tertiaryText)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xs, style: .continuous)
                    .fill(DesignSystem.Colors.lightOverlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xs, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
            )
    }

    /// Applies a metric card style
    func metricCardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .fill(DesignSystem.Colors.window)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
    }
}
