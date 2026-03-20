import SwiftUI

/// Scales a CGFloat using the current Dynamic Type size while preserving DesignSystem baselines.
@propertyWrapper
struct DesignSystemScaledMetric: DynamicProperty {
    @ScaledMetric private var scaledValue: CGFloat

    var wrappedValue: CGFloat {
        scaledValue
    }

    init(wrappedValue: CGFloat, relativeTo textStyle: Font.TextStyle = .body) {
        _scaledValue = ScaledMetric(wrappedValue: wrappedValue, relativeTo: textStyle)
    }
}

private struct DynamicPaddingModifier: ViewModifier {
    @ScaledMetric private var value: CGFloat
    private let edges: Edge.Set

    init(edges: Edge.Set, base: CGFloat, relativeTo textStyle: Font.TextStyle) {
        self.edges = edges
        _value = ScaledMetric(wrappedValue: base, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        content.padding(edges, value)
    }
}

extension View {
    /// Applies padding that scales automatically with Dynamic Type changes.
    func dynamicPadding(_ edges: Edge.Set = .all,
                        base: CGFloat,
                        relativeTo textStyle: Font.TextStyle = .body) -> some View {
        modifier(DynamicPaddingModifier(edges: edges, base: base, relativeTo: textStyle))
    }
}

private struct DynamicSystemFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo textStyle: Font.TextStyle) {
        self.weight = weight
        self.design = design
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }
}

extension View {
    /// Applies a system font that scales with Dynamic Type while preserving weight and design.
    func dynamicSystemFont(size: CGFloat,
                           weight: Font.Weight = .regular,
                           design: Font.Design = .default,
                           relativeTo textStyle: Font.TextStyle = .body) -> some View {
        modifier(DynamicSystemFontModifier(size: size, weight: weight, design: design, relativeTo: textStyle))
    }
}

extension DynamicTypeSize {
    /// Multiplier to scale spacing and layout metrics in line with Dynamic Type.
    var designSystemSpacingMultiplier: CGFloat {
        switch self {
        case .xSmall:
            return 0.88
        case .small:
            return 0.93
        case .medium:
            return 0.97
        case .large:
            return 1.0
        case .xLarge:
            return 1.05
        case .xxLarge:
            return 1.12
        case .xxxLarge:
            return 1.2
        case .accessibility1:
            return 1.28
        case .accessibility2:
            return 1.36
        case .accessibility3:
            return 1.44
        case .accessibility4:
            return 1.52
        case .accessibility5:
            return 1.6
        @unknown default:
            return 1.2
        }
    }

    /// Indicates when the user has opted into accessibility-focused Dynamic Type sizes.
    var isAccessibilityCategory: Bool {
        switch self {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }
}
