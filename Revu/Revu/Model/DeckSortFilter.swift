import Foundation

struct DeckSortFilter: Codable, Equatable {
    enum SortField: String, Codable, CaseIterable, Identifiable {
        case dueDate
        case createdDate
        case difficulty
        case alphabetical

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dueDate: return "Due Date"
            case .createdDate: return "Created"
            case .difficulty: return "Difficulty"
            case .alphabetical: return "A-Z"
            }
        }
    }

    enum FilterMode: String, Codable, CaseIterable, Identifiable {
        case all
        case dueNow
        case new
        case suspended

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .dueNow: return "Due"
            case .new: return "New"
            case .suspended: return "Suspended"
            }
        }
    }

    var sortField: SortField = .dueDate
    var ascending: Bool = true
    var filterMode: FilterMode = .all
}
