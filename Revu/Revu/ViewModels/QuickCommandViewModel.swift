import Foundation
import Combine

@MainActor
final class QuickCommandViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            guard !isPriming else { return }
            runSearch(for: query)
        }
    }
    @Published private(set) var results: [QuickCommandResult] = []
    @Published private(set) var isLoading = false

    private let searchService: SearchService
    private var searchTask: Task<Void, Never>?
    private var isPriming = false

    init(searchService: SearchService? = nil) {
        self.searchService = searchService ?? SearchService()
    }

    deinit {
        searchTask?.cancel()
    }

    func prepare() {
        isPriming = true
        query = ""
        isPriming = false
        searchTask?.cancel()
        searchTask = Task {
            await MainActor.run { isLoading = true }
            let results = await searchService.search(query: "")
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.results = results
                self.isLoading = false
            }
        }
    }

    private func runSearch(for text: String) {
        searchTask?.cancel()
        searchTask = Task {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { isLoading = true }
            let results = await searchService.search(query: trimmed)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.results = results
                self.isLoading = false
            }
        }
    }
}
