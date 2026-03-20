import SwiftUI

/// Exam readiness prediction panel showing estimated score, topic gaps, and countdown.
///
/// Uses `ConceptTracerService` for concept mastery and `CourseService` for topic coverage
/// to build a readiness prediction displayed as a progress ring and gap list.
struct ExamReadinessView: View {
    let courseId: UUID
    let examTitle: String
    let daysUntilExam: Int?

    @Environment(\.storage) private var storage
    @State private var prediction: ReadinessPrediction?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            headerLabel

            if isLoading {
                loadingPlaceholder
            } else if let prediction {
                readinessContent(prediction)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.subtleOverlay.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .task {
            await loadPrediction()
        }
    }

    // MARK: - Header

    private var headerLabel: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(DesignSystem.Typography.captionMedium)
            Text("EXAM READINESS")
                .font(DesignSystem.Typography.captionMedium)
                .tracking(0.8)
        }
        .foregroundStyle(DesignSystem.Colors.accent)
    }

    // MARK: - Loading

    private var loadingPlaceholder: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .controlSize(.small)
                .tint(DesignSystem.Colors.studyAccentBright)
            Text("Analyzing readiness...")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Content

    private func readinessContent(_ prediction: ReadinessPrediction) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                progressRing(score: prediction.estimatedScore)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Estimated Score")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text("\(Int(prediction.estimatedScore * 100))%")
                        .font(DesignSystem.Typography.title)
                        .foregroundStyle(scoreColor(for: prediction.estimatedScore))

                    if prediction.topicCount > 0 {
                        Text("\(prediction.topicCount) topic\(prediction.topicCount == 1 ? "" : "s") assessed")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer(minLength: 0)

                if let days = daysUntilExam, days > 0 {
                    countdownBadge(days: days)
                }
            }

            if !prediction.gaps.isEmpty {
                gapList(prediction.gaps)
            }

            if !prediction.gaps.isEmpty {
                Button {
                    // Placeholder for study weak areas action
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "book.fill")
                            .font(DesignSystem.Typography.captionMedium)
                        Text("Study Weak Areas")
                            .font(DesignSystem.Typography.bodyMedium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .fill(DesignSystem.Colors.studyAccentDeep)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Progress Ring

    private func progressRing(score: Double) -> some View {
        let ringSize: CGFloat = 100
        let strokeWidth: CGFloat = 6

        return ZStack {
            Circle()
                .stroke(DesignSystem.Colors.separator.opacity(0.3), lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: score)
                .stroke(
                    scoreColor(for: score),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DesignSystem.Animation.layout, value: score)
        }
        .frame(width: ringSize, height: ringSize)
    }

    // MARK: - Gap List

    private func gapList(_ gaps: [GapEntry]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Areas to Improve")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(gaps.prefix(5)) { gap in
                gapRow(gap)
            }

            if gaps.count > 5 {
                Text("+\(gaps.count - 5) more")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
        }
    }

    private func gapRow(_ gap: GapEntry) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(scoreColor(for: gap.mastery))
                .frame(width: DesignSystem.Spacing.xs, height: DesignSystem.Spacing.xs)

            Text(gap.name)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Mastery bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(DesignSystem.Colors.separator.opacity(0.3))
                    .frame(width: 50, height: 4)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(scoreColor(for: gap.mastery))
                    .frame(width: 50 * gap.mastery, height: 4)
            }

            Text("\(Int(gap.mastery * 100))%")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Countdown Badge

    private func countdownBadge(days: Int) -> some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text("\(days)")
                .font(DesignSystem.Typography.mono)
                .foregroundStyle(countdownColor(days: days))
            Text(days == 1 ? "day" : "days")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(countdownColor(days: days).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(countdownColor(days: days).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Color Helpers

    private func scoreColor(for score: Double) -> Color {
        switch score {
        case ..<0.4:
            return DesignSystem.Colors.feedbackError
        case 0.4..<0.7:
            return DesignSystem.Colors.feedbackWarning
        case 0.7..<0.85:
            return DesignSystem.Colors.accent
        default:
            return DesignSystem.Colors.feedbackSuccess
        }
    }

    private func countdownColor(days: Int) -> Color {
        switch days {
        case ..<4:
            return DesignSystem.Colors.feedbackError
        case 4..<8:
            return DesignSystem.Colors.feedbackWarning
        case 8..<15:
            return DesignSystem.Colors.accent
        default:
            return DesignSystem.Colors.secondaryText
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadPrediction() async {
        isLoading = true
        defer { isLoading = false }

        let courseService = CourseService(storage: storage)
        let conceptTracer = ConceptTracerService(storage: storage)

        let progress = await courseService.courseProgress(courseId: courseId)
        let conceptStates = (try? await conceptTracer.allConceptStates()) ?? []

        // Build gap entries from topic coverage
        let gaps: [GapEntry] = progress.topicCoverage
            .filter { $0.mastery < 0.85 }
            .sorted { $0.mastery < $1.mastery }
            .map { topic in
                GapEntry(
                    id: topic.topicId,
                    name: topic.topicName,
                    mastery: topic.mastery
                )
            }

        // Calculate estimated score from concept states + topic coverage
        let estimatedScore: Double
        if !conceptStates.isEmpty {
            let conceptAvg = conceptStates.reduce(0.0) { $0 + $1.pKnown } / Double(conceptStates.count)
            // Blend concept mastery with topic mastery
            estimatedScore = (conceptAvg * 0.4 + progress.overallMastery * 0.6)
        } else {
            estimatedScore = progress.overallMastery
        }

        prediction = ReadinessPrediction(
            estimatedScore: min(1.0, max(0.0, estimatedScore)),
            topicCount: progress.topicCoverage.count,
            gaps: gaps
        )
    }
}

// MARK: - Supporting Types

extension ExamReadinessView {
    struct ReadinessPrediction {
        let estimatedScore: Double
        let topicCount: Int
        let gaps: [GapEntry]
    }

    struct GapEntry: Identifiable {
        let id: UUID
        let name: String
        let mastery: Double
    }
}
