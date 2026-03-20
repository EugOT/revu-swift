import Foundation

enum QuickCommandAction: Hashable {
    case openDeck(UUID)
    case openCard(cardId: UUID, deckId: UUID?)
    case filterTag(String)
    case smartFilter(SmartFilter)
    case openStats
    case openSettings
}

struct QuickCommandResult: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let badge: String?
    let action: QuickCommandAction

    init(id: String, title: String, subtitle: String? = nil, icon: String, badge: String? = nil, action: QuickCommandAction) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.badge = badge
        self.action = action
    }
}
