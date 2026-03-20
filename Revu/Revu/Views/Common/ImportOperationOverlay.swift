import SwiftUI

struct ImportOperationOverlayState: Equatable {
    enum Phase: Equatable {
        case importing(progress: Double?)
        case success
        case failure
    }

    var title: String
    var subtitle: String?
    var phase: Phase
}

struct ImportOperationOverlay: View {
    let state: ImportOperationOverlayState

    @State private var isAnimating = false
    @State private var revealSuccess = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .transition(.opacity)

            overlayCard
                .padding(DesignSystem.Spacing.xl)
                .frame(maxWidth: 520)
                .transition(.scale(scale: 0.98).combined(with: .opacity))
        }
        .onAppear {
            isAnimating = true
            if case .success = state.phase {
                revealSuccess = true
            }
        }
        .onChange(of: state.phase) { _, newValue in
            if case .success = newValue {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    revealSuccess = true
                }
            } else {
                revealSuccess = false
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var overlayCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            badge

            VStack(spacing: 6) {
                Text(state.title)
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                if let subtitle = state.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if case .importing(let progress) = state.phase {
                if let progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(Color.accentColor)
                } else {
                    ImportDots()
                        .padding(.top, 2)
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignSystem.Colors.window)
                .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var badge: some View {
        switch state.phase {
        case .importing:
            ImportSpinner(isAnimating: isAnimating)
        case .success:
            AnimatedCheckmark(isRevealed: revealSuccess)
        case .failure:
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.red)
            }
        }
    }
}

private struct ImportSpinner: View {
    let isAnimating: Bool

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.subtleOverlay)
                .frame(width: 64, height: 64)

            Circle()
                .trim(from: 0.08, to: 0.86)
                .stroke(
                    AngularGradient(
                        colors: [
                            DesignSystem.Colors.primaryText.opacity(0.10),
                            DesignSystem.Colors.primaryText.opacity(0.55),
                            DesignSystem.Colors.primaryText.opacity(0.10)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    guard isAnimating else { return }
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        }
        .accessibilityLabel("Importing")
    }
}

private struct ImportDots: View {
    @State private var phase: Int = 0
    @State private var isRunning = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(DesignSystem.Colors.tertiaryText.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == index ? 1.25 : 0.75)
                    .opacity(phase == index ? 1.0 : 0.45)
            }
        }
        .onAppear {
            guard !isRunning else { return }
            isRunning = true
            Task {
                while isRunning {
                    try? await Task.sleep(nanoseconds: 260_000_000)
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            phase = (phase + 1) % 3
                        }
                    }
                }
            }
        }
        .onDisappear {
            isRunning = false
        }
        .accessibilityHidden(true)
    }
}

private struct AnimatedCheckmark: View {
    let isRevealed: Bool

    @State private var drawCircle = false
    @State private var drawCheck = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.12))
                .frame(width: 64, height: 64)

            Circle()
                .trim(from: 0, to: drawCircle ? 1 : 0)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-90))

            CheckmarkShape()
                .trim(from: 0, to: drawCheck ? 1 : 0)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .frame(width: 26, height: 20)
        }
        .scaleEffect(isRevealed ? 1.0 : 0.96)
        .opacity(isRevealed ? 1.0 : 0.0)
        .onAppear {
            guard isRevealed else { return }
            start()
        }
        .onChange(of: isRevealed) { _, newValue in
            if newValue {
                start()
            } else {
                drawCircle = false
                drawCheck = false
            }
        }
        .accessibilityLabel("Import complete")
    }

    private func start() {
        drawCircle = false
        drawCheck = false
        withAnimation(.easeInOut(duration: 0.35)) {
            drawCircle = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.22)) {
            drawCheck = true
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let mid = CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY)
        let end = CGPoint(x: rect.maxX, y: rect.minY)
        path.move(to: start)
        path.addLine(to: mid)
        path.addLine(to: end)
        return path
    }
}

#if DEBUG
#Preview("ImportOperationOverlay – Importing") {
    ImportOperationOverlay(
        state: ImportOperationOverlayState(
            title: "Importing…",
            subtitle: "Validating decks",
            phase: .importing(progress: nil)
        )
    )
}

#Preview("ImportOperationOverlay – Progress") {
    ImportOperationOverlay(
        state: ImportOperationOverlayState(
            title: "Importing…",
            subtitle: "3 of 10 decks",
            phase: .importing(progress: 0.3)
        )
    )
}

#Preview("ImportOperationOverlay – Success") {
    ImportOperationOverlay(
        state: ImportOperationOverlayState(
            title: "Import complete",
            subtitle: "Decks and cards are ready to study.",
            phase: .success
        )
    )
}

#Preview("ImportOperationOverlay – Failure") {
    ImportOperationOverlay(
        state: ImportOperationOverlayState(
            title: "Import failed",
            subtitle: "The file format was not recognized.",
            phase: .failure
        )
    )
}
#endif
