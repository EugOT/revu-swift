import SwiftUI

struct ViewModeToggle: View {
    @Binding var mode: CardViewMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CardViewMode.allCases) { viewMode in
                DesignSystemTopBarIconButton(
                    icon: viewMode.icon,
                    action: { mode = viewMode },
                    help: viewMode.title
                )
                .opacity(mode == viewMode ? 1.0 : 0.5)
            }
        }
    }
}
