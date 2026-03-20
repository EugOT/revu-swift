import Foundation
import Combine

/// Shared preferences for workspace-level UI affordances.
final class WorkspacePreferences: ObservableObject {
    @Published var showTagColumn: Bool {
        didSet { persist() }
    }
    
    @Published var cardViewMode: CardViewMode {
        didSet { persist() }
    }

    @Published var deckSortFilter: DeckSortFilter {
        didSet { persist() }
    }

    @Published var cardSizeScale: Double {
        didSet { persist() }
    }

    private let userDefaults: UserDefaults
    private let tagColumnKey = "workspace.showTagColumn"
    private let viewModeKey = "workspace.cardViewMode"
    private let sortFilterKey = "workspace.deckSortFilter"
    private let cardSizeScaleKey = "workspace.cardSizeScale"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if userDefaults.object(forKey: tagColumnKey) != nil {
            self.showTagColumn = userDefaults.bool(forKey: tagColumnKey)
        } else {
            self.showTagColumn = true
        }

        if let rawValue = userDefaults.string(forKey: viewModeKey),
           let mode = CardViewMode(rawValue: rawValue) {
            self.cardViewMode = mode
        } else {
            self.cardViewMode = .grid
        }

        if let data = userDefaults.data(forKey: sortFilterKey),
           let filter = try? JSONDecoder().decode(DeckSortFilter.self, from: data) {
            self.deckSortFilter = filter
        } else {
            self.deckSortFilter = DeckSortFilter()
        }

        self.cardSizeScale = userDefaults.object(forKey: "workspace.cardSizeScale") != nil
            ? userDefaults.double(forKey: "workspace.cardSizeScale")
            : 0.5
    }

    private func persist() {
        userDefaults.set(showTagColumn, forKey: tagColumnKey)
        userDefaults.set(cardViewMode.rawValue, forKey: viewModeKey)
        if let data = try? JSONEncoder().encode(deckSortFilter) {
            userDefaults.set(data, forKey: sortFilterKey)
        }
        userDefaults.set(cardSizeScale, forKey: cardSizeScaleKey)
    }
}

enum CardViewMode: String, CaseIterable, Identifiable {
    case grid
    case notebook
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .grid: return "Grid"
        case .notebook: return "Notebook"
        }
    }
    
    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .notebook: return "book.closed"
        }
    }
}

/// Tracks selection context across canvas and inspector surfaces.
final class WorkspaceSelection: ObservableObject {
    @Published private(set) var focusedCard: Card? {
        didSet { focusedCardID = focusedCard?.id }
    }

    private var focusedCardID: UUID?

    func focus(on card: Card?) {
        guard focusedCard?.id != card?.id || focusedCard != card else { return }
        focusedCard = card
    }

    func clearCard() {
        focus(on: nil)
    }

    func restoreCard(in cards: [Card]) {
        guard let id = focusedCardID else { return }
        let candidate = cards.first { $0.id == id }
        focus(on: candidate)
    }

    func prepareFocus(cardID: UUID) {
        focusedCardID = cardID
        focusedCard = nil
    }
}

/// Tracks navigation history for back/forward navigation.
final class WorkspaceNavigationHistory: ObservableObject {
    @Published private(set) var stack: [SidebarItem] = []
    @Published private(set) var cursor: Int = -1
    
    var canGoBack: Bool {
        cursor > 0
    }
    
    var canGoForward: Bool {
        cursor < stack.count - 1
    }
    
    func push(_ item: SidebarItem) {
        // If we're not at the end, truncate forward history
        if cursor < stack.count - 1 {
            stack = Array(stack[0...cursor])
        }
        
        // Don't push duplicate if it's the same as current
        if let current = current, current == item {
            return
        }
        
        stack.append(item)
        cursor = stack.count - 1
    }
    
    func goBack() -> SidebarItem? {
        guard canGoBack else { return nil }
        cursor -= 1
        return stack[cursor]
    }
    
    func goForward() -> SidebarItem? {
        guard canGoForward else { return nil }
        cursor += 1
        return stack[cursor]
    }
    
    var current: SidebarItem? {
        guard cursor >= 0 && cursor < stack.count else { return nil }
        return stack[cursor]
    }
}

/// Broadcasts workspace-level command invocations (e.g., Quick Find).
final class WorkspaceCommandCenter: ObservableObject {
    @Published private(set) var quickFindToken: Int = 0
    @Published private(set) var onboardingToken: Int = 0

    func openQuickFind() {
        quickFindToken &+= 1
    }

    func presentOnboarding() {
        onboardingToken &+= 1
    }
}
