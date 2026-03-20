import SwiftUI

/// Unified session status tray: streak progress + pomodoro timer + save status.
/// Renders as a single ambient capsule with inner dividers.
struct TopBarSessionTray: View {
    // Streak data
    let reviewed: Int
    let due: Int
    let streakDays: Int
    let bestStreak: Int
    let averageSessionSeconds: Double

    // Pomodoro
    @Bindable var pomodoroService: PomodoroService
    @Bindable var soundService: PomodoroSoundService

    // Save status
    let saveStatus: SaveStatusService.Status

    @State private var isStreakPopoverPresented = false
    @State private var isHovered = false
    @State private var showPomodoroPopover = false

    private var progress: Double {
        guard due > 0 else { return reviewed > 0 ? 1.0 : 0.0 }
        return min(Double(reviewed) / Double(due), 1.0)
    }

    private var isReviewComplete: Bool { due > 0 && reviewed >= due }
    private var isStudying: Bool { pomodoroService.isActive }

    var body: some View {
        HStack(spacing: 0) {
            // Streak section
            streakSection

            trayDivider()

            // Pomodoro section
            pomodoroSection

            // Save status (only when visible)
            if saveStatus != .idle {
                trayDivider()
                saveSection
            }
        }
        .frame(height: 26)
        .animation(DesignSystem.Animation.smooth, value: isStudying)
        .animation(DesignSystem.Animation.smooth, value: saveStatus)
        .onChange(of: pomodoroService.phase) { oldPhase, newPhase in
            if oldPhase != .idle && newPhase != .idle {
                soundService.playCompletionSound()
            }
            switch newPhase {
            case .working:
                soundService.startTicking()
            default:
                soundService.stopTicking()
            }
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        Button(action: { isStreakPopoverPresented.toggle() }) {
            HStack(spacing: DesignSystem.Spacing.xxs + 2) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1.5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isReviewComplete
                                ? DesignSystem.Colors.feedbackSuccess
                                : DesignSystem.Colors.studyAccentBright,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    if isReviewComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 5, weight: .bold))
                            .foregroundStyle(DesignSystem.Colors.feedbackSuccess)
                    }
                }
                .frame(width: 14, height: 14)

                Text("\(reviewed)/\(due)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                // Streak flame
                HStack(spacing: 1) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(streakDays > 0 ? .orange : DesignSystem.Colors.tertiaryText.opacity(0.5))
                    Text("\(streakDays)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            streakDays > 0
                                ? DesignSystem.Colors.primaryText
                                : DesignSystem.Colors.tertiaryText
                        )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xs)
        }
        .buttonStyle(.plain)
        .help("Review Progress")
        .popover(isPresented: $isStreakPopoverPresented, arrowEdge: .bottom) {
            streakPopover
        }
    }

    // MARK: - Pomodoro Section

    private var pomodoroSection: some View {
        Button(action: { showPomodoroPopover.toggle() }) {
            Group {
                switch pomodoroService.phase {
                case .idle:
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .frame(width: 26, height: 26)
                case .working:
                    pomodoroActiveLabel(icon: "timer", color: DesignSystem.Colors.studyAccentBright)
                case .shortBreak, .longBreak:
                    pomodoroActiveLabel(icon: "cup.and.saucer.fill", color: DesignSystem.Colors.feedbackSuccess)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Pomodoro Timer")
        .popover(isPresented: $showPomodoroPopover, arrowEdge: .bottom) {
            PomodoroPopoverView(
                pomodoroService: pomodoroService,
                soundService: soundService
            )
        }
    }

    private func pomodoroActiveLabel(icon: String, color: Color) -> some View {
        let minutes = Int(pomodoroService.remaining) / 60
        let seconds = Int(pomodoroService.remaining) % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)

        return HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
            Text(timeString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(
                    pomodoroService.isPaused
                        ? DesignSystem.Colors.tertiaryText
                        : DesignSystem.Colors.primaryText
                )
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
    }

    // MARK: - Save Section

    private var saveSection: some View {
        Group {
            switch saveStatus {
            case .idle:
                EmptyView()
            case .saving:
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                    .symbolEffect(.pulse, options: .repeating)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.Colors.feedbackSuccess)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.Colors.feedbackError)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
            }
        }
    }

    // MARK: - Tray Chrome

    private var trayBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
            .fill(
                isStudying
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.studyAccentBright.opacity(0.06),
                                DesignSystem.Colors.subtleOverlay
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    : AnyShapeStyle(DesignSystem.Colors.subtleOverlay)
            )
    }

    private var trayBorder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
            .strokeBorder(
                isStudying
                    ? DesignSystem.Colors.studyAccentBorder.opacity(0.2)
                    : DesignSystem.Colors.borderOverlay.opacity(0.12),
                lineWidth: 0.5
            )
    }

    private func trayDivider() -> some View {
        Rectangle()
            .fill(DesignSystem.Colors.borderOverlay.opacity(0.2))
            .frame(width: 1, height: 14)
    }

    // MARK: - Streak Popover

    private var streakPopover: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                Text("Today's Progress")
                    .font(DesignSystem.Typography.captionMedium)
            }

            Divider()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                HStack {
                    Text("Reviewed")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Spacer()
                    Text("\(reviewed) of \(due)")
                        .font(DesignSystem.Typography.captionMedium)
                }

                HStack {
                    Text("Streak")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                        Text("\(streakDays) days")
                            .font(DesignSystem.Typography.captionMedium)
                    }
                }

                HStack {
                    Text("Best")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Spacer()
                    Text("\(bestStreak) days")
                        .font(DesignSystem.Typography.captionMedium)
                }

                if averageSessionSeconds > 0 {
                    HStack {
                        Text("Avg. Session")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        Spacer()
                        Text("\(Int(averageSessionSeconds / 60)) min")
                            .font(DesignSystem.Typography.captionMedium)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(width: 200)
    }
}

// MARK: - Simplified Tray (no streak data)

/// Minimal session tray when no streak data is available.
struct TopBarSessionTrayMinimal: View {
    @Bindable var pomodoroService: PomodoroService
    @Bindable var soundService: PomodoroSoundService
    let saveStatus: SaveStatusService.Status

    @State private var showPomodoroPopover = false

    var body: some View {
        HStack(spacing: 0) {
            pomodoroSection

            if saveStatus != .idle {
                trayDivider()
                saveSection
            }
        }
        .frame(height: 26)
        .onChange(of: pomodoroService.phase) { oldPhase, newPhase in
            if oldPhase != .idle && newPhase != .idle {
                soundService.playCompletionSound()
            }
            switch newPhase {
            case .working:
                soundService.startTicking()
            default:
                soundService.stopTicking()
            }
        }
    }

    private var pomodoroSection: some View {
        Button(action: { showPomodoroPopover.toggle() }) {
            Group {
                switch pomodoroService.phase {
                case .idle:
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .frame(width: 26, height: 26)
                case .working:
                    pomodoroActiveLabel(icon: "timer", color: DesignSystem.Colors.studyAccentBright)
                case .shortBreak, .longBreak:
                    pomodoroActiveLabel(icon: "cup.and.saucer.fill", color: DesignSystem.Colors.feedbackSuccess)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Pomodoro Timer")
        .popover(isPresented: $showPomodoroPopover, arrowEdge: .bottom) {
            PomodoroPopoverView(
                pomodoroService: pomodoroService,
                soundService: soundService
            )
        }
    }

    private func pomodoroActiveLabel(icon: String, color: Color) -> some View {
        let minutes = Int(pomodoroService.remaining) / 60
        let seconds = Int(pomodoroService.remaining) % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)

        return HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
            Text(timeString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(
                    pomodoroService.isPaused
                        ? DesignSystem.Colors.tertiaryText
                        : DesignSystem.Colors.primaryText
                )
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
    }

    private var saveSection: some View {
        Group {
            switch saveStatus {
            case .idle:
                EmptyView()
            case .saving:
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(DesignSystem.Colors.studyAccentBright)
                    .symbolEffect(.pulse, options: .repeating)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.Colors.feedbackSuccess)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.Colors.feedbackError)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
            }
        }
    }

    private func trayDivider() -> some View {
        Rectangle()
            .fill(DesignSystem.Colors.borderOverlay.opacity(0.2))
            .frame(width: 1, height: 14)
    }
}
