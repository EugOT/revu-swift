import SwiftUI
import Charts

struct StatsView: View {
    @Environment(\.storage) private var storage
    @EnvironmentObject private var storeEvents: StoreEvents
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var todayStats: DailyStats = .empty
    @State private var retentionValues: [RetentionEntry] = []
    @State private var forecast: [ForecastEntry] = []
    @State private var recallSummary: RecallSummary = .empty
    @State private var stabilityBuckets: [StabilityBucket] = []

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: responsiveSpacing(for: geometry.size.width)) {
                    Text("Statistics")
                        .font(.largeTitle)
                    summary(for: geometry.size.width)
                    adaptiveSection(for: geometry.size.width)
                    ChartsSection(title: "Retention (7 days)", data: retentionValues) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Retention", entry.retention)
                        )
                    }
                    ChartsSection(title: "Scheduled Cards (Next 14 days)", data: forecast) { entry in
                        BarMark(
                            x: .value("Date", entry.date),
                            y: .value("Cards", entry.count)
                        )
                    }
                }
                .padding(responsivePadding(for: geometry.size.width))
            }
        }
        .task { await refresh() }
        .onReceive(storeEvents.$tick) { _ in Task { await refresh() } }
    }
    
    // MARK: - Responsive Layout Helpers
    
    private func responsivePadding(for width: CGFloat) -> CGFloat {
        let base: CGFloat
        switch width {
        case ..<600:
            base = DesignSystem.Spacing.md
        case 600..<900:
            base = DesignSystem.Spacing.lg
        default:
            base = DesignSystem.Spacing.xl
        }
        return base * dynamicTypeSize.designSystemSpacingMultiplier
    }
    
    private func responsiveSpacing(for width: CGFloat) -> CGFloat {
        let base: CGFloat
        switch width {
        case ..<600:
            base = DesignSystem.Spacing.md
        default:
            base = DesignSystem.Spacing.lg
        }
        return base * dynamicTypeSize.designSystemSpacingMultiplier
    }

    private func summary(for width: CGFloat) -> some View {
        let columns = responsiveColumns(for: width)

        return LazyVGrid(columns: columns, alignment: .leading, spacing: responsiveGridSpacing(for: width)) {
            summaryTile(title: "Today's Reviews", value: "\(todayStats.reviewCount)", icon: "checkmark.circle", color: .blue)
            summaryTile(title: "New Cards", value: "\(todayStats.newCards)", icon: "sparkles", color: .purple)
            summaryTile(title: "Retention", value: String(format: "%.0f%%", todayStats.retention * 100), icon: "chart.line.uptrend.xyaxis", color: .green)
            summaryTile(title: "Time Spent", value: formattedTime(todayStats.timeSpent), icon: "clock", color: .orange)
        }
    }

    private func adaptiveSection(for width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Adaptive Scheduler Insights")
                .font(.headline)
            adaptiveSummaryTiles(for: width)
            if !stabilityBuckets.isEmpty {
                ChartsSection(title: "Stability Distribution", data: stabilityBuckets) { bucket in
                    BarMark(
                        x: .value("Stability", bucket.label),
                        y: .value("Cards", bucket.count)
                    )
                }
            }
        }
    }

    private func adaptiveSummaryTiles(for width: CGFloat) -> some View {
        let columns = responsiveColumns(for: width)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: responsiveGridSpacing(for: width)) {
            adaptiveTile(
                title: "Avg Recall",
                value: String(format: "%.0f%%", recallSummary.averageRecall * 100),
                subtitle: "If you studied now",
                icon: "brain",
                color: .teal
            )
            adaptiveTile(
                title: "Due Now",
                value: "\(recallSummary.dueCount)",
                subtitle: "Cards waiting for review",
                icon: "bolt.fill",
                color: .orange
            )
            adaptiveTile(
                title: "At Risk",
                value: "\(recallSummary.atRiskCount)",
                subtitle: "Below your retention goal",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
        }
    }
    
    private func responsiveColumns(for width: CGFloat) -> [GridItem] {
        let spacing = responsiveGridSpacing(for: width)
        switch width {
        case ..<600:
            // 2 columns on narrow screens
            return [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ]
        case 600..<900:
            // 2 columns on medium screens  
            return [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ]
        default:
            // 4 columns on wide screens
            return [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ]
        }
    }
    
    private func responsiveGridSpacing(for width: CGFloat) -> CGFloat {
        let base: CGFloat
        switch width {
        case ..<600:
            base = DesignSystem.Spacing.md
        default:
            base = DesignSystem.Spacing.lg
        }
        return base * dynamicTypeSize.designSystemSpacingMultiplier
    }

    private func summaryTile(title: String, value: String, icon: String, color: Color) -> some View {
        let stackSpacing = DesignSystem.Spacing.sm * dynamicTypeSize.designSystemSpacingMultiplier
        let headerSpacing = DesignSystem.Spacing.xs * dynamicTypeSize.designSystemSpacingMultiplier
        let tilePadding = DesignSystem.Spacing.lg * dynamicTypeSize.designSystemSpacingMultiplier

        return VStack(alignment: .leading, spacing: stackSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(color)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(color.opacity(0.12))
                    )
                
                Text(title.uppercased())
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            
            Text(value)
                .font(Font.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(tilePadding)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .shadow(
            color: Color(light: Color.black.opacity(0.03), dark: Color.black.opacity(0.3)),
            radius: 8,
            x: 0,
            y: 2
        )
    }

    private func adaptiveTile(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        let stackSpacing = DesignSystem.Spacing.sm * dynamicTypeSize.designSystemSpacingMultiplier
        let headerSpacing = DesignSystem.Spacing.xs * dynamicTypeSize.designSystemSpacingMultiplier
        let tilePadding = DesignSystem.Spacing.lg * dynamicTypeSize.designSystemSpacingMultiplier

        return VStack(alignment: .leading, spacing: stackSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(color)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(color.opacity(0.12))
                    )

                Text(title.uppercased())
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }

            Text(value)
                .font(Font.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(tilePadding)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .shadow(
            color: Color(light: Color.black.opacity(0.03), dark: Color.black.opacity(0.3)),
            radius: 8,
            x: 0,
            y: 2
        )
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%dm %ds", minutes, secs)
    }

    private func refresh() async {
        let logService = ReviewLogService(storage: storage)
        let cardService = CardService(storage: storage)
        let logs = await logService.recentLogs(limit: 5000)
        let cards = await cardService.allCards()
        let settings = (try? await DataController.shared.loadSettings()) ?? UserSettings()
        let calculatedToday = computeTodayStats(logs: logs)
        let retention = computeRetention(logs: logs)
        let schedule = computeForecast(cards: cards)
        let recall = computeRecallSummary(cards: cards, retentionTarget: settings.retentionTarget)
        let stability = computeStabilityBuckets(cards: cards)
        await MainActor.run {
            todayStats = calculatedToday
            retentionValues = retention
            forecast = schedule
            recallSummary = recall
            stabilityBuckets = stability
        }
    }

    private func computeTodayStats(logs: [ReviewLog]) -> DailyStats {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        let todaysLogs = logs.filter { $0.timestamp >= start && $0.timestamp < end }
        let reviewCount = todaysLogs.count
        let newCards = todaysLogs.filter { $0.prevInterval == 0 && $0.nextInterval > 0 }.count
        let correct = todaysLogs.filter { $0.grade >= 3 }.count
        let retention = reviewCount > 0 ? Double(correct) / Double(reviewCount) : 0.0
        let timeSpent = todaysLogs.reduce(0) { $0 + TimeInterval($1.elapsedMs) / 1000 }
        return DailyStats(reviewCount: reviewCount, newCards: newCards, retention: retention, timeSpent: timeSpent)
    }

    private func computeRetention(logs: [ReviewLog]) -> [RetentionEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let start = day
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let dayLogs = logs.filter { $0.timestamp >= start && $0.timestamp < end }
            let correct = dayLogs.filter { $0.grade >= 3 }.count
            let retention = dayLogs.isEmpty ? 0.0 : Double(correct) / Double(dayLogs.count)
            return RetentionEntry(date: start, retention: retention * 100)
        }
    }

    private func computeForecast(cards: [Card]) -> [ForecastEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries: [ForecastEntry] = []
        for offset in 0..<14 {
            let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            let start = day
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let count = cards.filter { !$0.isSuspended && $0.srs.dueDate >= start && $0.srs.dueDate < end }.count
            entries.append(ForecastEntry(date: start, count: count))
        }
        return entries
    }

    private func computeRecallSummary(cards: [Card], retentionTarget: Double) -> RecallSummary {
        let active = cards.filter { !$0.isSuspended }
        guard !active.isEmpty else { return .empty }
        let now = Date()
        var recallValues: [Double] = []
        var dueCount = 0
        var atRisk = 0
        for card in active {
            let recall = card.srs.predictedRecall(on: now, retentionTarget: retentionTarget)
            recallValues.append(recall)
            if card.srs.dueDate <= now {
                dueCount += 1
                if recall < retentionTarget {
                    atRisk += 1
                }
            }
        }
        let average = recallValues.isEmpty ? 0.0 : recallValues.reduce(0, +) / Double(recallValues.count)
        return RecallSummary(averageRecall: average, dueCount: dueCount, atRiskCount: atRisk)
    }

    private func computeStabilityBuckets(cards: [Card]) -> [StabilityBucket] {
        let active = cards.filter { !$0.isSuspended }
        guard !active.isEmpty else { return [] }
        let ranges: [(min: Double, max: Double?, label: String)] = [
            (0, 1, "<1d"),
            (1, 3, "1–3d"),
            (3, 7, "3–7d"),
            (7, 14, "1–2w"),
            (14, 30, "2–4w"),
            (30, 90, "1–3m"),
            (90, nil, "3m+")
        ]
        return ranges.map { range in
            let count = active.filter { card in
                let stability = card.srs.stability
                if let upper = range.max {
                    return stability >= range.min && stability < upper
                }
                return stability >= range.min
            }.count
            return StabilityBucket(label: range.label, count: count)
        }
    }
}

private struct DailyStats {
    let reviewCount: Int
    let newCards: Int
    let retention: Double
    let timeSpent: TimeInterval

    static let empty = DailyStats(reviewCount: 0, newCards: 0, retention: 0.0, timeSpent: 0)
}

private struct RecallSummary {
    let averageRecall: Double
    let dueCount: Int
    let atRiskCount: Int

    static let empty = RecallSummary(averageRecall: 0.0, dueCount: 0, atRiskCount: 0)
}

private struct RetentionEntry: Identifiable {
    let id = UUID()
    let date: Date
    let retention: Double
}

private struct ForecastEntry: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

private struct StabilityBucket: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

private struct ChartsSection<Data: RandomAccessCollection, Content: ChartContent>: View where Data.Element: Identifiable {
    let title: String
    let data: Data
    let content: (Data.Element) -> Content

    init(title: String, data: Data, @ChartContentBuilder content: @escaping (Data.Element) -> Content) {
        self.title = title
        self.data = data
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Chart(data) { entry in
                content(entry)
            }
            .frame(height: 240)
        }
    }
}

#if DEBUG
#Preview("StatsView") {
    RevuPreviewHost { _ in
        StatsView()
            .frame(width: 1200, height: 820)
    }
}
#endif
