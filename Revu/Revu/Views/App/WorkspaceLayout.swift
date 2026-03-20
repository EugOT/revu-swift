import SwiftUI

/// Flexible three-surface layout that mirrors the Notion workspace arrangement.
struct WorkspaceLayout<Sidebar: View, Canvas: View, Inspector: View>: View {
    private enum SidebarConstants {
        static var compactWidth: CGFloat { 224 }
        static var dragHandleWidth: CGFloat { 10 }
        static var hiddenRevealWidth: CGFloat { 10 }
        static var hiddenSnapThreshold: CGFloat { 120 }
    }

    private let sidebar: Sidebar
    private let canvas: Canvas
    private let inspector: Inspector?
    @Binding private var sidebarPresentation: SidebarPresentation
    @Binding private var sidebarExpandedWidth: CGFloat
    @Binding private var isInspectorVisible: Bool
    private let inspectorAvailable: Bool
    @State private var sidebarDragWidth: CGFloat?
    @State private var sidebarDragStartWidth: CGFloat = 0
    @State private var sidebarHideTask: Task<Void, Never>?

    init(
        sidebarPresentation: Binding<SidebarPresentation>,
        sidebarExpandedWidth: Binding<CGFloat>,
        isInspectorVisible: Binding<Bool>,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder canvas: () -> Canvas,
        @ViewBuilder inspector: () -> Inspector?
    ) {
        self._sidebarPresentation = sidebarPresentation
        self._sidebarExpandedWidth = sidebarExpandedWidth
        self._isInspectorVisible = isInspectorVisible
        self.sidebar = sidebar()
        self.canvas = canvas()
        let inspectorView = inspector()
        self.inspector = inspectorView
        self.inspectorAvailable = inspectorView != nil
    }

    init(
        sidebarPresentation: Binding<SidebarPresentation>,
        sidebarExpandedWidth: Binding<CGFloat>,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder canvas: () -> Canvas
    ) where Inspector == EmptyView {
        self._sidebarPresentation = sidebarPresentation
        self._sidebarExpandedWidth = sidebarExpandedWidth
        self._isInspectorVisible = .constant(false)
        self.sidebar = sidebar()
        self.canvas = canvas()
        self.inspector = nil
        self.inspectorAvailable = false
    }

    var body: some View {
        GeometryReader { geometry in
            let windowWidth = geometry.size.width
            let expandedMinWidth = expandedSidebarMinWidth(for: windowWidth)
            let expandedMaxWidth = expandedSidebarMaxWidth(for: windowWidth)
            let clampedExpandedWidth = min(max(sidebarExpandedWidth, expandedMinWidth), expandedMaxWidth)
            let compactWidth = compactSidebarWidth(for: windowWidth)

            let baseSidebarWidth: CGFloat = switch sidebarPresentation {
            case .hidden:
                0
            case .compact:
                compactWidth
            case .expanded:
                clampedExpandedWidth
            }

            let effectiveSidebarWidth = sidebarDragWidth ?? baseSidebarWidth
            let shouldShowSidebar = sidebarPresentation.isVisible || sidebarDragWidth != nil
            let sidebarDragGesture = DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    sidebarHideTask?.cancel()
                    sidebarHideTask = nil

                    if sidebarDragWidth == nil {
                        sidebarDragStartWidth = baseSidebarWidth
                        sidebarDragWidth = baseSidebarWidth

                        if sidebarPresentation == .hidden {
                            sidebarPresentation = .compact
                        }
                    }

                    let proposedWidth = sidebarDragStartWidth + value.translation.width
                    let clampedWidth = min(max(proposedWidth, 0), expandedMaxWidth)
                    sidebarDragWidth = clampedWidth
                }
                .onEnded { value in
                    let proposedWidth = sidebarDragStartWidth + value.translation.width
                    let clampedWidth = min(max(proposedWidth, 0), expandedMaxWidth)

                    if clampedWidth < SidebarConstants.hiddenSnapThreshold {
                        withAnimation(DesignSystem.Animation.snappy) {
                            sidebarDragWidth = 0
                        }
                        sidebarHideTask?.cancel()
                        sidebarHideTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 180_000_000)
                            guard !Task.isCancelled else { return }
                            withAnimation(DesignSystem.Animation.snappy) {
                                sidebarPresentation = .hidden
                                sidebarDragWidth = nil
                            }
                        }
                        return
                    }

                    let resolvedWidth = min(max(clampedWidth, expandedMinWidth), expandedMaxWidth)
                    withAnimation(DesignSystem.Animation.snappy) {
                        sidebarPresentation = .expanded
                        sidebarExpandedWidth = resolvedWidth
                        sidebarDragWidth = nil
                    }
                }

            HStack(spacing: 0) {
                if shouldShowSidebar {
                    sidebar
                        .frame(width: max(effectiveSidebarWidth, 0))
                        .frame(maxHeight: .infinity)
                        .workspaceSidebarSurface()
                        .overlay(alignment: .trailing) {
                            sidebarResizeHandle()
                                .gesture(sidebarDragGesture)
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .workspaceCanvasSurface()
                    .overlay(alignment: .trailing) {
                        if inspectorAvailable, isInspectorVisible, let inspector, shouldShowInspector(for: geometry.size.width) {
                            HStack(spacing: 0) {
                                divider()
                                inspector
                                    .frame(width: responsiveInspectorWidth(for: geometry.size.width))
                                    .frame(maxHeight: .infinity)
                                    .workspaceInspectorSurface()
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(DesignSystem.Animation.layout, value: isInspectorVisible)
            }
            .background(DesignSystem.Colors.canvasBackground)
            .overlay(alignment: .leading) {
                if !shouldShowSidebar, sidebarPresentation == .hidden {
                    Color.clear
                        .frame(width: SidebarConstants.hiddenRevealWidth)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(sidebarDragGesture)
                }
            }
            .transaction { t in
                if sidebarDragWidth != nil {
                    t.animation = nil
                }
            }
            .animation(DesignSystem.Animation.layout, value: sidebarPresentation)
        }
    }
    
    // MARK: - Responsive Layout Helpers
    
    private func compactSidebarWidth(for windowWidth: CGFloat) -> CGFloat {
        let maxCompact = min(SidebarConstants.compactWidth, windowWidth * 0.4)
        return max(168, maxCompact)
    }

    private func expandedSidebarMinWidth(for windowWidth: CGFloat) -> CGFloat {
        max(240, compactSidebarWidth(for: windowWidth))
    }

    private func expandedSidebarMaxWidth(for windowWidth: CGFloat) -> CGFloat {
        max(expandedSidebarMinWidth(for: windowWidth), min(420, windowWidth * 0.45))
    }
    
    private func responsiveInspectorWidth(for windowWidth: CGFloat) -> CGFloat {
        switch windowWidth {
        case ..<1000:
            return 280
        default:
            return 320
        }
    }
    
    private func shouldShowInspector(for windowWidth: CGFloat) -> Bool {
        // Auto-hide inspector on very narrow windows
        windowWidth >= 900
    }

    @ViewBuilder
    private func divider() -> some View {
        Rectangle()
            .fill(DesignSystem.Colors.separator)
            .frame(width: 1)
            .allowsHitTesting(false)
    }

    private func sidebarResizeHandle() -> some View {
        ZStack {
            Color.clear
            SidebarGrabberDots()
                .foregroundStyle(DesignSystem.Colors.separator.opacity(0.8))
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
        }
        .frame(width: SidebarConstants.dragHandleWidth)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

private struct SidebarGrabberDots: View {
    var body: some View {
        HStack(spacing: 2) {
            dotsColumn()
            dotsColumn()
        }
        .padding(2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func dotsColumn() -> some View {
        VStack(spacing: 2) {
            dot()
            dot()
            dot()
        }
    }

    private func dot() -> some View {
        Circle()
            .frame(width: 2, height: 2)
    }
}

#if DEBUG
private struct WorkspaceLayoutPreview: View {
    @State private var sidebarPresentation: SidebarPresentation = .expanded
    @State private var sidebarWidth: CGFloat = 280
    @State private var isInspectorVisible: Bool = true

    var body: some View {
        WorkspaceLayout(
            sidebarPresentation: $sidebarPresentation,
            sidebarExpandedWidth: $sidebarWidth,
            isInspectorVisible: $isInspectorVisible,
            sidebar: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sidebar")
                        .font(.headline)
                    Toggle("Inspector", isOn: $isInspectorVisible)
                    Picker("Mode", selection: $sidebarPresentation) {
                        Text("Hidden").tag(SidebarPresentation.hidden)
                        Text("Compact").tag(SidebarPresentation.compact)
                        Text("Expanded").tag(SidebarPresentation.expanded)
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.sidebarBackground)
            },
            canvas: {
                ZStack {
                    DesignSystem.Colors.canvasBackground
                    Text("Canvas")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            },
            inspector: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Inspector")
                        .font(.headline)
                    Text("Resize me")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.inspectorBackground)
            }
        )
    }
}

#Preview("WorkspaceLayout") {
    WorkspaceLayoutPreview()
        .frame(width: 1200, height: 800)
}
#endif
