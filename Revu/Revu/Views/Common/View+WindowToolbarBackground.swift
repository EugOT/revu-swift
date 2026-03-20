import SwiftUI

extension View {
    @ViewBuilder
    func revuWindowToolbarBackgroundHidden() -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            // macOS 15+ (Sequoia): Disable new liquid glass/vibrancy effects
            self
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .containerBackground(.clear, for: .window)
        } else {
            toolbarBackground(.hidden, for: .windowToolbar)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func revuWindowToolbarBackground(_ color: Color) -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            self
                .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
                .toolbarBackground(color, for: .windowToolbar)
                .containerBackground(color, for: .window)
        } else {
            self
                .toolbarBackground(color, for: .windowToolbar)
        }
        #else
        self
        #endif
    }

}
