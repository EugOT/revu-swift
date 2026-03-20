import SwiftUI

// MARK: - Button Components

/// Primary action button with accent color and shadow
struct PrimaryButton<Label: View>: View {
    let action: () -> Void
    let label: Label
    
    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }
    
    var body: some View {
        Button(action: action) {
            label
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(Color.accentColor)
                )
                .shadow(color: Color.accentColor.opacity(0.3), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

/// Secondary button with subtle background
struct SecondaryButton<Label: View>: View {
    let action: () -> Void
    let label: Label
    
    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }
    
    var body: some View {
        Button(action: action) {
            label
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
        .buttonStyle(.plain)
    }
}

/// Icon button for toolbar actions
struct IconButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    
    init(_ icon: String, size: CGFloat = 32, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .background(DesignSystem.Colors.hoverBackground, in: Circle())
                .overlay(
                    Circle()
                        .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Components

/// Stat card for displaying metrics
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(color)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(color.opacity(0.12))
                    )
                
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            Text(value)
                .dynamicSystemFont(size: 28, weight: .bold, design: .rounded, relativeTo: .title)
                .foregroundStyle(.primary)
        }
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
        .shadow(
            color: DesignSystem.Shadow.subtle(for: colorScheme).color,
            radius: DesignSystem.Shadow.subtle(for: colorScheme).radius,
            x: DesignSystem.Shadow.subtle(for: colorScheme).x,
            y: DesignSystem.Shadow.subtle(for: colorScheme).y
        )
    }
}

/// Info card for displaying information with icon
struct InfoCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
    
    init(icon: String, title: String, subtitle: String? = nil, color: Color = .accentColor) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .dynamicSystemFont(size: 24, weight: .semibold, relativeTo: .title2)
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(color.opacity(0.12))
                )
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
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

// MARK: - Badge Components

/// Status badge for displaying state
struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.smallMedium)
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
}

/// Tag badge for displaying tags
struct TagBadge: View {
    let tag: String
    
    var body: some View {
        Text("#\(tag)")
            .font(DesignSystem.Typography.captionMedium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.subtleOverlay)
            )
    }
}

// MARK: - Section Components

/// Section header with title and optional action
struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionLabel: String?
    
    init(
        _ title: String,
        subtitle: String? = nil,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.actionLabel = actionLabel
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(title)
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(.primary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if let action, let actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Divider with label
struct LabeledDivider: View {
    let label: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Rectangle()
                .fill(DesignSystem.Colors.separator)
                .frame(height: 1)
            
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Rectangle()
                .fill(DesignSystem.Colors.separator)
                .frame(height: 1)
        }
    }
}

// MARK: - Empty State Component

/// Empty state view with icon and message
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionLabel: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .dynamicSystemFont(size: 48, weight: .light, relativeTo: .largeTitle)
                .foregroundStyle(.tertiary)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(.primary)
                
                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionLabel, let action {
                PrimaryButton(action: action) {
                    Text(actionLabel)
                }
            }
        }
        .padding(DesignSystem.Spacing.xxl)
        .frame(maxWidth: 480)
    }
}

// MARK: - Design System Text Field

/// Custom text field with focus ring, hover state, and design system styling.
/// Mirrors the DeckTextField pattern but is reusable across the app.
struct DesignSystemTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int> = 1...1

    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .lineLimit(lineLimit)
            .textFieldStyle(.plain)
            .font(DesignSystem.Typography.body)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(isFocused ? DesignSystem.Colors.window : DesignSystem.Colors.hoverBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(
                        isFocused ? DesignSystem.Colors.primaryText.opacity(0.25) : (isHovered ? DesignSystem.Colors.separator : .clear),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .focused($isFocused)
            .onHover { isHovered = $0 }
            .animation(DesignSystem.Animation.quick, value: isFocused)
            .animation(DesignSystem.Animation.quick, value: isHovered)
    }
}

// MARK: - Design System Secure Field

/// Custom secure field with the same styling as DesignSystemTextField.
struct DesignSystemSecureField: View {
    let placeholder: String
    @Binding var text: String

    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        SecureField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(DesignSystem.Typography.body)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(isFocused ? DesignSystem.Colors.window : DesignSystem.Colors.hoverBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(
                        isFocused ? DesignSystem.Colors.primaryText.opacity(0.25) : (isHovered ? DesignSystem.Colors.separator : .clear),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .focused($isFocused)
            .onHover { isHovered = $0 }
            .animation(DesignSystem.Animation.quick, value: isFocused)
            .animation(DesignSystem.Animation.quick, value: isHovered)
    }
}

// MARK: - Design System Toggle

/// Custom switch toggle with emerald accent when on.
struct DesignSystemToggle: View {
    @Binding var isOn: Bool

    @State private var isHovered = false
    private let trackWidth: CGFloat = 40
    private let trackHeight: CGFloat = 22
    private let knobSize: CGFloat = 18
    private let knobPadding: CGFloat = 2

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? DesignSystem.Colors.studyAccentMid : DesignSystem.Colors.hoverBackground)
                    .overlay(
                        Capsule()
                            .stroke(isOn ? DesignSystem.Colors.studyAccentBorder.opacity(0.5) : DesignSystem.Colors.separator, lineWidth: 1)
                    )
                    .frame(width: trackWidth, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .padding(knobPadding)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Design System Segmented Picker

/// Custom segmented control using design system styling with a sliding selection indicator.
struct DesignSystemSegmentedPicker<SelectionValue: Hashable>: View {
    @Binding var selection: SelectionValue
    let items: [DesignSystemSegment<SelectionValue>]

    @Namespace private var segmentNamespace
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let isSelected = selection == item.value
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        selection = item.value
                    }
                } label: {
                    Text(item.label)
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(isSelected ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                    .fill(DesignSystem.Colors.window)
                                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.1), radius: 2, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "segment", in: segmentNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.canvasBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
        )
    }
}

/// A single segment item for DesignSystemSegmentedPicker.
struct DesignSystemSegment<Value: Hashable>: Identifiable {
    let id = UUID()
    let label: String
    let value: Value
}

// MARK: - Design System Slider

/// Custom slider with emerald gradient fill track and a white thumb.
struct DesignSystemSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var step: Double? = nil

    @State private var isDragging = false
    private let trackHeight: CGFloat = 6
    private let thumbSize: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let clampedFraction = min(max(fraction, 0), 1)
            let thumbX = clampedFraction * (trackWidth - thumbSize)

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(DesignSystem.Colors.hoverBackground)
                    .frame(height: trackHeight)
                    .overlay(
                        Capsule()
                            .stroke(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
                    )

                // Filled track
                Capsule()
                    .fill(DesignSystem.Gradients.studyAccentSoft)
                    .frame(width: max(trackHeight, thumbX + thumbSize / 2), height: trackHeight)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .scaleEffect(isDragging ? 1.15 : 1.0)
                    .offset(x: thumbX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                let newFraction = gesture.location.x / trackWidth
                                let clamped = min(max(newFraction, 0), 1)
                                var newValue = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                                if let step {
                                    newValue = (newValue / step).rounded() * step
                                }
                                value = min(max(newValue, range.lowerBound), range.upperBound)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .frame(height: thumbSize)
        }
        .frame(height: thumbSize)
        .animation(DesignSystem.Animation.quick, value: isDragging)
    }
}

// MARK: - Search Field Component

/// Enhanced search field with clear button
struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    
    init(_ placeholder: String = "Search...", text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(DesignSystem.Typography.caption)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(DesignSystem.Typography.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
}

// MARK: - Progress Indicator

/// Linear progress indicator with smooth animation
struct ProgressIndicator: View {
    let progress: Double
    let color: Color
    
    init(progress: Double, color: Color = .accentColor) {
        self.progress = progress
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .fill(DesignSystem.Colors.subtleOverlay)
                
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)))
            }
        }
        .frame(height: 6)
        .animation(DesignSystem.Animation.smooth, value: progress)
    }
}

// MARK: - Callout Component

/// Callout box for highlighting information
struct Callout: View {
    enum Style {
        case info, success, warning, error
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }
    
    let style: Style
    let title: String?
    let message: String
    
    init(_ message: String, style: Style = .info, title: String? = nil) {
        self.message = message
        self.style = style
        self.title = title
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: style.icon)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(style.color)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                if let title {
                    Text(title)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(.primary)
                }
                
                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(style.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(style.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Session Stage Badge

/// Capsule badge with icon + uppercase label + tint color used across session item views.
struct SessionStageBadge: View {
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(.caption2, design: .default).weight(.semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(DesignSystem.Typography.smallMedium)
                .foregroundStyle(tint)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs + 1)
        .background(
            Capsule().fill(tint.opacity(0.12))
        )
    }
}

// MARK: - Typing Dots Indicator

/// Animated dots indicator using TimelineView (no Timer leak).
struct TypingDotsIndicator: View {
    private let dotCount = 3
    private let dotSize: CGFloat = 6

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.3)) { timeline in
            let phase = Int(timeline.date.timeIntervalSinceReferenceDate * 3.3) % dotCount
            HStack(spacing: DesignSystem.Spacing.xxs) {
                ForEach(0..<dotCount, id: \.self) { index in
                    Circle()
                        .fill(DesignSystem.Colors.secondaryText)
                        .frame(width: dotSize, height: dotSize)
                        .offset(y: index == phase ? -3 : 0)
                        .animation(DesignSystem.Animation.smooth, value: phase)
                }
            }
        }
    }
}

// MARK: - Score Ring

/// Circular progress ring with score-based coloring.
struct ScoreRing: View {
    let score: Double
    var size: CGFloat = 64
    var lineWidth: CGFloat = 6
    @State private var animatedScore: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Colors.separator.opacity(0.3), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedScore)
                .stroke(
                    DesignSystem.Colors.scoreColor(for: score),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(Int(score * 100))%")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.scoreColor(for: score))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(DesignSystem.Animation.smooth) {
                animatedScore = score
            }
        }
    }
}

#if DEBUG
#Preview("NotionStyleComponents") {
    ScrollView {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            StatCard(title: "Today", value: "24", icon: "checkmark.circle.fill", color: .blue)
            InfoCard(icon: "sparkles", title: "Pro tip", subtitle: "Use markdown + LaTeX in your cards.")
            Callout("This is a warning callout.", style: .warning, title: "Heads up")

            HStack(spacing: DesignSystem.Spacing.md) {
                PrimaryButton(action: {}) { Text("Primary") }
                SecondaryButton(action: {}) { Text("Secondary") }
                IconButton("gearshape") {}
            }
        }
        .padding()
    }
    .frame(width: 560, height: 520)
    .background(DesignSystem.Colors.window)
}
#endif
