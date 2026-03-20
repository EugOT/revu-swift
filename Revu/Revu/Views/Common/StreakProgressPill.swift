import SwiftUI

struct StreakProgressPill: View {
    let reviewed: Int
    let due: Int
    let streakDays: Int
    let bestStreak: Int
    let averageSessionSeconds: Double

    @State private var isPopoverPresented = false

    private var progress: Double {
        guard due > 0 else { return reviewed > 0 ? 1.0 : 0.0 }
        return min(Double(reviewed) / Double(due), 1.0)
    }

    private var isComplete: Bool { due > 0 && reviewed >= due }

    var body: some View {
        Button(action: { isPopoverPresented.toggle() }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(DesignSystem.Colors.separator, lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isComplete ? DesignSystem.Colors.feedbackSuccess : DesignSystem.Colors.accent,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(DesignSystem.Colors.feedbackSuccess)
                    }
                }
                .frame(width: 16, height: 16)

                Text("\(reviewed)/\(due)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                // Streak flame
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(streakDays > 0 ? .orange : DesignSystem.Colors.tertiaryText)
                    Text("\(streakDays)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(streakDays > 0 ? DesignSystem.Colors.primaryText : DesignSystem.Colors.tertiaryText)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(DesignSystem.Colors.subtleOverlay)
            )
        }
        .buttonStyle(.plain)
        .help("Review Progress")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            streakPopover
        }
    }

    private var streakPopover: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("\(reviewed) of \(due) cards reviewed today")
                .font(DesignSystem.Typography.smallMedium)
            Text("\(streakDays)-day streak (best: \(bestStreak))")
                .font(DesignSystem.Typography.smallMedium)
            if averageSessionSeconds > 0 {
                let minutes = Int(averageSessionSeconds / 60)
                Text("Average session: \(minutes) min")
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(DesignSystem.Spacing.md)
    }
}
