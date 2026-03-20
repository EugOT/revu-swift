import SwiftUI

/// Expanded pomodoro panel shown as a popover from the top bar.
struct PomodoroPopoverView: View {
    @Bindable var pomodoroService: PomodoroService
    @Bindable var soundService: PomodoroSoundService

    @State private var showDurations = false
    @State private var showSounds = false
    @State private var showHistory = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                settingsSection
            }
        }
        .scrollIndicators(.hidden)
        .frame(width: 340)
        .frame(maxHeight: 560)
        .background(DesignSystem.Colors.window)
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

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack {
            // Phase-aware ambient background tint
            heroBackground

            VStack(spacing: DesignSystem.Spacing.lg) {
                phaseBadge
                timerRing
                sessionDots
                controlsRow
            }
            .padding(.top, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xl)
            .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroBackground: some View {
        ZStack {
            // Soft radial glow behind the timer ring
            RadialGradient(
                colors: [
                    phaseColor.opacity(pomodoroService.isActive ? 0.08 : 0.03),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )

            // Top-edge accent wash
            LinearGradient(
                colors: [
                    phaseColor.opacity(pomodoroService.isActive ? 0.06 : 0.0),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
        .animation(DesignSystem.Animation.smooth, value: pomodoroService.phase)
    }

    private var phaseBadge: some View {
        Text(phaseLabel.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(2.8)
            .foregroundStyle(phaseColor)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(phaseColor.opacity(0.12))
                    .overlay(
                        Capsule()
                            .strokeBorder(phaseColor.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .animation(DesignSystem.Animation.smooth, value: pomodoroService.phase)
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        let totalDuration = currentPhaseTotalDuration
        let progress: Double = totalDuration > 0
            ? 1.0 - (pomodoroService.remaining / totalDuration)
            : 0

        let ringSize: CGFloat = 172
        let ringStroke: CGFloat = 6

        return ZStack {
            // Outer ambient glow ring (only when active)
            if pomodoroService.isActive {
                Circle()
                    .stroke(phaseColor.opacity(0.15), lineWidth: 24)
                    .blur(radius: 16)
                    .frame(width: ringSize, height: ringSize)
            }

            // Track ring
            Circle()
                .stroke(
                    DesignSystem.Colors.subtleOverlay,
                    lineWidth: ringStroke
                )
                .frame(width: ringSize, height: ringSize)

            // Progress arc with gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            phaseColor.opacity(0.5),
                            phaseColor,
                            phaseColor
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: pomodoroService.isActive ? phaseColor.opacity(0.5) : .clear,
                    radius: 12
                )
                .animation(DesignSystem.Animation.smooth, value: pomodoroService.remaining)

            // Progress tip dot
            if progress > 0.02 && pomodoroService.isActive {
                Circle()
                    .fill(phaseColor)
                    .frame(width: ringStroke + 4, height: ringStroke + 4)
                    .shadow(color: phaseColor.opacity(0.6), radius: 6)
                    .offset(y: -(ringSize / 2))
                    .rotationEffect(.degrees(360 * progress))
                    .animation(DesignSystem.Animation.smooth, value: pomodoroService.remaining)
            }

            // Time display
            VStack(spacing: 2) {
                Text(timeString)
                    .font(.system(size: 44, weight: .ultraLight, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .opacity(pomodoroService.isPaused ? 0.5 : 1.0)
                    .animation(DesignSystem.Animation.ambientPulse, value: pomodoroService.isPaused)

                if pomodoroService.isActive {
                    Text(phaseSubtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .transition(.opacity)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - Session Dots

    private var sessionDots: some View {
        let total = pomodoroService.sessionsBeforeLongBreak
        let completed = pomodoroService.completedSessions % total
        let currentIsWork: Bool = {
            if case .working = pomodoroService.phase { return true }
            return false
        }()

        return HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                let isCompleted = index < completed
                let isCurrent = index == completed && currentIsWork

                Circle()
                    .fill(
                        isCompleted
                            ? phaseColor
                            : (isCurrent
                                ? phaseColor.opacity(0.35)
                                : DesignSystem.Colors.subtleOverlay)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                isCurrent ? phaseColor.opacity(0.6) : .clear,
                                lineWidth: 1.5
                            )
                            .scaleEffect(isCurrent ? 1.6 : 1.0)
                            .animation(
                                isCurrent
                                    ? DesignSystem.Animation.ambientPulse
                                    : .default,
                                value: pomodoroService.phase
                            )
                    )
                    .frame(width: 7, height: 7)
                    .shadow(
                        color: isCompleted ? phaseColor.opacity(0.4) : .clear,
                        radius: 3
                    )
            }
        }
        .accessibilityLabel("Session \(completed) of \(total)")
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            if pomodoroService.isActive {
                PomodoroControlButton(
                    icon: "arrow.counterclockwise",
                    size: 36,
                    iconSize: 13,
                    action: pomodoroService.reset
                )
                .accessibilityLabel("Reset timer")

                PomodoroControlButton(
                    icon: pomodoroService.isPaused ? "play.fill" : "pause.fill",
                    size: 52,
                    iconSize: 20,
                    isAccented: true,
                    accentColor: pomodoroService.isRunning ? phaseColor : nil,
                    action: {
                        if pomodoroService.isPaused { pomodoroService.resume() }
                        else { pomodoroService.pause() }
                    }
                )
                .accessibilityLabel(pomodoroService.isPaused ? "Resume timer" : "Pause timer")

                PomodoroControlButton(
                    icon: "forward.fill",
                    size: 36,
                    iconSize: 13,
                    action: pomodoroService.skip
                )
                .accessibilityLabel("Skip to next phase")
            } else {
                PomodoroControlButton(
                    icon: "play.fill",
                    size: 52,
                    iconSize: 20,
                    isAccented: true,
                    accentColor: DesignSystem.Colors.studyAccentBright,
                    action: {
                        pomodoroService.requestNotificationPermission()
                        pomodoroService.start()
                        soundService.startTicking()
                    }
                )
                .accessibilityLabel("Start pomodoro")
            }
        }
        .animation(DesignSystem.Animation.layout, value: pomodoroService.isActive)
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 0) {
            // Separator between hero and settings
            Rectangle()
                .fill(DesignSystem.Colors.borderOverlay.opacity(0.15))
                .frame(height: 0.5)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            settingsRow(title: "Durations", icon: "clock", isExpanded: $showDurations) {
                durationsContent
            }

            settingsRow(title: "Sounds", icon: "speaker.wave.2", isExpanded: $showSounds) {
                soundsContent
            }

            settingsRow(title: "Today", icon: "chart.bar", isExpanded: $showHistory) {
                historyContent
            }

            // Bottom breathing room
            Spacer()
                .frame(height: DesignSystem.Spacing.xs)
        }
    }

    private func settingsRow<Content: View>(
        title: String,
        icon: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DesignSystem.Animation.layout) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isExpanded.wrappedValue ? phaseColor : DesignSystem.Colors.tertiaryText)
                        .frame(width: 18, alignment: .center)

                    Text(title)
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(
                            isExpanded.wrappedValue
                                ? DesignSystem.Colors.primaryText
                                : DesignSystem.Colors.secondaryText
                        )

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(isExpanded.wrappedValue ? .degrees(90) : .zero)
                        .animation(DesignSystem.Animation.snappy, value: isExpanded.wrappedValue)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Inset separator after each row
            Rectangle()
                .fill(DesignSystem.Colors.borderOverlay.opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
    }

    // MARK: - Durations Content

    private var durationsContent: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            durationRow(
                label: "Work",
                value: Binding(
                    get: { pomodoroService.workDuration / 60 },
                    set: { pomodoroService.workDuration = $0 * 60; pomodoroService.saveDurationPreferences() }
                ),
                range: 1...60,
                step: 5
            )
            durationRow(
                label: "Short Break",
                value: Binding(
                    get: { pomodoroService.shortBreakDuration / 60 },
                    set: { pomodoroService.shortBreakDuration = $0 * 60; pomodoroService.saveDurationPreferences() }
                ),
                range: 1...15,
                step: 1
            )
            durationRow(
                label: "Long Break",
                value: Binding(
                    get: { pomodoroService.longBreakDuration / 60 },
                    set: { pomodoroService.longBreakDuration = $0 * 60; pomodoroService.saveDurationPreferences() }
                ),
                range: 5...30,
                step: 5
            )

            HStack {
                Text("Sessions before long break")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Spacer()
                Stepper(
                    "\(pomodoroService.sessionsBeforeLongBreak)",
                    value: Binding(
                        get: { pomodoroService.sessionsBeforeLongBreak },
                        set: { pomodoroService.sessionsBeforeLongBreak = $0; pomodoroService.saveDurationPreferences() }
                    ),
                    in: 2...8
                )
                .font(DesignSystem.Typography.captionMedium)
                .fixedSize()
            }
        }
    }

    private func durationRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .frame(width: 72, alignment: .leading)

            DesignSystemSlider(value: value, range: range, step: step)

            Text("\(Int(value.wrappedValue)) min")
                .font(DesignSystem.Typography.captionMedium)
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .frame(width: 48, alignment: .trailing)
        }
    }

    // MARK: - Sounds Content

    private var soundsContent: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Notifications")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Spacer()
                DesignSystemToggle(isOn: $soundService.notificationsEnabled)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("Completion Sound")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                DesignSystemSegmentedPicker(
                    selection: Binding(
                        get: { soundService.completionSound },
                        set: {
                            soundService.completionSound = $0
                            soundService.previewSound($0)
                        }
                    ),
                    items: PomodoroSoundService.CompletionSound.allCases.map {
                        DesignSystemSegment(label: $0.displayName, value: $0)
                    }
                )
            }

            HStack {
                Text("Focus Ticking")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Spacer()
                DesignSystemToggle(isOn: $soundService.focusTickingEnabled)
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                DesignSystemSlider(value: $soundService.volume, range: 0...1)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
        }
    }

    // MARK: - History Content

    private var historyContent: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            statsRow
            if !pomodoroService.todaySessions.isEmpty {
                miniTimeline
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            statCapsule(
                value: "\(pomodoroService.completedSessions)",
                label: pomodoroService.completedSessions == 1 ? "session" : "sessions"
            )
            statCapsule(
                value: formatDuration(pomodoroService.totalFocusTimeToday),
                label: "focus"
            )
            statCapsule(
                value: "\(pomodoroService.consecutiveCompleted)",
                label: "streak"
            )
        }
    }

    private func statCapsule(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Colors.primaryText)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.borderOverlay.opacity(0.08), lineWidth: 0.5)
                )
        }
    }

    private var miniTimeline: some View {
        let sessions = pomodoroService.todaySessions
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
        guard totalDuration > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            HStack(spacing: 2) {
                ForEach(Array(sessions.enumerated()), id: \.offset) { _, record in
                    let fraction = record.duration / totalDuration
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(timelineColor(for: record.phase))
                        .frame(width: max(6, fraction * 260), height: 8)
                        .shadow(color: timelineColor(for: record.phase).opacity(0.3), radius: 2, y: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignSystem.Spacing.xxs)
        )
    }

    // MARK: - Helpers

    private var timeString: String {
        let minutes = Int(pomodoroService.remaining) / 60
        let seconds = Int(pomodoroService.remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var phaseLabel: String {
        switch pomodoroService.phase {
        case .idle: return "Ready"
        case .working: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    private var phaseSubtitle: String {
        switch pomodoroService.phase {
        case .idle: return ""
        case .working: return "Stay focused"
        case .shortBreak: return "Take a breather"
        case .longBreak: return "You earned this"
        }
    }

    private var phaseColor: Color {
        switch pomodoroService.phase {
        case .idle: return DesignSystem.Colors.secondaryText
        case .working: return DesignSystem.Colors.studyAccentBright
        case .shortBreak: return DesignSystem.Colors.feedbackSuccess
        case .longBreak: return DesignSystem.Colors.feedbackInfo
        }
    }

    private var currentPhaseTotalDuration: TimeInterval {
        switch pomodoroService.phase {
        case .idle: return 0
        case .working: return pomodoroService.workDuration
        case .shortBreak: return pomodoroService.shortBreakDuration
        case .longBreak: return pomodoroService.longBreakDuration
        }
    }

    private func timelineColor(for phase: PomodoroService.Phase) -> Color {
        switch phase {
        case .working: return DesignSystem.Colors.studyAccentBright
        case .shortBreak: return DesignSystem.Colors.feedbackSuccess
        case .longBreak: return DesignSystem.Colors.feedbackInfo
        case .idle: return DesignSystem.Colors.subtleOverlay
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
// MARK: - Pomodoro Control Button

/// A glass-morphic circular control button for the pomodoro timer.
private struct PomodoroControlButton: View {
    let icon: String
    var size: CGFloat = 36
    var iconSize: CGFloat = 13
    var isAccented: Bool = false
    var accentColor: Color? = nil
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(
                    isAccented
                        ? (accentColor ?? DesignSystem.Colors.primaryText)
                        : DesignSystem.Colors.primaryText
                )
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(buttonFill)
                        .overlay(
                            Circle()
                                .strokeBorder(buttonBorder, lineWidth: 0.5)
                        )
                        .shadow(
                            color: isAccented && accentColor != nil
                                ? (accentColor ?? .clear).opacity(isHovered ? 0.35 : 0.2)
                                : Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06),
                            radius: isHovered ? 8 : 4,
                            y: 2
                        )
                }
                .scaleEffect(isPressed ? 0.92 : (isHovered ? 1.06 : 1.0))
                .animation(DesignSystem.Animation.snappy, value: isHovered)
                .animation(DesignSystem.Animation.snappy, value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var buttonFill: some ShapeStyle {
        if isAccented, let color = accentColor {
            return AnyShapeStyle(color.opacity(isHovered ? 0.22 : 0.15))
        }
        return AnyShapeStyle(
            isHovered
                ? DesignSystem.Colors.hoverBackground
                : DesignSystem.Colors.subtleOverlay
        )
    }

    private var buttonBorder: some ShapeStyle {
        if isAccented, let color = accentColor {
            return AnyShapeStyle(color.opacity(0.3))
        }
        return AnyShapeStyle(DesignSystem.Colors.borderOverlay.opacity(0.12))
    }
}

