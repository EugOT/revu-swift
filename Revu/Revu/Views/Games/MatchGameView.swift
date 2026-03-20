import SwiftUI

struct MatchGameView: View {
    @StateObject private var viewModel: MatchGameViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var particles: [Particle] = []
    private let onDismiss: () -> Void
    
    init(cards: [Card], onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: MatchGameViewModel(cards: cards))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DesignSystem.Colors.canvasBackground
                    .ignoresSafeArea()
                
                // Particle Layer
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
                
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                    
                    if viewModel.gameState == .finished {
                        gameOverView
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        gameGrid(geometry: geometry.size)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                
                // Combo Overlay
                if viewModel.comboStreak > 1 {
                    VStack {
                        Text("\(viewModel.comboStreak)x COMBO!")
                            .font(DesignSystem.Typography.hero)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 0)
                            .scaleEffect(1.2)
                            .rotationEffect(.degrees(Double.random(in: -5...5)))
                            .transition(.scale.combined(with: .opacity))
                            .id("combo-\(viewModel.comboStreak)")
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: viewModel.comboStreak)
                }
            }
            .onChange(of: viewModel.matchedPairs) {
                // Trigger particles on match
                if viewModel.matchedPairs > 0 {
                    spawnParticles(in: geometry.size)
                }
            }
        }
    }
    
    private func spawnParticles(in size: CGSize) {
        // Spawn particles from center
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for _ in 0..<20 {
            let particle = Particle(
                position: center,
                color: [.red, .orange, .yellow, .blue, .purple].randomElement() ?? .white
            )
            particles.append(particle)
        }
        
        // Animate particles
        withAnimation(.easeOut(duration: 1.0)) {
            for i in particles.indices {
                particles[i].position.x += CGFloat.random(in: -100...100)
                particles[i].position.y += CGFloat.random(in: -100...100)
                particles[i].opacity = 0
            }
        }
        
        // Cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            particles.removeAll()
        }
    }
    
    private var header: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(DesignSystem.Colors.hoverBackground, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(viewModel.timeRemaining < 10 ? .red : .secondary)
                        .symbolEffect(.pulse, isActive: viewModel.timeRemaining < 10)
                    
                    Text(formatTime(viewModel.timeRemaining))
                        .font(DesignSystem.Typography.mono)
                        .foregroundStyle(viewModel.timeRemaining < 10 ? Color.red : .primary)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: viewModel.timeRemaining)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.window)
                )
                .overlay(
                    Capsule()
                        .stroke(viewModel.timeRemaining < 10 ? Color.red : DesignSystem.Colors.separator, lineWidth: 1)
                )
                
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(.orange)
                    
                    Text("\(viewModel.score)")
                        .font(DesignSystem.Typography.mono)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(countsDown: false))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.window)
                )
                .overlay(
                    Capsule()
                        .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                )
            }
            
            Spacer()
            
            // Balance the close button
            Color.clear.frame(width: 36, height: 36)
        }
    }
    
    private func gameGrid(geometry: CGSize) -> some View {
        let availableWidth = geometry.width - 48 // Horizontal padding
        let availableHeight = geometry.height - 100 // Header + padding
        
        let isLandscape = availableWidth > availableHeight
        let columnsCount = isLandscape ? 4 : 3
        let rowsCount = isLandscape ? 3 : 4
        
        let gap: CGFloat = 12
        let totalGapWidth = gap * CGFloat(columnsCount - 1)
        let totalGapHeight = gap * CGFloat(rowsCount - 1)
        
        let cardWidth = (availableWidth - totalGapWidth) / CGFloat(columnsCount)
        let cardHeight = (availableHeight - totalGapHeight) / CGFloat(rowsCount)
        
        let columns = Array(repeating: GridItem(.fixed(cardWidth), spacing: gap), count: columnsCount)
        
        return LazyVGrid(columns: columns, spacing: gap) {
            ForEach(Array(viewModel.tiles.enumerated()), id: \.element.id) { index, tile in
                TileView(tile: tile, width: cardWidth, height: cardHeight)
                    .onTapGesture {
                        viewModel.selectTile(at: index)
                    }
                    .opacity(tile.isMatched ? 0 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tile.isMatched)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
    
    private var gameOverView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(viewModel.matchedPairs == viewModel.tiles.count / 2 ? Color.yellow.opacity(0.1) : Color.orange.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: viewModel.matchedPairs == viewModel.tiles.count / 2 ? "trophy.fill" : "clock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(viewModel.matchedPairs == viewModel.tiles.count / 2 ? Color.yellow : Color.orange)
            }
            .scaleEffect(1.1)
            .animation(.spring(response: 0.5, dampingFraction: 0.6).repeatForever(autoreverses: true), value: true)
            
            VStack(spacing: 12) {
                Text(viewModel.matchedPairs == viewModel.tiles.count / 2 ? "All Pairs Matched!" : "Time's Up!")
                    .font(DesignSystem.Typography.hero)
                    .foregroundStyle(.primary)
                
                Text("Final Score: \(viewModel.score)")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        let fraction = Int((time - Double(seconds)) * 10)
        return String(format: "%02d.%d", seconds, fraction)
    }
}

struct TileView: View {
    let tile: MatchGameViewModel.Tile
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundColor)
                .shadow(
                    color: shadowColor,
                    radius: tile.isSelected ? 12 : 4,
                    x: 0,
                    y: tile.isSelected ? 6 : 2
                )
            
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
            
            Text(tile.content)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .padding(12)
                .minimumScaleFactor(0.4)
        }
        .frame(width: width, height: height)
        .scaleEffect(tile.isSelected ? 1.05 : 1.0)
        .rotation3DEffect(
            .degrees(tile.isSelected ? 10 : 0),
            axis: (x: 1.0, y: 0.0, z: 0.0)
        )
        .offset(x: tile.isError ? -5 : 0)
        .animation(tile.isError ? .default.repeatCount(3).speed(4) : .spring(response: 0.3, dampingFraction: 0.7), value: tile.isError)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: tile.isSelected)
    }
    
    private var backgroundColor: Color {
        if tile.isError { return Color.red.opacity(0.08) }
        if tile.isSelected { return Color.accentColor.opacity(0.08) }
        return DesignSystem.Colors.window
    }
    
    private var borderColor: Color {
        if tile.isError { return Color.red.opacity(0.6) }
        if tile.isSelected { return Color.accentColor }
        return DesignSystem.Colors.separator.opacity(0.6)
    }
    
    private var borderWidth: CGFloat {
        if tile.isSelected || tile.isError { return 2 }
        return 1
    }
    
    private var textColor: Color {
        if tile.isError { return .red }
        if tile.isSelected { return .accentColor }
        return .primary
    }
    
    private var shadowColor: Color {
        if tile.isError { return Color.red.opacity(0.2) }
        if tile.isSelected { return Color.accentColor.opacity(0.25) }
        return Color.black.opacity(0.05)
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var size: CGFloat = CGFloat.random(in: 4...8)
    var opacity: Double = 1.0
}

#if DEBUG
#Preview("MatchGameView") {
    let cards = [
        Card(kind: .basic, front: "Hola", back: "Hello"),
        Card(kind: .basic, front: "Merci", back: "Thank you"),
        Card(kind: .basic, front: "Ciao", back: "Hi"),
        Card(kind: .basic, front: "Danke", back: "Thanks"),
        Card(kind: .basic, front: "Oui", back: "Yes"),
        Card(kind: .basic, front: "Non", back: "No"),
    ]
    return MatchGameView(cards: cards, onDismiss: {})
        .frame(width: 980, height: 720)
}
#endif
