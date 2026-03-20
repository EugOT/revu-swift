import SwiftUI

enum CourseCardVariant {
    case actionFirst       // Variant 1 (default) - Due count hero
    case progressCentric   // Variant 2 - Giant mastery ring
}

struct CourseCardV2: View {
    let item: DailyPlan.CoursePlanItem
    let variant: CourseCardVariant

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            headerRow

            switch variant {
            case .actionFirst:
                actionFirstContent
            case .progressCentric:
                progressCentricContent
            }

            if !item.topicGaps.isEmpty {
                topicGapsWarning
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(cardBackground)
        .onHover { isHovered = $0 }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            Text(item.courseName)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(DesignSystem.Colors.primaryText)

            Spacer()

            if let days = item.daysUntilExam {
                examCountdownPill(days: days)
            }
        }
    }

    private func examCountdownPill(days: Int) -> some View {
        let isUrgent = days <= 7
        let displayText = days <= 0 ? "Exam passed" : "\(days)d until exam"

        return Text(displayText)
            .font(DesignSystem.Typography.small)
            .foregroundStyle(isUrgent ? .red : DesignSystem.Colors.secondaryText)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                Capsule()
                    .fill(isUrgent ? Color.red.opacity(0.12) : DesignSystem.Colors.subtleOverlay)
            )
    }

    // MARK: - Variant 1: Action-First Content

    private var actionFirstContent: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.lg) {
            // Left: Due count hero
            dueCountHero
                .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Mastery ring
            ScoreRing(score: item.overallMastery, size: 72, lineWidth: 6)
        }
    }

    private var dueCountHero: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text("\(item.dueCards)")
                .font(DesignSystem.Typography.hero)
                .foregroundStyle(item.dueCards > 0
                    ? DesignSystem.Colors.studyAccentBright
                    : DesignSystem.Colors.tertiaryText)

            Text("due cards")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
    }

    // MARK: - Variant 2: Progress-Centric Content

    private var progressCentricContent: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Giant mastery ring (centered)
            giantMasteryRing
                .frame(maxWidth: .infinity, alignment: .center)

            // Metrics badges (horizontal)
            metricsBadges
        }
    }

    private var giantMasteryRing: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Colors.separator.opacity(0.3), lineWidth: 8)

            Circle()
                .trim(from: 0, to: item.overallMastery)
                .stroke(
                    DesignSystem.Gradients.studyAccentSoft,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text("\(Int(item.overallMastery * 100))%")
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.scoreColor(for: item.overallMastery))

                Text("mastery")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
        .frame(width: 96, height: 96)
    }

    private var metricsBadges: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Due count badge
            if item.dueCards > 0 {
                metricPill(
                    icon: "checkmark.circle.fill",
                    text: "\(item.dueCards) due",
                    color: DesignSystem.Colors.studyAccentBright
                )
            }

            // Exam countdown (if not shown in header)
            if let days = item.daysUntilExam, days > 0 && days <= 7 {
                metricPill(
                    icon: "calendar",
                    text: "\(days)d",
                    color: .red
                )
            }

            // Topic gaps count
            if !item.topicGaps.isEmpty {
                metricPill(
                    icon: "exclamationmark.triangle.fill",
                    text: "\(item.topicGaps.count)",
                    color: .orange
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func metricPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)

            Text(text)
                .font(DesignSystem.Typography.small)
                .foregroundStyle(color)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }

    // MARK: - Topic Gaps Warning

    private var topicGapsWarning: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)

            Text("\(item.topicGaps.count) topic\(item.topicGaps.count == 1 ? "" : "s") need attention")
                .font(DesignSystem.Typography.small)
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        let shadow = DesignSystem.Shadow.card(for: colorScheme)

        return RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
            .fill(DesignSystem.Colors.window)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
            .shadow(
                color: shadow.color,
                radius: isHovered ? shadow.radius + 4 : shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
            .animation(DesignSystem.Animation.elevation, value: isHovered)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("CourseCardV2 - Both Variants") {
    let sampleCourse1 = DailyPlan.CoursePlanItem(
        courseId: UUID(),
        courseName: "Organic Chemistry",
        examDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
        daysUntilExam: 5,
        overallMastery: 0.68,
        dueCards: 24,
        totalCards: 150,
        priority: 2.5,
        topicGaps: [
            DailyPlan.TopicGap(topicId: UUID(), topicName: "Alkenes", mastery: 0.35),
            DailyPlan.TopicGap(topicId: UUID(), topicName: "Stereochemistry", mastery: 0.42)
        ]
    )

    let sampleCourse2 = DailyPlan.CoursePlanItem(
        courseId: UUID(),
        courseName: "Linear Algebra",
        examDate: Calendar.current.date(byAdding: .day, value: 45, to: Date()),
        daysUntilExam: 45,
        overallMastery: 0.82,
        dueCards: 8,
        totalCards: 200,
        priority: 1.0,
        topicGaps: []
    )

    let sampleCourse3 = DailyPlan.CoursePlanItem(
        courseId: UUID(),
        courseName: "Physics II",
        examDate: nil,
        daysUntilExam: nil,
        overallMastery: 0.35,
        dueCards: 42,
        totalCards: 120,
        priority: 1.8,
        topicGaps: [
            DailyPlan.TopicGap(topicId: UUID(), topicName: "Electromagnetism", mastery: 0.28)
        ]
    )

    return ScrollView {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            // Variant 1: Action-First
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Variant 1: Action-First (Default)")
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                VStack(spacing: DesignSystem.Spacing.md) {
                    CourseCardV2(item: sampleCourse1, variant: .actionFirst)
                    CourseCardV2(item: sampleCourse2, variant: .actionFirst)
                    CourseCardV2(item: sampleCourse3, variant: .actionFirst)
                }
            }

            Divider()

            // Variant 2: Progress-Centric
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Variant 2: Progress-Centric")
                    .font(DesignSystem.Typography.heading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                VStack(spacing: DesignSystem.Spacing.md) {
                    CourseCardV2(item: sampleCourse1, variant: .progressCentric)
                    CourseCardV2(item: sampleCourse2, variant: .progressCentric)
                    CourseCardV2(item: sampleCourse3, variant: .progressCentric)
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }
    .frame(maxWidth: 600)
    .background(DesignSystem.Colors.canvasBackground)
}
#endif
