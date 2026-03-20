import SwiftUI

struct SortFilterButton: View {
    @Binding var sortFilter: DeckSortFilter
    @State private var isPopoverPresented = false

    var body: some View {
        DesignSystemTopBarIconButton(
            icon: "line.3.horizontal.decrease.circle",
            action: { isPopoverPresented.toggle() },
            help: "Sort & Filter"
        )
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            SortFilterPopoverContent(sortFilter: $sortFilter)
        }
    }
}

private struct SortFilterPopoverContent: View {
    @Binding var sortFilter: DeckSortFilter

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("SORT BY")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)

                ForEach(DeckSortFilter.SortField.allCases) { field in
                    Button(action: { sortFilter.sortField = field }) {
                        HStack {
                            Text(field.title)
                                .font(DesignSystem.Typography.smallMedium)
                            Spacer()
                            if sortFilter.sortField == field {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Button(action: { sortFilter.ascending.toggle() }) {
                HStack {
                    Text(sortFilter.ascending ? "Ascending" : "Descending")
                        .font(DesignSystem.Typography.smallMedium)
                    Spacer()
                    Image(systemName: sortFilter.ascending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            .buttonStyle(.plain)

            Divider()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("FILTER")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)

                ForEach(DeckSortFilter.FilterMode.allCases) { mode in
                    Button(action: { sortFilter.filterMode = mode }) {
                        HStack {
                            Text(mode.title)
                                .font(DesignSystem.Typography.smallMedium)
                            Spacer()
                            if sortFilter.filterMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(width: 200)
    }
}
