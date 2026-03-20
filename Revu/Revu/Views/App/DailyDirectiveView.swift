import SwiftUI

/// Hero card showing a natural language study directive with course name,
/// weak concepts as pills, "Start" button, exam countdown, and mastery progress ring.
struct DailyDirectiveView: View {
    let directive: StudyDirective
    let secondaryCourses: [DailyPlan.CoursePlanItem]
    var onStartStudying: (UUID?) -> Void
    var onQuickImport: (() -> Void)? = nil

    @State private var showSecondaryCourses = false
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 0) {
            // Main directive card
            mainDirectiveCard

            // Secondary courses disclosure
            if !secondaryCourses.isEmpty {
                secondaryCoursesSection
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
    }

    // MARK: - Main Card

    private var mainDirectiveCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Top row: progress ring + course name + exam badge
            headerRow

            // Headline
            Text(directive.headline)
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .lineLimit(2)

            // Body text
            Text(directive.body)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .lineLimit(3)

            // Concept pills
            if !directive.weakConcepts.isEmpty {
                conceptPills
            }

            // Start button or Quick Import for empty state
            if directive.sessionType == .celebrate && directive.urgency == .low && directive.courseId == nil {
                if let onQuickImport {
                    quickImportButton(action: onQuickImport)
                }
            } else {
                startButton
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            progressRing

            if let courseName = directive.courseName {
                Text(courseName)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)
            }

            Spacer()

            if let countdown = directive.examCountdown {
                examBadge(countdown: countdown)
            }
        }
    }

    // MARK: - Progress Ring

    @ViewBuilder
    private var progressRing: some View {
        let isCelebrate = directive.urgency == .low || directive.sessionType == .celebrate
        let score = directive.examCountdown?.estimatedScore ?? 0
        let percentage = Int(score * 100)

        ZStack {
            if isCelebrate {
                // Checkmark for celebrate/low urgency
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "checkmark")
                    .font(DesignSystem.Typography.subheading)
                    .foregroundStyle(DesignSystem.Colors.accent)
            } else {
                // Background track
                Circle()
                    .stroke(DesignSystem.Colors.separator, lineWidth: 3)
                    .frame(width: 44, height: 44)

                // Progress arc
                Circle()
                    .trim(from: 0, to: CGFloat(score))
                    .stroke(urgencyAccentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                // Critical urgency: pulsing border
                if directive.urgency == .critical {
                    Circle()
                        .stroke(DesignSystem.Colors.feedbackError.opacity(isPulsing ? 0.4 : 0.1), lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .onAppear { isPulsing = true }
                        .animation(DesignSystem.Animation.ambientPulse, value: isPulsing)
                }

                // Center percentage text
                if percentage > 0 {
                    Text("\(percentage)%")
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
            }
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Exam Badge

    private func examBadge(countdown: StudyDirective.ExamCountdown) -> some View {
        Text(shortCountdown(days: countdown.daysRemaining))
            .font(DesignSystem.Typography.captionMedium)
            .foregroundStyle(examBadgeColor(days: countdown.daysRemaining))
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                Capsule()
                    .fill(examBadgeColor(days: countdown.daysRemaining).opacity(0.12))
            )
    }

    // MARK: - Concept Pills

    private var conceptPills: some View {
        let maxPills = 4
        let visibleConcepts = Array(directive.weakConcepts.prefix(maxPills))
        let overflow = directive.weakConcepts.count - maxPills

        return FlowLayout(spacing: DesignSystem.Spacing.xs) {
            ForEach(visibleConcepts, id: \.self) { concept in
                Text(concept)
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.accent.opacity(0.12))
                    )
            }

            if overflow > 0 {
                Text("+\(overflow) more")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.subtleOverlay)
                    )
            }
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        let cardCount = directive.estimatedMinutes > 0
            ? "\(directive.estimatedMinutes) min"
            : ""

        return Button {
            onStartStudying(directive.courseId)
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "play.fill")
                    .font(DesignSystem.Typography.captionMedium)

                Text("Start Studying")
                    .font(DesignSystem.Typography.bodyMedium)

                if !cardCount.isEmpty {
                    Text("(\(cardCount))")
                        .font(DesignSystem.Typography.caption)
                        .opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(DesignSystem.Colors.accent)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Quick Import Button

    private func quickImportButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "square.and.arrow.down")
                    .font(DesignSystem.Typography.captionMedium)

                Text("Import Material")
                    .font(DesignSystem.Typography.bodyMedium)
            }
            .foregroundStyle(DesignSystem.Colors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(DesignSystem.Colors.accent.opacity(0.12))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Secondary Courses

    private var secondaryCoursesSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DesignSystem.Colors.separator)
                .frame(height: 1)

            Button {
                withAnimation(DesignSystem.Animation.smooth) {
                    showSecondaryCourses.toggle()
                }
            } label: {
                HStack {
                    Text("Other courses")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(showSecondaryCourses ? 90 : 0))
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showSecondaryCourses {
                VStack(spacing: 0) {
                    ForEach(secondaryCourses) { course in
                        Button {
                            onStartStudying(course.courseId)
                        } label: {
                            HStack {
                                Text(course.courseName)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.primaryText)
                                    .lineLimit(1)

                                Spacer()

                                Text("\(course.dueCards) due")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if course.id != secondaryCourses.last?.id {
                            Rectangle()
                                .fill(DesignSystem.Colors.separator)
                                .frame(height: 1)
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Urgency Helpers

    private var urgencyAccentColor: Color {
        switch directive.urgency {
        case .critical: return DesignSystem.Colors.feedbackError
        case .high: return DesignSystem.Colors.feedbackWarning
        case .normal: return DesignSystem.Colors.accent
        case .low: return DesignSystem.Colors.accent
        }
    }

    private func examBadgeColor(days: Int) -> Color {
        if days <= 3 { return DesignSystem.Colors.feedbackError }
        if days <= 7 { return DesignSystem.Colors.feedbackWarning }
        return DesignSystem.Colors.accent
    }

    private func shortCountdown(days: Int) -> String {
        if days <= 0 { return "today" }
        if days < 7 { return "\(days)d" }
        let weeks = days / 7
        return "\(weeks)w"
    }
}

// MARK: - FlowLayout

/// Horizontal wrapping layout used for concept pills.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for size in sizes {
            if lineWidth + size.width > proposal.width ?? 0 {
                totalHeight += lineHeight + spacing
                lineWidth = size.width + spacing
                lineHeight = size.height
            } else {
                if lineWidth > 0 { lineWidth += spacing }
                lineWidth += size.width
                lineHeight = max(lineHeight, size.height)
            }
            totalWidth = max(totalWidth, lineWidth)
        }
        totalHeight += lineHeight

        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var lineX = bounds.minX
        var lineY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineX + size.width > bounds.maxX && lineX > bounds.minX {
                lineY += lineHeight + spacing
                lineHeight = 0
                lineX = bounds.minX
            }
            subview.place(at: CGPoint(x: lineX, y: lineY), proposal: .unspecified)
            lineHeight = max(lineHeight, size.height)
            lineX += size.width + spacing
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Daily Directive — Normal") {
    DailyDirectiveView(
        directive: StudyDirective(
            headline: "Reaction Mechanisms Need You",
            body: "Your exam is in 3 days. Focus on these weak areas to boost your score.",
            courseId: UUID(),
            courseName: "Organic Chemistry",
            weakConcepts: ["Mechanisms", "Acid-Base Eq.", "Stereochemistry"],
            sessionType: .examPrep,
            estimatedMinutes: 25,
            urgency: .normal,
            examCountdown: .init(courseName: "Organic Chemistry", daysRemaining: 3, estimatedScore: 0.72)
        ),
        secondaryCourses: [
            DailyPlan.CoursePlanItem(
                courseId: UUID(), courseName: "Biology", examDate: nil,
                daysUntilExam: nil, overallMastery: 0.6, dueCards: 8,
                totalCards: 40, priority: 1.0, topicGaps: []
            ),
            DailyPlan.CoursePlanItem(
                courseId: UUID(), courseName: "Linear Algebra", examDate: nil,
                daysUntilExam: nil, overallMastery: 0.8, dueCards: 3,
                totalCards: 20, priority: 0.5, topicGaps: []
            )
        ],
        onStartStudying: { _ in }
    )
    .frame(width: 280)
    .padding()
    .background(DesignSystem.Colors.sidebarBackground)
}

#Preview("Daily Directive — Empty") {
    DailyDirectiveView(
        directive: .empty,
        secondaryCourses: [],
        onStartStudying: { _ in },
        onQuickImport: {}
    )
    .frame(width: 280)
    .padding()
    .background(DesignSystem.Colors.sidebarBackground)
}
#endif
