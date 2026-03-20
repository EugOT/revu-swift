import Foundation

enum SidebarPresentation: String, CaseIterable, Identifiable, Sendable {
    case hidden
    case compact
    case expanded

    var id: String { rawValue }

    var isVisible: Bool { self != .hidden }
}

