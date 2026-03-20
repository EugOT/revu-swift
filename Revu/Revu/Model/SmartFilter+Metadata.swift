import Foundation

extension SmartFilter {
    var symbol: String {
        switch self {
        case .dueToday: return "calendar"
        case .new: return "sparkles"
        case .suspended: return "pause.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .dueToday:
            return "Cards scheduled before midnight"
        case .new:
            return "Freshly created and unstudied"
        case .suspended:
            return "Paused cards awaiting review"
        }
    }

    var searchKeywords: [String] {
        switch self {
        case .dueToday: return ["due", "today", "reviews", "overdue"]
        case .new: return ["new", "fresh", "unseen"]
        case .suspended: return ["suspended", "paused", "hold"]
        }
    }
}
