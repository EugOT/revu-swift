import SwiftUI

/// A custom context menu component that matches the app's design system.
/// Provides a refined alternative to macOS default context menus with consistent styling,
/// smooth animations, and semantic color coding.
///
/// Usage:
/// ```swift
/// SomeView()
///     .designSystemContextMenu {
///         ContextMenuItem(icon: "pencil", label: "Rename", action: { ... })
///         ContextMenuItem(icon: "trash", label: "Delete", isDestructive: true, action: { ... })
///     }
/// ```
struct DesignSystemContextMenu<Content: View>: View {
    @Binding var isPresented: Bool
    let anchorPoint: CGPoint
    @ViewBuilder let content: Content
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var menuSize: CGSize = .zero
    @State private var appearAnimation: Bool = false
    
    var body: some View {
        if isPresented {
            ZStack {
                // Invisible backdrop to dismiss on click outside
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissMenu()
                    }
                
                // Menu surface
                menuSurface
                    .position(menuPosition)
                    .opacity(appearAnimation ? 1 : 0)
                    .scaleEffect(appearAnimation ? 1 : 0.92, anchor: .top)
                    .animation(DesignSystem.Animation.snappy, value: appearAnimation)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                appearAnimation = true
            }
        }
    }
    
    private var menuSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        menuSize = geometry.size
                    }
            }
        )
        .background(DesignSystem.Colors.window)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .shadow(
            color: DesignSystem.Shadow.elevated(for: colorScheme).color,
            radius: DesignSystem.Shadow.elevated(for: colorScheme).radius,
            x: DesignSystem.Shadow.elevated(for: colorScheme).x,
            y: DesignSystem.Shadow.elevated(for: colorScheme).y
        )
    }
    
    private var menuPosition: CGPoint {
        // Position menu at anchor point (typically mouse cursor)
        // In a more sophisticated version, this would check screen bounds and adjust positioning
        CGPoint(x: anchorPoint.x + menuSize.width / 2, y: anchorPoint.y + menuSize.height / 2 + 8)
    }
    
    private func dismissMenu() {
        withAnimation(DesignSystem.Animation.quick) {
            appearAnimation = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isPresented = false
        }
    }
}

/// A single item in a DesignSystemContextMenu
struct ContextMenuItem: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                action()
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(itemColor)
                
                Text(label)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(itemColor)
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .frame(minWidth: 180)
            .contentShape(Rectangle())
            .background(itemBackground)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering && !isDisabled
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isDisabled {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
    
    private var itemColor: Color {
        if isDisabled {
            return DesignSystem.Colors.tertiaryText
        }
        if isDestructive {
            return .red
        }
        return DesignSystem.Colors.primaryText
    }
    
    private var itemBackground: Color {
        if isDisabled {
            return .clear
        }
        if isPressed {
            return DesignSystem.Colors.pressedBackground
        }
        if isHovered {
            return DesignSystem.Colors.hoverBackground
        }
        return .clear
    }
}

/// A divider between groups of menu items
struct ContextMenuDivider: View {
    var body: some View {
        Divider()
            .overlay(DesignSystem.Colors.separator)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

// MARK: - View Modifier for Right-Click Context Menu

extension View {
    /// Attaches a design-system context menu that appears on right-click
    func designSystemContextMenu<MenuContent: View>(
        @ViewBuilder items: @escaping () -> MenuContent
    ) -> some View {
        modifier(DesignSystemContextMenuModifier(menuContent: items))
    }
}

private struct DesignSystemContextMenuModifier<MenuContent: View>: ViewModifier {
    @ViewBuilder let menuContent: () -> MenuContent
    
    @State private var isMenuPresented: Bool = false
    @State private var menuAnchorPoint: CGPoint = .zero
    
    func body(content: Content) -> some View {
        content
            .background(
                // Right-click detector using NSView representable
                RightClickDetector { location in
                    showMenu(at: location)
                }
            )
            .overlay {
                // Menu overlay
                if isMenuPresented {
                    GeometryReader { geometry in
                        DesignSystemContextMenu(
                            isPresented: $isMenuPresented,
                            anchorPoint: menuAnchorPoint,
                            content: menuContent
                        )
                    }
                }
            }
    }
    
    private func showMenu(at localPoint: CGPoint) {
        menuAnchorPoint = localPoint
        withAnimation(DesignSystem.Animation.snappy) {
            isMenuPresented = true
        }
    }
}

// MARK: - Right-Click Detection via NSView

#if os(macOS)
import AppKit

private struct RightClickDetector: NSViewRepresentable {
    let onRightClick: (CGPoint) -> Void
    
    func makeNSView(context: Context) -> RightClickNSView {
        let view = RightClickNSView()
        view.onRightClick = onRightClick
        return view
    }
    
    func updateNSView(_ nsView: RightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }
}

private class RightClickNSView: NSView {
    var onRightClick: ((CGPoint) -> Void)?
    
    override func rightMouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        // Convert to SwiftUI coordinate system (origin at top-left)
        let swiftUILocation = CGPoint(x: location.x, y: bounds.height - location.y)
        onRightClick?(swiftUILocation)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
#endif
