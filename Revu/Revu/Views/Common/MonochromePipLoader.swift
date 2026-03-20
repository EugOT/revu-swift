import SwiftUI

/// Minimal, satisfying loading indicator with pulsing dots that fits the Arc/Notion monochrome palette.
struct MonochromePipLoader: View {
    @State private var phase: CGFloat = 0

    private let dots = Array(0..<3)

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(dots, id: \.self) { index in
                Circle()
                    .fill(DesignSystem.Colors.primaryText)
                    .frame(width: 10, height: 10)
                    .scaleEffect(scale(for: index))
                    .opacity(opacity(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func scale(for index: Int) -> CGFloat {
        let offset = phase + CGFloat(index) * 0.2
        return 0.8 + 0.4 * sin(offset * .pi)
    }

    private func opacity(for index: Int) -> Double {
        let offset = phase + CGFloat(index) * 0.3
        return 0.5 + 0.5 * Double(sin(offset * .pi))
    }
}

#Preview {
    ZStack {
        DesignSystem.Colors.canvasBackground
            .ignoresSafeArea()
        MonochromePipLoader()
    }
}
