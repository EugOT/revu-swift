import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// A reusable date picker surface styled to match the Revu design system.
/// Can be used for deck due dates, exam due dates, or any other date selection.
///
/// Features:
/// - Design-system-consistent styling (window surface, lg radius, separator borders)
/// - Optional quick actions (today, tomorrow, next week)
/// - Clear date functionality
/// - Graphical calendar picker
/// - Countdown display
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $isPresented) {
///     DesignSystemDatePickerSurface(
///         title: "Deck Due Date",
///         selectedDate: $dueDate,
///         allowClear: true,
///         helpText: "We'll adapt scheduling so your final review lands right before this date.",
///         onSave: { newDate in
///             await applyDueDate(newDate)
///         },
///         onDismiss: { isPresented = false }
///     )
/// }
/// ```
struct DesignSystemDatePickerSurface: View {
    let title: String
    @Binding var selectedDate: Date
    let allowClear: Bool
    let helpText: String?
    let onSave: (Date?) -> Void
    let onDismiss: () -> Void
    
    @State private var draftDate: Date
    @State private var hoveredPresetID: Preset.ID?
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        title: String,
        selectedDate: Binding<Date>,
        allowClear: Bool = true,
        helpText: String? = nil,
        onSave: @escaping (Date?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self._selectedDate = selectedDate
        self.allowClear = allowClear
        self.helpText = helpText
        self.onSave = onSave
        self.onDismiss = onDismiss
        self._draftDate = State(initialValue: Self.sanitizedStartOfDay(selectedDate.wrappedValue))
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.window.ignoresSafeArea()
            mainSurface
        }
        .frame(minWidth: 760, minHeight: 560)
        .modifier(ClearSheetBackground())
        .background(SheetWindowChromeClearer())
        .onAppear {
            print("[DatePicker] onAppear — selectedDate: \(selectedDate)")
            draftDate = Self.sanitizedStartOfDay(selectedDate)
        }
        .onChange(of: draftDate) { oldVal, newVal in
            print("[DatePicker] draftDate CHANGED: \(oldVal) → \(newVal)")
        }
    }
    
    // MARK: - Sections
    
    private var mainSurface: some View {
        VStack(spacing: 0) {
            headerRow
            
            Rectangle()
                .fill(DesignSystem.Colors.separator)
                .frame(height: 1)
            
            HStack(spacing: 0) {
                presetsColumn
                
                Rectangle()
                    .fill(DesignSystem.Colors.separator)
                    .frame(width: 1)
                
                calendarColumn
            }
            
            Rectangle()
                .fill(DesignSystem.Colors.separator)
                .frame(height: 1)
            
            footerRow
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xxl, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xxl, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .shadow(
            color: DesignSystem.Shadow.subtle(for: colorScheme).color,
            radius: DesignSystem.Shadow.subtle(for: colorScheme).radius,
            x: DesignSystem.Shadow.subtle(for: colorScheme).x,
            y: DesignSystem.Shadow.subtle(for: colorScheme).y
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Date picker")
    }
    
    private var headerRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(DesignSystem.Typography.heading)
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .lineLimit(1)
            
            Spacer()
            
            Text(draftDate.formatted(date: .abbreviated, time: .omitted))
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.lightOverlay)
    }
    
    private var presetsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Presets")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.8)
                
                Text(draftDate.formatted(date: .abbreviated, time: .omitted))
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .lineLimit(1)
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Rectangle()
                    .fill(DesignSystem.Colors.lightOverlay)
            )
            
            VStack(spacing: 4) {
                ForEach(presets) { preset in
                    presetRow(preset)
                }
            }
            .padding(DesignSystem.Spacing.sm)
            
            Spacer(minLength: 0)
        }
        .frame(width: 280)
    }
    
    private var calendarColumn: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    
                    Text(draftDate.formatted(date: .complete, time: .omitted))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    draftDate = Calendar.current.startOfDay(for: Date())
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .medium))
                        Text("Today")
                            .font(DesignSystem.Typography.smallMedium)
                    }
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .fill(DesignSystem.Colors.hoverBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Jump to today")
            }
            
            Spacer(minLength: 0)
            
            DesignSystemCalendarPicker(selection: $draftDate)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.lg)
    }
    
    private var footerRow: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            if let helpText {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        .padding(.top, 1)
                    
                    Text(helpText)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            if allowClear {
                Button(role: .destructive) {
                    onSave(nil)
                    onDismiss()
                } label: {
                    Text("Clear")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(Color.red.opacity(0.95))
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                                .fill(Color.red.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                                .stroke(Color.red.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            
            Button {
                onDismiss()
            } label: {
                Text("Cancel")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .fill(DesignSystem.Colors.hoverBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            
            Button {
                let safeDraft = Self.sanitizedStartOfDay(draftDate)
                let normalized = normalizedDueDate(safeDraft)
                print("[DatePicker] Save pressed — draftDate: \(draftDate), normalized: \(normalized), ti1970=\(normalized.timeIntervalSince1970)")
                selectedDate = safeDraft
                onSave(normalized)
                onDismiss()
            } label: {
                Text("Save")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.canvasBackground)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .fill(DesignSystem.Colors.primaryText)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .stroke(DesignSystem.Colors.separator.opacity(0.25), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.lightOverlay)
    }

    // MARK: - Helpers
    
    private static func sanitizedStartOfDay(_ date: Date) -> Date {
        if isReferenceSentinelOrNear(date) {
            print("[DatePicker] CLAMP: reference-date sentinel detected (raw): t=\(date.timeIntervalSinceReferenceDate)")
            return Calendar.current.startOfDay(for: Date())
        }

        let normalized = Calendar.current.startOfDay(for: date)
        if isReferenceSentinelOrNear(normalized) {
            print("[DatePicker] CLAMP: reference-date sentinel detected (normalized): t=\(normalized.timeIntervalSinceReferenceDate)")
            return Calendar.current.startOfDay(for: Date())
        }
        return normalized
    }

    private static func isReferenceSentinelOrNear(_ date: Date) -> Bool {
        abs(date.timeIntervalSinceReferenceDate) < 172_800
    }
    
    private var presets: [Preset] {
        [
            Preset(title: "Today", icon: "sun.max", date: Calendar.current.startOfDay(for: Date())),
            Preset(title: "Tomorrow", icon: "sunrise", date: startOfDayAdding(days: 1)),
            Preset(title: "This weekend", icon: "sparkles", date: nextWeekend(isNext: false)),
            Preset(title: "Next week", icon: "arrow.right", date: nextWeekStart()),
            Preset(title: "Next weekend", icon: "sparkles", date: nextWeekend(isNext: true)),
            Preset(title: "2 weeks", icon: "calendar", date: startOfDayAdding(days: 14)),
            Preset(title: "4 weeks", icon: "calendar", date: startOfDayAdding(days: 28))
        ]
    }
    
    private func presetRow(_ preset: Preset) -> some View {
        let isSelected = Calendar.current.isDate(preset.date, inSameDayAs: draftDate)
        let isHovered = hoveredPresetID == preset.id
        
        return Button {
            print("[DatePicker] Preset tapped: \(preset.title) → \(preset.date)")
            draftDate = preset.date
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(isSelected ? DesignSystem.Colors.studyAccentDeep.opacity(0.16) : DesignSystem.Colors.subtleOverlay)
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: preset.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? DesignSystem.Colors.studyAccentBright : DesignSystem.Colors.tertiaryText)
                }
                
                Text(preset.title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                Text(preset.trailingLabel)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .monospacedDigit()
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.studyAccentDeep.opacity(0.10) : (isHovered ? DesignSystem.Colors.hoverBackground : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .stroke(isSelected ? DesignSystem.Colors.studyAccentBorder : DesignSystem.Colors.separator.opacity(isHovered ? 0.9 : 0.0), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            withAnimation(DesignSystem.Animation.quick) {
                hoveredPresetID = isHovering ? preset.id : nil
            }
        }
        .accessibilityLabel("\(preset.title), \(preset.trailingLabel)")
    }
    
    private func startOfDayAdding(days: Int) -> Date {
        let target = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return Calendar.current.startOfDay(for: target)
    }
    
    private func nextWeekStart() -> Date {
        let calendar = Calendar.current
        let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfThisWeek) ?? Date()
        return calendar.startOfDay(for: nextWeek)
    }
    
    private func nextWeekend(isNext: Bool) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // Sunday=1 ... Saturday=7
        
        if !isNext, weekday == 7 || weekday == 1 {
            return today
        }
        
        let base = isNext ? nextWeekStart() : today
        let baseWeekday = calendar.component(.weekday, from: base)
        let daysUntilSaturday = (7 - baseWeekday + 7) % 7
        let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: base) ?? base
        return calendar.startOfDay(for: saturday)
    }
    
    private func normalizedDueDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        // Set to end of day (23:59:59)
        if let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) {
            return endOfDay
        }
        return date
    }
}

// MARK: - Calendar Picker

private struct DesignSystemCalendarPicker: View {
    @Binding var selection: Date
    @State private var displayedMonthStart: Date
    @State private var hoveredCellID: String?

    @Environment(\.colorScheme) private var colorScheme
    private let calendar = Calendar.current

    init(selection: Binding<Date>) {
        self._selection = selection
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: selection.wrappedValue)
        self._displayedMonthStart = State(initialValue: cal.date(from: comps) ?? cal.startOfDay(for: Date()))
    }
    
    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayedMonthStart) ?? DateInterval(start: displayedMonthStart, duration: 0)
    }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return formatter.string(from: displayedMonthStart)
    }
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = .current
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let firstWeekdayIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }
    
    private var gridDates: [Date] {
        let startOfMonth = monthInterval.start
        let weekdayOfStart = calendar.component(.weekday, from: startOfMonth)
        let weekdayIndex = (weekdayOfStart - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -weekdayIndex, to: startOfMonth) ?? startOfMonth
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(monthTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                HStack(spacing: 6) {
                    monthNavButton(systemName: "chevron.left") {
                        shiftMonth(by: -1)
                    }
                    monthNavButton(systemName: "chevron.right") {
                        shiftMonth(by: 1)
                    }
                }
            }
            
            // Weekday headers — separate from the date grid to avoid ID collisions
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(DesignSystem.Typography.smallMedium)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 2)
                }
            }

            // Date cells in their own grid — no shared ID namespace
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(gridDates, id: \.timeIntervalSinceReferenceDate) { date in
                    dayCell(date)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.canvasBackground.opacity(colorScheme == .dark ? 0.32 : 0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .stroke(DesignSystem.Colors.separator.opacity(0.75), lineWidth: 1)
        )
        .onAppear {
            displayedMonthStart = startOfMonth(for: selection)
        }
        .onChange(of: selection) { _, newValue in
            let newMonthStart = startOfMonth(for: newValue)
            if !calendar.isDate(newMonthStart, equalTo: displayedMonthStart, toGranularity: .month) {
                displayedMonthStart = newMonthStart
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar")
    }
    
    private func monthNavButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
                .frame(width: 26, height: 26)
                .background(DesignSystem.Colors.hoverBackground, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "chevron.left" ? "Previous month" : "Next month")
    }
    
    private func dayCell(_ date: Date) -> some View {
        let isInMonth = calendar.isDate(date, equalTo: displayedMonthStart, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(date)
        let cellID = cellIdentifier(for: date)
        let isHovered = hoveredCellID == cellID
        let cellCornerRadius = DesignSystem.Radius.md
        
        return Button {
            let newDate = calendar.startOfDay(for: date)
            print("[DatePicker] Calendar day tapped: \(newDate)")
            selection = newDate
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(foregroundColor(isInMonth: isInMonth, isSelected: isSelected))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                        .fill(backgroundFill(isSelected: isSelected, isHovered: isHovered))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                        .stroke(isToday && !isSelected ? DesignSystem.Colors.studyAccentBorder : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .opacity(isInMonth ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                hoveredCellID = hovering ? cellID : nil
            }
        }
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private func backgroundFill(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected {
            return DesignSystem.Colors.studyAccentDeep
        }
        if isHovered {
            return DesignSystem.Colors.hoverBackground
        }
        return .clear
    }
    
    private func foregroundColor(isInMonth: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return .white
        }
        if isInMonth {
            return DesignSystem.Colors.primaryText
        }
        return DesignSystem.Colors.secondaryText
    }
    
    private func shiftMonth(by delta: Int) {
        let shifted = calendar.date(byAdding: .month, value: delta, to: displayedMonthStart) ?? displayedMonthStart
        displayedMonthStart = startOfMonth(for: shifted)
    }
    
    private func startOfMonth(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }
    
    private func cellIdentifier(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }
}

// MARK: - Sheet Presentation

private struct ClearSheetBackground: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            content.presentationBackground(.clear)
        } else {
            content
        }
        #else
        if #available(iOS 16.0, tvOS 16.0, *) {
            content.presentationBackground(.clear)
        } else {
            content
        }
        #endif
    }
}

private struct SheetWindowChromeClearer: View {
    var body: some View {
        #if os(macOS)
        WindowAccessor { window in
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            
            if let contentView = window.contentView {
                clearLayeredBackgrounds(in: contentView)
            }
        }
        #else
        EmptyView()
        #endif
    }
    
    #if os(macOS)
    private func clearLayeredBackgrounds(in root: NSView) {
        var stack: [NSView] = [root]
        while let view = stack.popLast() {
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.clear.cgColor
            stack.append(contentsOf: view.subviews)
        }
    }
    #endif
}

#if os(macOS)
private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
#endif

// MARK: - Presets

private struct Preset: Identifiable {
    let title: String
    let icon: String
    let date: Date
    
    var id: String { title }
    
    var trailingLabel: String {
        let calendar = Calendar.current
        let target = date
        let today = calendar.startOfDay(for: Date())
        
        if calendar.isDate(target, inSameDayAs: today) {
            return dayOfWeekString(for: target)
        }
        
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if days > 0 && days <= 7 {
            return dayOfWeekString(for: target)
        }
        
        return shortDateString(for: target)
    }
    
    private func dayOfWeekString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }
    
    private func shortDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Components

/// Countdown display for due dates
private struct DueDateCountdownDisplay: View {
    let target: Date
    
    private var daysRemaining: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: target)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
    
    private var countdownColor: Color {
        if daysRemaining <= 0 { return .red }
        if daysRemaining <= 3 { return .orange }
        if daysRemaining <= 7 { return .blue }
        return .green
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.separator, lineWidth: 4)
                    .frame(width: 52, height: 52)
                
                Circle()
                    .trim(from: 0, to: min(1, Double(max(0, daysRemaining)) / 30.0))
                    .stroke(countdownColor.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                
                Text("\(max(0, daysRemaining))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(countdownText)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                Text(target.formatted(date: .complete, time: .omitted))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(countdownColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(countdownColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var countdownText: String {
        if daysRemaining <= 0 { return "Due today" }
        if daysRemaining == 1 { return "Due tomorrow" }
        return "\(daysRemaining) days remaining"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Date Picker Surface") {
    struct PreviewWrapper: View {
        @State private var selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        @State private var isPresented = true
        
        var body: some View {
            Button("Show Date Picker") {
                isPresented = true
            }
            .sheet(isPresented: $isPresented) {
                DesignSystemDatePickerSurface(
                    title: "Deck Due Date",
                    selectedDate: $selectedDate,
                    allowClear: true,
                    helpText: "We'll adapt scheduling so your final review lands right before this date.",
                    onSave: { newDate in
                        if let newDate {
                            print("Selected: \(newDate)")
                        } else {
                            print("Cleared")
                        }
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
            }
        }
    }
    
    return PreviewWrapper()
}
#endif
