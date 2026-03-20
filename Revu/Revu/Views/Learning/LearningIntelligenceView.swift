import SwiftUI
import Charts

struct LearningIntelligenceView: View {
    // MARK: - Loading Phases for Progressive Display
    private enum LoadingPhase: Int, Comparable {
        case initial = 0
        case coreData = 1      // Session + navigator snapshots (fast)
        case planData = 2      // Workspace plan (medium)
        case analyticsData = 3 // Review analytics (slow - heavy computation)
        case complete = 4
        
        static func < (lhs: LoadingPhase, rhs: LoadingPhase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    private struct ReviewDayMetrics: Equatable {
        let cardsLearned: Int
        let reviewsCompleted: Int
        let totalReviewSeconds: Int

        static let empty = ReviewDayMetrics(cardsLearned: 0, reviewsCompleted: 0, totalReviewSeconds: 0)
    }

    private struct DailyReviewSummary: Identifiable, Equatable {
        let date: Date
        let reviewCount: Int
        let learnedCount: Int
        let totalSeconds: Int
        let successCount: Int
        let retention: Double

        var id: Date { date }
    }

    private struct HeatmapWeek: Identifiable, Equatable {
        struct Day: Identifiable, Equatable {
            let date: Date
            let reviewCount: Int
            let learnedCount: Int
            let isFuture: Bool

            var id: Date { date }
        }

        let startOfWeek: Date
        let days: [Day]

        var id: Date { startOfWeek }
    }

    private struct TrendSample: Identifiable, Equatable {
        let date: Date
        let value: Double

        var id: Date { date }
    }

    private struct ReviewStreak: Equatable {
        let current: Int
        let best: Int
        let activeDays: Int
        let totalReviews: Int
        let totalLearned: Int
        let averageSessionSeconds: Double

        static let empty = ReviewStreak(
            current: 0,
            best: 0,
            activeDays: 0,
            totalReviews: 0,
            totalLearned: 0,
            averageSessionSeconds: 0
        )
    }

    private struct ReviewAnalytics: Equatable {
        let today: ReviewDayMetrics
        let timeline: [DailyReviewSummary]
        let heatmap: [HeatmapWeek]
        let streak: ReviewStreak
        let retentionTrend: [TrendSample]
        let reviewVelocityTrend: [TrendSample]
        let learningTrend: [TrendSample]
        let maxDailyReviewCount: Int
        let maxDailyLearnedCount: Int

        static let empty = ReviewAnalytics(
            today: .empty,
            timeline: [],
            heatmap: [],
            streak: .empty,
            retentionTrend: [],
            reviewVelocityTrend: [],
            learningTrend: [],
            maxDailyReviewCount: 0,
            maxDailyLearnedCount: 0
        )
    }

    @Environment(\.storage) private var storage
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storeEvents: StoreEvents
    
    // Loading state - phased for progressive display
    @State private var loadingPhase: LoadingPhase = .initial
    @State private var loadTask: Task<Void, Never>?
    
    // Core data (Phase 1 - loads fast)
    @State private var sessionSnapshot: SessionCuratorSnapshot = .empty
    @State private var navigatorSnapshot: AdaptiveNavigatorSnapshot = .empty
    @State private var decks: [Deck] = []
    @State private var settings: UserSettings = UserSettings()
    
    // Plan data (Phase 2)
    @State private var workspacePlan: [StudyPlanSummary] = []
    
    // Analytics data (Phase 3 - computed in background)
    @State private var reviewMetrics: ReviewDayMetrics = .empty
    @State private var reviewHistory: [DailyReviewSummary] = []
    @State private var reviewHeatmap: [HeatmapWeek] = []
    @State private var reviewStreak: ReviewStreak = .empty
    @State private var retentionTrend: [TrendSample] = []
    @State private var reviewVelocityTrend: [TrendSample] = []
    @State private var learningTrend: [TrendSample] = []
    @State private var heatmapMaxCount: Int = 0
    @State private var heatmapMaxLearned: Int = 0
    
    // UI state
    @State private var showingStudy = false
    @State private var showingGenerator = false
    @State private var showingStatsSheet = false
    
    // Computed loading helpers
    private var isLoading: Bool { loadingPhase < .complete }
    private var hasCoreData: Bool { loadingPhase >= .coreData }
    private var hasPlanData: Bool { loadingPhase >= .planData }
    private var hasAnalyticsData: Bool { loadingPhase >= .analyticsData }

    var body: some View {
        Group {
            if showingStudy {
                StudySessionSurface {
                    StudySessionView(onDismiss: endStudySession)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            } else {
                WorkspaceCanvas { width in
                    learningHeader(for: width)
                    reviewActivitySection(for: width)
                    learningTrendsSection(for: width)
                    sessionPreviewSection(for: width)
                }
                .background(DesignSystem.Colors.window)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingStudy)
        .task { await loadSnapshotsPhased() }
        .onReceive(storeEvents.$tick) { _ in
            loadTask?.cancel()
            loadTask = Task { await loadSnapshotsPhased() }
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }
    
    private func endStudySession() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingStudy = false
        }
        loadTask?.cancel()
        loadTask = Task { await loadSnapshotsPhased() }
    }
}

// MARK: - Sections

private extension LearningIntelligenceView {
    private func learningHeader(for width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs * 0.75) {
                    HStack(spacing: DesignSystem.Spacing.xs * 0.5) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        Text("Learning intelligence")
                            .font(DesignSystem.Typography.smallMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .textCase(.uppercase)
                            .tracking(0.9)
                    }
                    Text("Today")
                        .font(DesignSystem.Typography.hero)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }

                Spacer(minLength: DesignSystem.Spacing.md)

                if hasCoreData {
                    startSessionButton
                }
            }

            if hasCoreData {
                heroMetrics(for: width)
                streakSummary
            } else {
                heroMetricsSkeleton(for: width)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Full-Width Review Session Section

    private func sessionPreviewSection(for width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Review Session")
                    .font(DesignSystem.Typography.subheading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                if hasCoreData && sessionSnapshot.totalDue > 0 {
                    Text("\(sessionSnapshot.totalDue) cards ready")
                        .font(DesignSystem.Typography.small)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
            }

            if !hasCoreData {
                sessionSkeletonContent
            } else if sessionSnapshot.queuePreview.isEmpty && sessionSnapshot.conceptWeaves.isEmpty {
                emptyStateCompact(
                    icon: "sparkles",
                    message: "No cards due for review"
                )
            } else {
                sessionFullWidthContent(for: width)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func sessionFullWidthContent(for width: CGFloat) -> some View {
        let useThreeColumns = width >= 1200
        let useTwoColumns = width >= 800
        
        if useThreeColumns {
            // Three-column layout: Queue | Interleaving | Stats
            HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                // Queue preview column
                if !sessionSnapshot.queuePreview.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        sectionHeaderCompact("Next Up", icon: "arrow.right.circle.fill")
                        ForEach(sessionSnapshot.queuePreview.prefix(4)) { preview in
                            compactQueueRow(preview)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Concept weaves column
                if !sessionSnapshot.conceptWeaves.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        sectionHeaderCompact("Interleaving", icon: "waveform.path")
                        ForEach(sessionSnapshot.conceptWeaves.prefix(4)) { weave in
                            compactWeaveRow(weave)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Session stats column
                sessionStatsColumn
            }
        } else if useTwoColumns {
            // Two-column layout: Queue/Weaves | Stats
            HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    if !sessionSnapshot.queuePreview.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionHeaderCompact("Next Up", icon: "arrow.right.circle.fill")
                            ForEach(sessionSnapshot.queuePreview.prefix(3)) { preview in
                                compactQueueRow(preview)
                            }
                        }
                    }
                    
                    if !sessionSnapshot.conceptWeaves.isEmpty {
                        Divider().overlay(DesignSystem.Colors.separator)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionHeaderCompact("Interleaving", icon: "waveform.path")
                            ForEach(sessionSnapshot.conceptWeaves.prefix(2)) { weave in
                                compactWeaveRow(weave)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                sessionStatsColumn
                    .frame(maxWidth: 280)
            }
        } else {
            // Single column - compact vertical stack
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                if !sessionSnapshot.queuePreview.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        sectionHeaderCompact("Next Up", icon: "arrow.right.circle.fill")
                        ForEach(sessionSnapshot.queuePreview.prefix(3)) { preview in
                            compactQueueRow(preview)
                        }
                    }
                }
                
                if !sessionSnapshot.conceptWeaves.isEmpty {
                    Divider().overlay(DesignSystem.Colors.separator)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        sectionHeaderCompact("Interleaving", icon: "waveform.path")
                        ForEach(sessionSnapshot.conceptWeaves.prefix(2)) { weave in
                            compactWeaveRow(weave)
                        }
                    }
                }
            }
        }
    }
    
    private var sessionStatsColumn: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeaderCompact("Session Stats", icon: "chart.bar.fill")
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                sessionStatRow(
                    icon: "square.stack.3d.down.forward",
                    label: "Total Due",
                    value: "\(sessionSnapshot.totalDue)"
                )
                sessionStatRow(
                    icon: "lightbulb.fill",
                    label: "Concepts",
                    value: "\(sessionSnapshot.conceptCoverage)"
                )
                sessionStatRow(
                    icon: "shuffle",
                    label: "Interleaving",
                    value: percentString(sessionSnapshot.interleavingScore)
                )
            }
            
            if !sessionSnapshot.insights.isEmpty {
                Divider().overlay(DesignSystem.Colors.separator)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ForEach(sessionSnapshot.insights.prefix(2)) { insight in
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: insight.symbol)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            Text(insight.title)
                                .font(DesignSystem.Typography.small)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay.opacity(colorScheme == .dark ? 0.5 : 0.3))
        )
    }
    
    private func sessionStatRow(icon: String, label: String, value: String) -> some View {
        HStack {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                Text(label)
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.smallMedium)
                .foregroundStyle(DesignSystem.Colors.primaryText)
        }
    }
    
    private var sessionSkeletonContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.lightOverlay.opacity(0.5))
                    .frame(height: 60)
                    .shimmering()
            }
        }
    }

    private func reviewActivitySection(for width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Review activity")
                    .font(DesignSystem.Typography.subheading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                Spacer()
                Text("Last 21 weeks")
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }

            if !hasAnalyticsData {
                // Skeleton while analytics load
                heatmapSkeleton(for: width)
            } else if reviewHeatmap.isEmpty {
                emptyStateCompact(
                    icon: "calendar.badge.clock",
                    message: "Reviews will appear as you study"
                )
            } else {
                contributionGrid(for: width)

                HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                    Text("\(reviewStreak.totalReviews) reviews")
                    Text("∙")
                    Text("\(reviewStreak.activeDays) active days")
                    if reviewStreak.best > 0 {
                        Text("∙")
                        Text("Best streak \(reviewStreak.best) days")
                    }
                    Text("∙")
                    Text("\(reviewStreak.totalLearned) cards learned")
                }
                .font(DesignSystem.Typography.small)
                .foregroundStyle(DesignSystem.Colors.secondaryText)

                heatmapLegend
            }
        }
    }

    private func learningTrendsSection(for width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Learning pulse")
                    .font(DesignSystem.Typography.subheading)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }

            let columns = trendColumns(for: width)
            LazyVGrid(columns: columns, alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                if hasAnalyticsData {
                    trendCard(
                        title: "Retention trajectory",
                        icon: "chart.xyaxis.line",
                        subtitle: "Rolling 7-day recall",
                        data: retentionTrend,
                        unit: .percent
                    )
                    trendCard(
                        title: "Review velocity",
                        icon: "speedometer",
                        subtitle: "Average reviews / day",
                        data: reviewVelocityTrend,
                        unit: .count
                    )
                    trendCard(
                        title: "Fresh cards",
                        icon: "sparkles",
                        subtitle: "Average new cards / day",
                        data: learningTrend,
                        unit: .count
                    )
                } else {
                    // Skeleton cards
                    ForEach(0..<3, id: \.self) { _ in
                        trendCardSkeleton
                    }
                }
                
                // Workload card integrated into the grid
                upcomingWorkloadCard(for: width)
            }
        }
    }
    
    // MARK: - Workload Card (Now in Grid)
    
    private func upcomingWorkloadCard(for width: CGFloat) -> some View {
        let horizon = width >= 900 ? 14 : 10
        let aggregated = hasPlanData ? aggregatedWorkspacePlan(limit: horizon) : []
        let totalNew = aggregated.reduce(0) { $0 + $1.day.newCount }
        let totalReview = aggregated.reduce(0) { $0 + $1.day.reviewCount }
        let totalCards = totalNew + totalReview

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header matching trend cards
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        Text("UPCOMING WORKLOAD")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .tracking(1.0)
                    }
                    
                    Text("\(totalCards)")
                        .font(.system(size: 32, weight: .semibold, design: .default))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                
                Spacer()
                
                if let deadline = nextWorkspaceDeadline {
                    Text(deadline, style: .relative)
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
                        )
                }
            }

            if !hasPlanData {
                workloadSkeletonChart
                    .frame(height: 110)
            } else if aggregated.isEmpty {
                emptyStateCompact(
                    icon: "calendar.badge.clock",
                    message: "No upcoming reviews"
                )
                .frame(height: 100)
            } else {
                workloadMiniChart(for: aggregated, width: width)
                    .frame(height: 110)
                    .padding(.bottom, DesignSystem.Spacing.xs)
            }
            
            Text("Cards over next \(horizon) days")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
    
    private func workloadMiniChart(for aggregated: [AggregatedPlanDay], width: CGFloat) -> some View {
        Chart {
            ForEach(aggregated) { entry in
                BarMark(
                    x: .value("Date", entry.day.date, unit: .day),
                    y: .value("Cards", entry.day.total)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primaryText.opacity(0.6),
                            DesignSystem.Colors.primaryText.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(3)
            }
            
            ForEach(aggregated) { entry in
                LineMark(
                    x: .value("Date", entry.day.date, unit: .day),
                    y: .value("Total", entry.day.total)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            
            if let last = aggregated.last {
                PointMark(
                    x: .value("Date", last.day.date, unit: .day),
                    y: .value("Total", last.day.total)
                )
                .foregroundStyle(DesignSystem.Colors.window)
                .symbolSize(80)
                .annotation(position: .overlay, alignment: .center) {
                    Circle()
                        .strokeBorder(DesignSystem.Colors.primaryText, lineWidth: 2.5)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
    }
    
    private var workloadSkeletonChart: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<10, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignSystem.Colors.lightOverlay.opacity(0.5))
                    .frame(height: CGFloat.random(in: 30...90))
                    .shimmering()
            }
        }
    }

    private func aggregatedWorkspacePlan(limit: Int) -> [AggregatedPlanDay] {
        guard limit > 0 else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var totals: [Date: (new: Int, review: Int)] = [:]
        var deadlines: Set<Date> = []

        for summary in workspacePlan {
            if let dueDate = summary.dueDate {
                deadlines.insert(calendar.startOfDay(for: dueDate))
            }

            for day in summary.days {
                let normalized = calendar.startOfDay(for: day.date)
                var current = totals[normalized] ?? (new: 0, review: 0)
                current.new += day.newCount
                current.review += day.reviewCount
                totals[normalized] = current
            }
        }

        var orderedDates: [Date] = []
        orderedDates.reserveCapacity(limit)

        var seen: Set<Date> = []
        for offset in 0..<limit {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            let normalized = calendar.startOfDay(for: date)
            if seen.insert(normalized).inserted {
                orderedDates.append(normalized)
            }
        }

        let sourceDates = Set(totals.keys).union(deadlines).filter { $0 >= today }.sorted()
        for date in sourceDates {
            if seen.insert(date).inserted {
                orderedDates.append(date)
            }
        }

        orderedDates.sort()

        var aggregated: [AggregatedPlanDay] = []
        aggregated.reserveCapacity(limit)

        for date in orderedDates {
            let totalsForDay = totals[date] ?? (new: 0, review: 0)
            let isDeadline = deadlines.contains(date)
            let day = StudyPlanSummary.Day(date: date, newCount: totalsForDay.new, reviewCount: totalsForDay.review)
            aggregated.append(AggregatedPlanDay(day: day, isDeadline: isDeadline))

            if aggregated.count >= limit {
                break
            }
        }

        if aggregated.isEmpty, let fallbackDate = sourceDates.first {
            let totalsForDay = totals[fallbackDate] ?? (new: 0, review: 0)
            let day = StudyPlanSummary.Day(date: fallbackDate, newCount: totalsForDay.new, reviewCount: totalsForDay.review)
            let isDeadline = deadlines.contains(fallbackDate)
            aggregated.append(AggregatedPlanDay(day: day, isDeadline: isDeadline))
        }

        return aggregated
    }

    private var nextWorkspaceDeadline: Date? {
        workspacePlan.compactMap { $0.dueDate }.min()
    }
}

private struct AggregatedPlanDay: Identifiable {
    let day: StudyPlanSummary.Day
    let isDeadline: Bool

    var id: Date { day.date }
}

// MARK: - Compact Components

private extension LearningIntelligenceView {
    var surfaceBackground: Color {
        colorScheme == .dark
            ? DesignSystem.Colors.subtleOverlay.opacity(0.9)
            : DesignSystem.Colors.subtleOverlay.opacity(0.55)
    }

    enum TrendUnit {
        case percent
        case count
    }

    private var sessionButtonGradient: LinearGradient {
        let base = DesignSystem.Colors.studyAccentDeep
        let start = base.opacity(colorScheme == .dark ? 0.92 : 0.96)
        let end = base.opacity(colorScheme == .dark ? 0.72 : 0.82)
        return LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var newWorkloadGradient: LinearGradient {
        let top = Color.orange.opacity(colorScheme == .dark ? 0.85 : 0.75)
        let bottom = Color.orange.opacity(colorScheme == .dark ? 0.55 : 0.4)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    private var reviewWorkloadGradient: LinearGradient {
        let top = DesignSystem.Colors.studyAccentMid.opacity(colorScheme == .dark ? 0.9 : 0.8)
        let bottom = DesignSystem.Colors.studyAccentMid.opacity(colorScheme == .dark ? 0.6 : 0.45)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    private var totalWorkloadGradient: LinearGradient {
        let primary = DesignSystem.Colors.studyAccentMid.opacity(colorScheme == .dark ? 0.85 : 0.8)
        let secondary = DesignSystem.Colors.studyAccentMid.opacity(colorScheme == .dark ? 0.4 : 0.3)
        return LinearGradient(colors: [primary, secondary], startPoint: .leading, endPoint: .trailing)
    }

    private var startSessionButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingStudy = true
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(sessionSnapshot.totalDue == 0 ? "Start session" : "Review \(sessionSnapshot.totalDue)")
                    .font(DesignSystem.Typography.bodyMedium)
            }
            .foregroundStyle(DesignSystem.Colors.window)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.primaryText)
            )
            .overlay(
                Capsule()
                    .strokeBorder(DesignSystem.Colors.primaryText.opacity(0.1), lineWidth: 1)
            )
            .shadow(
                color: DesignSystem.Colors.primaryText.opacity(0.15),
                radius: 8,
                x: 0,
                y: 4
            )
            .contentShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(sessionSnapshot.totalDue == 0 ? "Start study session" : "Review \(sessionSnapshot.totalDue) cards")
    }

    @ViewBuilder
    private func heroMetrics(for width: CGFloat) -> some View {
        let retentionDelta = trendDeltaText(for: retentionTrend, unit: .percent)
        let avgSecondsPerReview = reviewMetrics.reviewsCompleted > 0
            ? Double(reviewMetrics.totalReviewSeconds) / Double(reviewMetrics.reviewsCompleted)
            : 0
        let timeCaption = avgSecondsPerReview > 0
            ? "\(Int(round(avgSecondsPerReview)))s per card"
            : nil

        if width >= 940 {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                heroMetricCard(
                    title: "Cards learned",
                    icon: "checkmark.seal",
                    detail: "Fresh knowledge captured today",
                    value: "\(reviewMetrics.cardsLearned)"
                )
                heroMetricCard(
                    title: "Total reviews",
                    icon: "square.stack.3d.down.forward",
                    detail: "Repetitions completed today",
                    value: "\(reviewMetrics.reviewsCompleted)"
                )
                VStack(spacing: DesignSystem.Spacing.md) {
                    compactMetricCard(
                        title: "Retention",
                        icon: "chart.line.uptrend.xyaxis",
                        value: percentString(navigatorSnapshot.averageMastery),
                        caption: retentionDelta
                    )
                    compactMetricCard(
                        title: "Focus time",
                        icon: "clock",
                        value: formattedDuration(reviewMetrics.totalReviewSeconds),
                        caption: timeCaption
                    )
                }
                .frame(maxWidth: 260)
            }
        } else if width >= 680 {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    heroMetricCard(
                        title: "Cards learned",
                        icon: "checkmark.seal",
                        detail: "Today",
                        value: "\(reviewMetrics.cardsLearned)"
                    )
                    heroMetricCard(
                        title: "Total reviews",
                        icon: "square.stack.3d.down.forward",
                        detail: "Today",
                        value: "\(reviewMetrics.reviewsCompleted)"
                    )
                }
                HStack(spacing: DesignSystem.Spacing.md) {
                    compactMetricCard(
                        title: "Retention",
                        icon: "chart.line.uptrend.xyaxis",
                        value: percentString(navigatorSnapshot.averageMastery),
                        caption: retentionDelta
                    )
                    compactMetricCard(
                        title: "Focus time",
                        icon: "clock",
                        value: formattedDuration(reviewMetrics.totalReviewSeconds),
                        caption: timeCaption
                    )
                }
            }
        } else {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.xs) {
                miniStatCard(
                    title: "Cards learned",
                    icon: "checkmark.seal",
                    value: "\(reviewMetrics.cardsLearned)"
                )
                miniStatCard(
                    title: "Total reviews",
                    icon: "square.stack.3d.down.forward",
                    value: "\(reviewMetrics.reviewsCompleted)"
                )
                miniStatCard(
                    title: "Retention",
                    icon: "chart.line.uptrend.xyaxis",
                    value: percentString(navigatorSnapshot.averageMastery),
                    caption: retentionDelta
                )
                miniStatCard(
                    title: "Focus time",
                    icon: "clock",
                    value: formattedDuration(reviewMetrics.totalReviewSeconds),
                    caption: timeCaption
                )
            }
        }
    }

    private func heroMetricCard(
        title: String,
        icon: String,
        detail: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text(title.uppercased())
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .tracking(0.8)
            }

            Text(value)
                .font(Font.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(DesignSystem.Colors.primaryText)

            Text(detail)
                .font(DesignSystem.Typography.small)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay.opacity(colorScheme == .dark ? 0.75 : 0.6))
        )
    }

    private func compactMetricCard(
        title: String,
        icon: String,
        value: String,
        caption: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs * 0.75) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text(title.uppercased())
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .tracking(0.7)
            }
            Text(value)
                .font(DesignSystem.Typography.subheading)
                .foregroundStyle(DesignSystem.Colors.primaryText)
            if let caption {
                Text(caption)
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay.opacity(colorScheme == .dark ? 0.85 : 0.55))
        )
    }

    private func miniStatCard(
        title: String,
        icon: String,
        value: String,
        caption: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text(title.uppercased())
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .tracking(0.7)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(DesignSystem.Colors.primaryText)
            if let caption {
                Text(caption)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay.opacity(colorScheme == .dark ? 0.75 : 0.6))
        )
    }

    @ViewBuilder
    private var streakSummary: some View {
        if reviewStreak.totalReviews == 0 {
            Text("No review momentum yet—run a quick session to light up the graph.")
                .font(DesignSystem.Typography.small)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .padding(.top, DesignSystem.Spacing.xs)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    streakChip(icon: "flame.fill", title: "Current streak", value: "\(reviewStreak.current) days")
                    streakChip(icon: "crown.fill", title: "Best streak", value: "\(reviewStreak.best) days")
                    streakChip(icon: "calendar", title: "Active days", value: "\(reviewStreak.activeDays)")
                    streakChip(icon: "checkmark.circle", title: "Reviews", value: "\(reviewStreak.totalReviews)")
                    streakChip(icon: "bolt.fill", title: "Cards learned", value: "\(reviewStreak.totalLearned)")
                    if reviewStreak.averageSessionSeconds > 0 {
                        streakChip(icon: "timer", title: "Avg session", value: formattedDuration(Int(reviewStreak.averageSessionSeconds)))
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func streakChip(icon: String, title: String, value: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .tracking(0.7)
                Text(value)
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.lightOverlay.opacity(colorScheme == .dark ? 0.8 : 0.5))
        )
    }

    private func contributionGrid(for width: CGFloat) -> some View {
        let cell: CGFloat = width >= 820 ? 14 : 12
        let spacing: CGFloat = 3
        let minHeight = (cell * 7) + (spacing * 6) + (DesignSystem.Spacing.sm * 2)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(surfaceBackground)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(reviewHeatmap) { week in
                        VStack(spacing: spacing) {
                            ForEach(week.days) { day in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(heatmapColor(for: day))
                                    .frame(width: cell, height: cell)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .stroke(
                                                day.learnedCount > 0
                                                    ? DesignSystem.Colors.studyAccentBright.opacity(colorScheme == .dark ? 0.75 : 0.6)
                                                    : Color.clear,
                                                lineWidth: day.learnedCount > 0 ? 1.2 : 0
                                            )
                                    )
                                    .accessibilityLabel(heatmapAccessibility(for: day))
                            }
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
    }

    private var heatmapLegend: some View {
        let low = Color(light: Color(white: 0.92), dark: Color(white: 0.22))
        let high = Color(light: Color(white: 0.47), dark: Color(white: 0.78))

        return HStack(spacing: DesignSystem.Spacing.xs) {
            Text("Less")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            LinearGradient(colors: [low, high], startPoint: .leading, endPoint: .trailing)
                .frame(width: 100, height: 10)
                .clipShape(Capsule())
            Text("More")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
        }
    }

    private func heatmapColor(for day: HeatmapWeek.Day) -> Color {
        if day.isFuture {
            return DesignSystem.Colors.lightOverlay.opacity(colorScheme == .dark ? 0.25 : 0.18)
        }

        guard heatmapMaxCount > 0 else {
            return DesignSystem.Colors.lightOverlay.opacity(colorScheme == .dark ? 0.45 : 0.3)
        }

        let normalized = Double(day.reviewCount) / Double(max(1, heatmapMaxCount))
        let lightLevel = 0.92 - (normalized * 0.45)
        let darkLevel = 0.22 + (normalized * 0.55)
        return Color(
            light: Color(white: lightLevel),
            dark: Color(white: darkLevel)
        )
    }

    private func heatmapAccessibility(for day: HeatmapWeek.Day) -> String {
        let dateString = day.date.formatted(date: .abbreviated, time: .omitted)
        if day.reviewCount == 0 {
            return "No reviews on \(dateString)"
        } else {
            let learnedSuffix = day.learnedCount > 0 ? ", \(day.learnedCount) new cards" : ""
            return "\(day.reviewCount) reviews on \(dateString)\(learnedSuffix)"
        }
    }

    private func trendColumns(for width: CGFloat) -> [GridItem] {
        let count: Int
        if width >= 1400 {
            count = 4  // All 4 cards including workload
        } else if width >= 1180 {
            count = 3
        } else if width >= 780 {
            count = 2
        } else {
            count = 1
        }
        return Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.lg), count: count)
    }
    
    // MARK: - Skeleton Components
    
    @ViewBuilder
    private func heroMetricsSkeleton(for width: CGFloat) -> some View {
        if width >= 940 {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                heroMetricCardSkeleton
                heroMetricCardSkeleton
                VStack(spacing: DesignSystem.Spacing.md) {
                    compactMetricCardSkeleton
                    compactMetricCardSkeleton
                }
                .frame(maxWidth: 260)
            }
        } else if width >= 680 {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    heroMetricCardSkeleton
                    heroMetricCardSkeleton
                }
                HStack(spacing: DesignSystem.Spacing.md) {
                    compactMetricCardSkeleton
                    compactMetricCardSkeleton
                }
            }
        } else {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.xs) {
                compactMetricCardSkeleton
                compactMetricCardSkeleton
                compactMetricCardSkeleton
                compactMetricCardSkeleton
            }
        }
    }
    
    private var heroMetricCardSkeleton: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignSystem.Colors.lightOverlay.opacity(0.6))
                    .frame(width: 80, height: 14)
                    .shimmering()
            }
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignSystem.Colors.lightOverlay.opacity(0.5))
                .frame(width: 100, height: 42)
                .shimmering()
            RoundedRectangle(cornerRadius: 4)
                .fill(DesignSystem.Colors.lightOverlay.opacity(0.4))
                .frame(width: 140, height: 14)
                .shimmering()
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay.opacity(colorScheme == .dark ? 0.75 : 0.6))
        )
    }
    
    private var compactMetricCardSkeleton: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            RoundedRectangle(cornerRadius: 4)
                .fill(DesignSystem.Colors.lightOverlay.opacity(0.6))
                .frame(width: 60, height: 12)
                .shimmering()
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignSystem.Colors.lightOverlay.opacity(0.5))
                .frame(width: 70, height: 20)
                .shimmering()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay.opacity(colorScheme == .dark ? 0.85 : 0.55))
        )
    }
    
    private func heatmapSkeleton(for width: CGFloat) -> some View {
        let cell: CGFloat = width >= 820 ? 14 : 12
        let spacing: CGFloat = 3
        let minHeight = (cell * 7) + (spacing * 6) + (DesignSystem.Spacing.sm * 2)
        
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(surfaceBackground)
            
            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<21, id: \.self) { week in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(DesignSystem.Colors.lightOverlay.opacity(0.3))
                                .frame(width: cell, height: cell)
                                .shimmering()
                        }
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
    }
    
    private var trendCardSkeleton: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.lightOverlay.opacity(0.5))
                        .frame(width: 100, height: 14)
                        .shimmering()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.lightOverlay.opacity(0.4))
                        .frame(width: 80, height: 32)
                        .shimmering()
                }
                Spacer()
            }
            
            // Chart skeleton
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignSystem.Colors.lightOverlay.opacity(0.3))
                        .frame(height: CGFloat.random(in: 40...100))
                        .shimmering()
                }
            }
            .frame(height: 110)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(DesignSystem.Colors.lightOverlay.opacity(0.4))
                .frame(width: 120, height: 12)
                .shimmering()
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    private func trendCard(
        title: String,
        icon: String,
        subtitle: String,
        data: [TrendSample],
        unit: TrendUnit
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                        Text(title.uppercased())
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .tracking(1.0)
                    }
                    
                    Text(formattedTrendValue(data.last?.value, unit: unit))
                        .font(.system(size: 32, weight: .semibold, design: .default))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                
                Spacer()
                
                if let deltaText = trendDeltaText(for: data, unit: unit) {
                    Text(deltaText)
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
                        )
                }
            }
            
            // Chart
            if data.isEmpty {
                emptyStateCompact(
                    icon: "chart.line.uptrend.xyaxis",
                    message: "No data yet"
                )
                .frame(height: 100)
            } else {
                Chart {
                    ForEach(data) { sample in
                        LineMark(
                            x: .value("Date", sample.date),
                            y: .value("Value", sample.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .shadow(color: DesignSystem.Colors.primaryText.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    
                    if let last = data.last {
                        PointMark(
                            x: .value("Date", last.date),
                            y: .value("Value", last.value)
                        )
                        .foregroundStyle(DesignSystem.Colors.window)
                        .symbolSize(100)
                        .annotation(position: .overlay, alignment: .center) {
                            Circle()
                                .strokeBorder(DesignSystem.Colors.primaryText, lineWidth: 3)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 110)
                .padding(.bottom, DesignSystem.Spacing.xs)
            }
            
            Text(subtitle)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }

    private func formattedTrendValue(_ value: Double?, unit: TrendUnit) -> String {
        guard let value else { return "—" }
        switch unit {
        case .percent:
            return percentString(value)
        case .count:
            if abs(value) >= 10 {
                return "\(Int(round(value)))"
            } else {
                return String(format: "%.1f", value)
            }
        }
    }

    private func trendDeltaText(for data: [TrendSample], unit: TrendUnit) -> String? {
        guard data.count >= 2,
              let latest = data.last?.value,
              let previous = data.dropLast().last?.value else { return nil }
        let delta = latest - previous
        let threshold = unit == .percent ? 0.005 : 0.05
        guard abs(delta) > threshold else { return nil }
        return formatDelta(delta, unit: unit)
    }

    private func formatDelta(_ delta: Double, unit: TrendUnit) -> String {
        let sign = delta >= 0 ? "+" : "−"
        switch unit {
        case .percent:
            let value = abs(delta * 100)
            let formatted = value >= 10 ? String(format: "%.0f", value) : String(format: "%.1f", value)
            return "\(sign)\(formatted) pts"
        case .count:
            let value = abs(delta)
            let formatted = value >= 10 ? String(format: "%.0f", value) : String(format: "%.1f", value)
            return "\(sign)\(formatted)/day"
        }
    }

    func sectionHeaderCompact(_ title: String, icon: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                .tracking(0.6)
        }
    }
    
    func compactQueueRow(_ preview: SessionCuratorSnapshot.QueuePreview) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text(preview.concept)
                    .font(DesignSystem.Typography.smallMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.secondaryText.opacity(0.12))
                    )
                
                if let companion = preview.companionConcept {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    
                    Text(companion)
                        .font(DesignSystem.Typography.small)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.subtleOverlay)
                        )
                }
                
                Spacer()
                
                Text(percentString(preview.predictedRecall))
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            
            Text(preview.prompt)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .lineLimit(2)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
        )
    }
    
    func compactWeaveRow(_ weave: SessionCuratorSnapshot.ConceptWeave) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(weave.primaryConcept)
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    
                    if !weave.supportingConcepts.isEmpty {
                        Text("+\(weave.supportingConcepts.count)")
                            .font(DesignSystem.Typography.small)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    }
                }
                
                Text(weave.strategyLabel)
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("\(weave.dueCount)")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(DesignSystem.Colors.primaryText)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.lightOverlay.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
        )
    }
    
    func emptyStateCompact(icon: String, message: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            
            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
    }
    
    func conceptChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(DesignSystem.Typography.smallMedium)
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }

    func percentString(_ value: Double) -> String {
        let clamped = min(max(value, 0), 1)
        return NumberFormatter.sidebarPercent.string(from: NSNumber(value: clamped)) ?? "—"
    }

    private func dashboardDailyProgress() -> Double {
        let target = settings.dailyReviewLimit
        guard target > 0 else { return 1.0 }
        let progress = Double(reviewMetrics.reviewsCompleted) / Double(target)
        return min(max(progress, 0.0), 1.0)
    }

    private var deckLookup: [UUID: Deck] {
        Dictionary(uniqueKeysWithValues: decks.map { ($0.id, $0) })
    }

    private var suggestedDeckPlan: (deck: Deck, plan: StudyPlanSummary)? {
        var candidate: (deck: Deck, plan: StudyPlanSummary)?
        for summary in workspacePlan {
            guard (summary.dueToday > 0 || summary.totalScheduled > 0),
                  let deck = deckLookup[summary.deckId] else { continue }
            let next = (deck: deck, plan: summary)
            guard let current = candidate else {
                candidate = next
                continue
            }
            if next.plan.dueToday > current.plan.dueToday ||
                (next.plan.dueToday == current.plan.dueToday && next.plan.totalScheduled > current.plan.totalScheduled) {
                candidate = next
            }
        }
        return candidate
    }

    private var focusSessionData: FocusSession? {
        if let preview = sessionSnapshot.queuePreview.first {
            return FocusSession(
                deckName: "Smart Review",
                dueCount: sessionSnapshot.totalDue,
                nextConcept: preview.concept,
                color: emphasisColor(preview.emphasis)
            )
        }
        if let candidate = suggestedDeckPlan {
            let concept = candidate.plan.newToday > 0
                ? "\(candidate.plan.newToday) new waiting"
                : "Ready to study"
            let dueCount = max(candidate.plan.dueToday, candidate.plan.totalScheduled)
            return FocusSession(
                deckName: candidate.deck.name,
                dueCount: dueCount,
                nextConcept: concept,
                color: deckEnergy(for: candidate.deck).map(energyColor) ?? DesignSystem.Colors.accent
            )
        }
        return nil
    }

    private var continueSessionPreview: SessionPreview? {
        if let preview = sessionSnapshot.queuePreview.first {
            return SessionPreview(
                deckName: "Smart Review",
                concept: preview.prompt.isEmpty ? preview.concept : preview.prompt,
                dueString: dueDescription(for: preview.dueInHours)
            )
        }
        if let candidate = suggestedDeckPlan {
            let concept: String
            if candidate.plan.newToday > 0 {
                concept = "\(candidate.plan.newToday) new queued"
            } else if candidate.plan.totalScheduled > 0 {
                concept = "\(candidate.plan.totalScheduled) upcoming"
            } else {
                concept = "Ready to study"
            }
            let dueLabel: String
            if candidate.plan.dueToday > 0 {
                dueLabel = candidate.plan.dueToday == 1 ? "1 due today" : "\(candidate.plan.dueToday) due today"
            } else if candidate.plan.totalScheduled > 0 {
                dueLabel = "\(candidate.plan.totalScheduled) upcoming"
            } else {
                dueLabel = "On track"
            }
            return SessionPreview(
                deckName: candidate.deck.name,
                concept: concept,
                dueString: dueLabel
            )
        }
        return nil
    }

    private func dueDescription(for hours: Double) -> String {
        if hours <= 0.25 { return "due now" }
        if hours < 24 { return "in \(Int(round(hours)))h" }
        let days = Int(round(hours / 24))
        return "in \(days)d"
    }

    private func deckEnergy(for deck: Deck) -> AdaptiveNavigatorSnapshot.Energy? {
        navigatorSnapshot.deckNodes.first(where: { $0.deckId == deck.id })?.energy
    }

    private func energyColor(for energy: AdaptiveNavigatorSnapshot.Energy) -> Color {
        switch energy {
        case .focus: return Color.red
        case .calibrate: return DesignSystem.Colors.studyAccentBright
        case .accelerate: return Color.green
        }
    }

    private func emphasisColor(_ emphasis: SessionCuratorSnapshot.QueuePreview.Emphasis) -> Color {
        switch emphasis {
        case .focus: return Color.red
        case .contrast: return Color.orange
        case .reinforce: return Color.green
        }
    }



    func loadSnapshotsPhased() async {
        // Prevent concurrent loads
        guard loadingPhase == .initial || loadingPhase == .complete else { return }
        
        // Reset to initial for reload
        if loadingPhase == .complete {
            await MainActor.run { loadingPhase = .initial }
        }
        
        let service = LearningIntelligenceService(storage: storage)
        let planner = StudyPlanService(storage: storage)
        let reviewLogs = ReviewLogService(storage: storage)
        let deckService = DeckService(storage: storage)
        
        // PHASE 1: Core data (fast - snapshots, decks, settings)
        // These are lightweight and should display almost immediately
        async let snapshotsTask = service.combinedSnapshots()
        async let decksTask = deckService.allDecks(includeArchived: false)
        async let settingsTask = storage.loadSettings()
        
        let (session, navigator) = await snapshotsTask
        let fetchedDecks = await decksTask
        let settingsDTO = try? await settingsTask
        let userSettings = settingsDTO?.toDomain() ?? UserSettings()
        
        // Check for cancellation
        if Task.isCancelled { return }
        
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.15)) {
                sessionSnapshot = session
                navigatorSnapshot = navigator
                decks = fetchedDecks
                settings = userSettings
                loadingPhase = .coreData
            }
        }
        
        // PHASE 2: Plan data (medium - workspace forecast + course plan)
        let plans = await planner.workspaceForecast()

        if Task.isCancelled { return }

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.15)) {
                workspacePlan = plans
                loadingPhase = .planData
            }
        }
        
        // PHASE 3: Analytics (slow - heavy computation done off main thread)
        let logs = await reviewLogs.recentLogs(limit: 5_000)
        
        if Task.isCancelled { return }
        
        // Compute analytics on a background thread to avoid blocking UI
        let referenceDate = Date()
        let analytics = await Task.detached(priority: .userInitiated) {
            self.buildReviewAnalytics(from: logs, referenceDate: referenceDate)
        }.value
        
        if Task.isCancelled { return }
        
        await MainActor.run {
            withAnimation(DesignSystem.Animation.smooth) {
                reviewMetrics = analytics.today
                reviewHistory = analytics.timeline
                reviewHeatmap = analytics.heatmap
                reviewStreak = analytics.streak
                retentionTrend = analytics.retentionTrend
                reviewVelocityTrend = analytics.reviewVelocityTrend
                learningTrend = analytics.learningTrend
                heatmapMaxCount = analytics.maxDailyReviewCount
                heatmapMaxLearned = analytics.maxDailyLearnedCount
                loadingPhase = .complete
            }
        }
    }
}

private extension LearningIntelligenceView {
    private nonisolated func buildReviewAnalytics(from logs: [ReviewLog], referenceDate: Date) -> ReviewAnalytics {
        guard !logs.isEmpty else { return .empty }
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: referenceDate)
        let daySpan = 147 // 21 weeks of history for visualizations

        struct DayAccumulator {
            var reviewCount: Int = 0
            var learnedCount: Int = 0
            var seconds: Int = 0
            var successCount: Int = 0
        }

        var buckets: [Date: DayAccumulator] = [:]

        for log in logs {
            let day = calendar.startOfDay(for: log.timestamp)
            var accumulator = buckets[day] ?? DayAccumulator()
            accumulator.reviewCount += 1
            if log.prevInterval == 0 {
                accumulator.learnedCount += 1
            }
            accumulator.seconds += max(0, log.elapsedMs) / 1000
            if let grade = ReviewGrade(rawValue: log.grade), grade != .again {
                accumulator.successCount += 1
            }
            buckets[day] = accumulator
        }

        guard let start = calendar.date(byAdding: .day, value: -(daySpan - 1), to: anchorDay) else {
            return .empty
        }

        var timeline: [DailyReviewSummary] = []
        timeline.reserveCapacity(daySpan)

        var totalReviews = 0
        var totalLearned = 0
        var totalSeconds = 0

        var cursor = start
        while cursor <= anchorDay {
            let stats = buckets[cursor] ?? DayAccumulator()
            let retention = stats.reviewCount > 0 ? Double(stats.successCount) / Double(stats.reviewCount) : 0
            timeline.append(
                DailyReviewSummary(
                    date: cursor,
                    reviewCount: stats.reviewCount,
                    learnedCount: stats.learnedCount,
                    totalSeconds: stats.seconds,
                    successCount: stats.successCount,
                    retention: retention
                )
            )
            totalReviews += stats.reviewCount
            totalLearned += stats.learnedCount
            totalSeconds += stats.seconds
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let todayStats = buckets[anchorDay] ?? DayAccumulator()
        let todayMetrics = ReviewDayMetrics(
            cardsLearned: todayStats.learnedCount,
            reviewsCompleted: todayStats.reviewCount,
            totalReviewSeconds: todayStats.seconds
        )

        let heatmapWeeks = buildHeatmapWeeks(
            from: timeline,
            anchorDay: anchorDay,
            calendar: calendar
        )

        let streak = buildStreakMetrics(
            from: timeline,
            anchorDay: anchorDay,
            totalReviews: totalReviews,
            totalLearned: totalLearned,
            totalSeconds: totalSeconds,
            calendar: calendar
        )

        let retentionTrend = buildRollingRetention(for: timeline, window: 7)
        let velocityTrend = buildRollingAverage(for: timeline, keyPath: \.reviewCount, window: 7)
        let learningTrend = buildRollingAverage(for: timeline, keyPath: \.learnedCount, window: 7)

        let maxDailyReviews = timeline.map(\.reviewCount).max() ?? 0
        let maxDailyLearned = timeline.map(\.learnedCount).max() ?? 0

        return ReviewAnalytics(
            today: todayMetrics,
            timeline: timeline,
            heatmap: heatmapWeeks,
            streak: streak,
            retentionTrend: retentionTrend,
            reviewVelocityTrend: velocityTrend,
            learningTrend: learningTrend,
            maxDailyReviewCount: maxDailyReviews,
            maxDailyLearnedCount: maxDailyLearned
        )
    }

    private func buildHeatmapWeeks(
        from timeline: [DailyReviewSummary],
        anchorDay: Date,
        calendar: Calendar
    ) -> [HeatmapWeek] {
        guard !timeline.isEmpty else { return [] }

        var weeks: [HeatmapWeek] = []
        weeks.reserveCapacity(timeline.count / 7)

        var currentDays: [HeatmapWeek.Day] = []
        currentDays.reserveCapacity(7)

        var currentWeekStart = timeline.first?.date ?? anchorDay

        for entry in timeline {
            if currentDays.count == 0 {
                currentWeekStart = entry.date
            }

            currentDays.append(
                HeatmapWeek.Day(
                    date: entry.date,
                    reviewCount: entry.reviewCount,
                    learnedCount: entry.learnedCount,
                    isFuture: entry.date > anchorDay
                )
            )

            if currentDays.count == 7 {
                weeks.append(HeatmapWeek(startOfWeek: currentWeekStart, days: currentDays))
                currentDays.removeAll(keepingCapacity: true)
            }
        }

        if !currentDays.isEmpty {
            var padded = currentDays
            while padded.count < 7, let next = calendar.date(byAdding: .day, value: 1, to: padded.last?.date ?? currentWeekStart) {
                padded.append(
                    HeatmapWeek.Day(
                        date: next,
                        reviewCount: 0,
                        learnedCount: 0,
                        isFuture: next > anchorDay
                    )
                )
            }
            weeks.append(HeatmapWeek(startOfWeek: currentWeekStart, days: padded))
        }

        return weeks
    }

    private func buildStreakMetrics(
        from timeline: [DailyReviewSummary],
        anchorDay: Date,
        totalReviews: Int,
        totalLearned: Int,
        totalSeconds: Int,
        calendar: Calendar
    ) -> ReviewStreak {
        guard !timeline.isEmpty else { return .empty }

        let summaryByDate = Dictionary(uniqueKeysWithValues: timeline.map { ($0.date, $0) })

        var currentRun = 0
        var bestRun = 0
        var previousActiveDay: Date?

        for entry in timeline where entry.reviewCount > 0 {
            if let previous = previousActiveDay,
               let expected = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(entry.date, inSameDayAs: expected) {
                currentRun += 1
            } else {
                currentRun = 1
            }
            bestRun = max(bestRun, currentRun)
            previousActiveDay = entry.date
        }

        var currentStreak = 0
        var cursor = anchorDay
        while let summary = summaryByDate[cursor], summary.reviewCount > 0 {
            currentStreak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }

        let activeDays = timeline.filter { $0.reviewCount > 0 }.count
        let averageSessionSeconds = activeDays > 0 ? Double(totalSeconds) / Double(activeDays) : 0

        return ReviewStreak(
            current: currentStreak,
            best: bestRun,
            activeDays: activeDays,
            totalReviews: totalReviews,
            totalLearned: totalLearned,
            averageSessionSeconds: averageSessionSeconds
        )
    }

    private func buildRollingAverage<T>(
        for timeline: [DailyReviewSummary],
        keyPath: KeyPath<DailyReviewSummary, T>,
        window: Int
    ) -> [TrendSample] where T: BinaryInteger {
        guard !timeline.isEmpty else { return [] }
        return timeline.enumerated().map { index, entry in
            let lowerBound = max(0, index - window + 1)
            let slice = timeline[lowerBound...index]
            let total = slice.reduce(0.0) { $0 + Double($1[keyPath: keyPath]) }
            let value = total / Double(slice.count)
            return TrendSample(date: entry.date, value: value)
        }
    }

    private func buildRollingRetention(
        for timeline: [DailyReviewSummary],
        window: Int
    ) -> [TrendSample] {
        guard !timeline.isEmpty else { return [] }
        return timeline.enumerated().map { index, entry in
            let lowerBound = max(0, index - window + 1)
            let slice = timeline[lowerBound...index]
            let totalReviews = slice.reduce(0) { $0 + $1.reviewCount }
            let totalSuccess = slice.reduce(0) { $0 + $1.successCount }
            let value = totalReviews > 0 ? Double(totalSuccess) / Double(totalReviews) : 0
            return TrendSample(date: entry.date, value: value)
        }
    }

    func formattedDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0s" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, remainingSeconds)
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

private extension SessionCuratorSnapshot.ConceptWeave {
    var strategyLabel: String {
        switch strategy {
        case .contrast:
            return "Contrast for sharper discrimination"
        case .reinforce:
            return "Reinforce existing patterns"
        case .expand:
            return "Expand with adjacent ideas"
        }
    }
}

private extension View {
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Shimmer Effect for Loading States

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

private extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

#if DEBUG
#Preview("LearningIntelligenceView") {
    RevuPreviewHost { _ in
        LearningIntelligenceView()
            .frame(width: 1200, height: 820)
    }
}
#endif
