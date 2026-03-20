import SwiftUI

struct BreadcrumbCrumb: Identifiable {
    let id: String
    let title: String
    let sidebarItem: SidebarItem? // nil for ellipsis
    let icon: String? // SF Symbol for page type

    init(id: String, title: String, sidebarItem: SidebarItem?, icon: String? = nil) {
        self.id = id
        self.title = title
        self.sidebarItem = sidebarItem
        self.icon = icon
    }
}

struct BreadcrumbNavView: View {
    let crumbs: [BreadcrumbCrumb]
    let onNavigate: (SidebarItem) -> Void
    let onQuickFind: () -> Void

    var body: some View {
        DesignSystemTopBarQuickFindTab(action: onQuickFind)
    }
}
