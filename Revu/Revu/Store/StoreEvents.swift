import Foundation
import Combine

@MainActor
final class StoreEvents: ObservableObject {
    @Published private(set) var tick: Int = 0
    private var pendingNotifyTask: Task<Void, Never>?

    func notify() {
        // Coalesce bursts (e.g. large imports) into a single UI refresh.
        guard pendingNotifyTask == nil else { return }
        pendingNotifyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 60_000_000) // ~1-2 frames on most displays
            guard let self else { return }
            tick &+= 1
            pendingNotifyTask = nil
        }
    }
}

enum StoreEvent {
    case decksChanged
    case cardsChanged
    case settingsChanged
    case reviewLogsChanged
    case examsChanged
    case studyGuidesChanged
    case coursesChanged
}
