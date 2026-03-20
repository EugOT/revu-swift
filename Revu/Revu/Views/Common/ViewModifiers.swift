import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct HoverEffect: ViewModifier {
    @State private var isHovered = false
    var scale: CGFloat = 1.02
    var lift: CGFloat = 2
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1)
            .shadow(color: Color.black.opacity(isHovered ? 0.05 : 0), radius: isHovered ? 8 : 0, x: 0, y: isHovered ? 4 : 0)
            .offset(y: isHovered ? -lift : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverEffect(scale: CGFloat = 1.02, lift: CGFloat = 2) -> some View {
        modifier(HoverEffect(scale: scale, lift: lift))
    }
}
