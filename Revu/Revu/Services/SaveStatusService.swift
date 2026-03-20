import Foundation
import Combine

@MainActor
@Observable
final class SaveStatusService {
    enum Status {
        case idle
        case saving
        case saved
        case error
    }

    private(set) var status: Status = .idle

    private var storeEventsCancellable: AnyCancellable?
    private var fadeTask: Task<Void, Never>?

    func observe(_ storeEvents: StoreEvents) {
        storeEventsCancellable = storeEvents.$tick
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleStoreEvent()
            }
    }

    private func handleStoreEvent() {
        fadeTask?.cancel()
        status = .saving

        fadeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            guard !Task.isCancelled, let self else { return }
            self.status = .saved

            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            guard !Task.isCancelled else { return }
            self.status = .idle
        }
    }

    func reportError() {
        fadeTask?.cancel()
        status = .error
    }
}
