import Foundation
import Combine

@MainActor
@Observable
final class StreakPillViewModel {
    struct StreakData: Equatable {
        var current: Int = 0
        var best: Int = 0
        var averageSessionSeconds: Double = 0
    }

    private(set) var streak = StreakData()
    private(set) var todayReviewed: Int = 0
    private(set) var todayDue: Int = 0

    private var storeEventsCancellable: AnyCancellable?
    private var refreshTask: Task<Void, Never>?
    private let storage: any Storage

    init(storage: any Storage) {
        self.storage = storage
    }

    func observe(_ storeEvents: StoreEvents) {
        storeEventsCancellable = storeEvents.$tick
            .sink { [weak self] _ in
                self?.scheduleRefresh()
            }
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled, let self else { return }
            await self.refresh()
        }
    }

    private func refresh() async {
        let dueCards = (try? await storage.dueCards(on: Date(), limit: nil)) ?? []
        todayDue = dueCards.count

        let logs = (try? await storage.recentLogs(limit: 5000)) ?? []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let todayLogs = logs.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
        todayReviewed = todayLogs.count

        streak = buildStreak(from: logs, anchorDay: today, calendar: calendar)
    }

    private nonisolated func buildStreak(
        from logs: [ReviewLogDTO],
        anchorDay: Date,
        calendar: Calendar
    ) -> StreakData {
        guard !logs.isEmpty else { return StreakData() }

        // Bucket logs by day
        struct DayBucket {
            var reviewCount: Int = 0
            var totalSeconds: Int = 0
        }

        var buckets: [Date: DayBucket] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.timestamp)
            var bucket = buckets[day] ?? DayBucket()
            bucket.reviewCount += 1
            bucket.totalSeconds += max(0, log.elapsedMs) / 1000
            buckets[day] = bucket
        }

        // Current streak: walk backwards from anchor day
        var currentStreak = 0
        var cursor = anchorDay
        while let bucket = buckets[cursor], bucket.reviewCount > 0 {
            currentStreak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }

        // Best streak: walk all days in order
        let sortedDays = buckets.keys.sorted()
        var bestRun = 0
        var currentRun = 0
        var previousDay: Date?

        for day in sortedDays where buckets[day]!.reviewCount > 0 {
            if let prev = previousDay,
               let expected = calendar.date(byAdding: .day, value: 1, to: prev),
               calendar.isDate(day, inSameDayAs: expected) {
                currentRun += 1
            } else {
                currentRun = 1
            }
            bestRun = max(bestRun, currentRun)
            previousDay = day
        }

        // Average session seconds
        let activeDays = buckets.values.filter { $0.reviewCount > 0 }.count
        let totalSeconds = buckets.values.reduce(0) { $0 + $1.totalSeconds }
        let avgSession = activeDays > 0 ? Double(totalSeconds) / Double(activeDays) : 0

        return StreakData(
            current: currentStreak,
            best: bestRun,
            averageSessionSeconds: avgSession
        )
    }
}
