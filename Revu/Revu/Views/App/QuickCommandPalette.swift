import SwiftUI

struct QuickCommandPalette: View {
    @ObservedObject var viewModel: QuickCommandViewModel
    let onSelect: (QuickCommandResult) -> Void
    let onDismiss: () -> Void

    @State private var highlightedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search decks, cards, tags, or actions", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { commitSelection() }
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(DesignSystem.Colors.window.opacity(0.45))
            )

            Divider()

            if viewModel.results.isEmpty {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(viewModel.query.isEmpty ? "Type to jump anywhere" : "No matches")
                        .font(.headline)
                    if viewModel.query.isEmpty {
                        Text("Try searching for deck names, card fronts, tags, or actions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, result in
                            QuickCommandRow(result: result, isHighlighted: index == highlightedIndex)
                                .onTapGesture {
                                    highlightedIndex = index
                                    commitSelection()
                                }
                                .onHover { hovering in
                                    if hovering {
                                        highlightedIndex = index
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 520)
        .padding(DesignSystem.Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .shadow(
            color: Color(light: Color.black.opacity(0.08), dark: Color.black.opacity(0.4)),
            radius: 22,
            x: 0,
            y: 10
        )
        .onAppear {
            highlightedIndex = 0
            isSearchFocused = true
        }
        .onChange(of: viewModel.results) { _, newResults in
            if newResults.isEmpty {
                highlightedIndex = 0
            } else {
                highlightedIndex = min(highlightedIndex, newResults.count - 1)
            }
        }
        .onMoveCommand { direction in
            guard !viewModel.results.isEmpty else { return }
            switch direction {
            case .down:
                highlightedIndex = min(highlightedIndex + 1, viewModel.results.count - 1)
            case .up:
                highlightedIndex = max(highlightedIndex - 1, 0)
            default:
                break
            }
        }
        .onExitCommand(perform: onDismiss)
    }

    private func commitSelection() {
        guard highlightedIndex < viewModel.results.count else { return }
        let result = viewModel.results[highlightedIndex]
        onSelect(result)
    }
}

private struct QuickCommandRow: View {
    let result: QuickCommandResult
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: result.icon)
                .imageScale(.medium)
                .foregroundStyle(isHighlighted ? DesignSystem.Colors.accent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.body)
                    .fontWeight(isHighlighted ? .semibold : .regular)
                if let subtitle = result.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let badge = result.badge {
                Text(badge)
                    .font(.caption)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.accent.opacity(0.12))
                    )
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(isHighlighted ? DesignSystem.Colors.accent.opacity(0.15) : Color.clear)
        )
    }
}

#if DEBUG
#Preview("QuickCommandPalette") {
    RevuPreviewHost { controller in
        let viewModel = QuickCommandViewModel(searchService: SearchService(storage: controller.storage))
        Task { @MainActor in viewModel.prepare() }
        return QuickCommandPalette(
            viewModel: viewModel,
            onSelect: { _ in },
            onDismiss: {}
        )
        .frame(width: 560, height: 520)
        .padding()
        .background(DesignSystem.Colors.window)
    }
}
#endif
