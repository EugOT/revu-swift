import SwiftUI

struct PomodoroTimerView: View {
    @Bindable var service: PomodoroService

    private var timeString: String {
        let minutes = Int(service.remaining) / 60
        let seconds = Int(service.remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        Group {
            switch service.phase {
            case .idle:
                idleButton
            case .working:
                activeDisplay(icon: "timer", color: DesignSystem.Colors.accent)
            case .shortBreak, .longBreak:
                activeDisplay(icon: "cup.and.saucer.fill", color: DesignSystem.Colors.feedbackSuccess)
            }
        }
    }

    private var idleButton: some View {
        DesignSystemTopBarIconButton(
            icon: "timer",
            action: {
                service.requestNotificationPermission()
                service.start()
            },
            help: "Start Pomodoro Timer"
        )
    }

    private func activeDisplay(icon: String, color: Color) -> some View {
        Menu {
            if service.isPaused {
                Button("Resume", action: service.resume)
            } else {
                Button("Pause", action: service.pause)
            }
            Button("Skip", action: service.skip)
            Divider()
            Button("Reset", role: .destructive, action: service.reset)
        } label: {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)

                Text(timeString)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(
                        service.isPaused
                            ? DesignSystem.Colors.tertiaryText
                            : DesignSystem.Colors.primaryText
                    )
            }
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .fill(DesignSystem.Colors.subtleOverlay)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(service.isPaused ? "Pomodoro (Paused)" : "Pomodoro Timer")
    }
}
