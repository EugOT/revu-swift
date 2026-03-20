import SwiftUI

struct ImportPreviewView: View {
    let preview: ImportPreview
    let existingDecks: [DeckMergeTarget]
    @Binding var mergePlan: DeckMergePlan
    let onImport: () -> Void
    let onCancel: () -> Void
    let overlayState: ImportOperationOverlayState?
    
    @State private var isAppearing = false

    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        headerSection
                            .padding(.horizontal, DesignSystem.Spacing.xl)
                            .padding(.top, DesignSystem.Spacing.lg)
                            .padding(.bottom, DesignSystem.Spacing.xl)
                        
                        // Deck summaries
                        deckSummariesSection
                            .padding(.horizontal, DesignSystem.Spacing.xl)
                            .padding(.bottom, DesignSystem.Spacing.lg)
                            .offset(y: isAppearing ? 0 : 15)
                            .opacity(isAppearing ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1), value: isAppearing)
                        
                        // Validation issues
                        if !preview.errors.isEmpty {
                            validationSection
                                .padding(.horizontal, DesignSystem.Spacing.xl)
                                .padding(.bottom, DesignSystem.Spacing.lg)
                                .offset(y: isAppearing ? 0 : 15)
                                .opacity(isAppearing ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.15), value: isAppearing)
                        }
                        
                        // Format guide
                        formatGuideSection
                            .padding(.horizontal, DesignSystem.Spacing.xl)
                            .padding(.bottom, DesignSystem.Spacing.xxl)
                            .offset(y: isAppearing ? 0 : 15)
                            .opacity(isAppearing ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.2), value: isAppearing)
                    }
                }
                
                // Footer actions
                footerActions
            }

            if let overlayState {
                ImportOperationOverlay(state: overlayState)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 780, minHeight: 620)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                isAppearing = true
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            DesignSystem.Colors.canvasBackground
            
            // Subtle gradient orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [DesignSystem.Colors.subtleOverlay, .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: -100, y: -50)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Icon and title
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.green)
                }
                .offset(y: isAppearing ? 0 : -10)
                .opacity(isAppearing ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isAppearing)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Preview")
                        .font(.system(size: 26, weight: .bold, design: .default))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    
                    Text("Review before importing")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
            }
            
            // Stats badges
            HStack(spacing: DesignSystem.Spacing.md) {
                StatBadge(
                    icon: "rectangle.stack",
                    value: "\(preview.deckCount)",
                    label: preview.deckCount == 1 ? "deck" : "decks",
                    color: DesignSystem.Colors.studyAccentBright
                )
                
                StatBadge(
                    icon: "rectangle.on.rectangle",
                    value: "\(preview.cardCount)",
                    label: preview.cardCount == 1 ? "card" : "cards",
                    color: .purple
                )
                
                PreviewFormatBadge(title: preview.formatName)
                
                Spacer()
            }
            .offset(y: isAppearing ? 0 : 10)
            .opacity(isAppearing ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05), value: isAppearing)
        }
    }
    
    // MARK: - Deck Summaries
    
    private var deckSummariesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionTitle(title: "Decks in this file", icon: "rectangle.stack.fill")
            
            if preview.decks.isEmpty {
                EmptyStateCard(
                    icon: "exclamationmark.triangle",
                    title: "No decks detected",
                    description: "Fix the formatting issues below or choose a different file."
                )
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(preview.decks) { deck in
                        PremiumDeckSummaryRow(
                            deck: deck,
                            existingDecks: existingDecks,
                            assignment: assignmentBinding(for: deck.token)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Validation Section
    
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                
                Text("VALIDATION ISSUES")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .tracking(0.8)
                
                Text("\(preview.errors.count)")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
            }
            
            Text("We can still import, but these items need attention for best results.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(preview.errors) { error in
                    PremiumValidationIssueRow(error: error)
                }
            }
        }
    }
    
    // MARK: - Format Guide
    
    private var formatGuideSection: some View {
        PremiumFormatGuideDisclosure(activeFormatID: preview.formatIdentifier)
    }
    
    // MARK: - Footer
    
    private var footerActions: some View {
        HStack {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.hoverBackground)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: onImport) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 13, weight: .medium))
                    Text("Import \(preview.cardCount) Cards")
                        .font(DesignSystem.Typography.bodyMedium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.primaryText)
                )
            }
            .buttonStyle(PreviewImportButtonStyle())
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.window)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -2)
        )
    }
    
    // MARK: - Helpers
    
    private func assignmentBinding(for token: ImportDeckToken) -> Binding<DeckMergePlan.Assignment> {
        Binding(
            get: { mergePlan.assignment(for: token) },
            set: { mergePlan.setAssignment($0, for: token) }
        )
    }
}

// MARK: - Supporting Components

private struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
        }
    }
}

private struct PreviewFormatBadge: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 12, weight: .medium))
            Text(title)
                .font(DesignSystem.Typography.captionMedium)
        }
        .foregroundStyle(DesignSystem.Colors.secondaryText)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.hoverBackground)
        )
    }
}

private struct SectionTitle: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            
            Text(title.uppercased())
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .tracking(0.8)
        }
    }
}

private struct EmptyStateCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.tertiaryText)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                Text(description)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
    }
}

private struct PremiumDeckSummaryRow: View {
    let deck: ImportPreview.DeckSummary
    let existingDecks: [DeckMergeTarget]
    @Binding var assignment: DeckMergePlan.Assignment
    
    @State private var isHovered = false

    var body: some View {
        let components = deck.name
            .components(separatedBy: "::")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let depth = max(components.count - 1, 0)
        let leafName = components.last ?? deck.name
        let parentPath = components.dropLast().joined(separator: " / ")

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header row
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                // Deck icon
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                        .fill(DesignSystem.Colors.subtleOverlay)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(leafName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    
                    Text(subtitle(cardCount: deck.cardCount, parentPath: parentPath))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
                
                Spacer()
                
                if let target = assignment.targetDeck {
                    PremiumMergeBadge(target: target)
                }
            }
            .padding(.leading, CGFloat(depth) * 14)

            // Destination picker
            if existingDecks.isEmpty {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    
                    Text("Will create as a new deck")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
            } else {
                PremiumMergeDestinationPicker(
                    deckName: deck.name,
                    existingDecks: existingDecks,
                    assignment: $assignment
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.06 : 0.03),
                    radius: isHovered ? 12 : 6,
                    x: 0,
                    y: isHovered ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .stroke(
                    assignment.isMerging ? DesignSystem.Colors.studyAccentBright.opacity(0.3) : DesignSystem.Colors.separator,
                    lineWidth: assignment.isMerging ? 1.5 : 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(DesignSystem.Animation.quick, value: isHovered)
    }

    private func subtitle(cardCount: Int, parentPath: String) -> String {
        let cards = "\(cardCount) \(cardCount == 1 ? "card" : "cards")"
        guard !parentPath.isEmpty else { return cards }
        return "\(cards) • \(parentPath)"
    }
}

private struct PremiumValidationIssueRow: View {
    let error: ImportErrorDetail
    
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Warning icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.orange)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let line = error.line {
                        Text("Line \(line)")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.hoverBackground)
                            )
                    }
                    
                    Text(error.path)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
                
                Text(error.message)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .fill(Color.orange.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(DesignSystem.Animation.quick, value: isHovered)
    }
}

private struct PremiumMergeDestinationPicker: View {
    let deckName: String
    let existingDecks: [DeckMergeTarget]
    @Binding var assignment: DeckMergePlan.Assignment
    
    @State private var isHovered = false

    var body: some View {
        Menu {
            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    assignment = .createNew
                }
            } label: {
                Label("Create new deck \"\(deckName)\"", systemImage: "sparkles.rectangle.stack")
            }

            Section("Merge into existing") {
                ForEach(existingDecks) { target in
                    Button {
                        withAnimation(DesignSystem.Animation.quick) {
                            assignment = DeckMergePlan.Assignment(destination: .existing(target))
                        }
                    } label: {
                        Label(targetLabel(for: target), systemImage: target.isArchived ? "archivebox" : "rectangle.stack")
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectionTitle)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    
                    Text(selectionSubtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(isHovered ? DesignSystem.Colors.hoverBackground : DesignSystem.Colors.subtleOverlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(isHovered ? DesignSystem.Colors.separator : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(DesignSystem.Animation.quick, value: isHovered)
    }

    private var selectionTitle: String {
        switch assignment.destination {
        case .createNew:
            return "Create new deck"
        case .existing(let target):
            return "Merge into \(target.name)"
        }
    }

    private var selectionSubtitle: String {
        switch assignment.destination {
        case .createNew:
            return "Adds \(deckName) as its own deck"
        case .existing(let target):
            return target.isArchived ? "Currently archived" : "Preserves existing schedule"
        }
    }

    private func targetLabel(for target: DeckMergeTarget) -> String {
        target.isArchived ? "\(target.name) (archived)" : target.name
    }
}

private struct PremiumMergeBadge: View {
    let target: DeckMergeTarget

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 11, weight: .semibold))
            Text("Merging")
                .font(DesignSystem.Typography.captionMedium)
        }
        .foregroundStyle(DesignSystem.Colors.studyAccentBright)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.studyAccentBright.opacity(0.12))
        )
    }
}

private struct PremiumFormatGuideDisclosure: View {
    let activeFormatID: String?
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.subtleOverlay)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.yellow)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Format Reference")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                        
                        Text("View JSON, CSV, and Markdown requirements")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ImportFormatGuideView(activeFormatID: activeFormatID)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .fill(DesignSystem.Colors.window)
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.06 : 0.03),
                    radius: isHovered ? 12 : 6,
                    x: 0,
                    y: isHovered ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(DesignSystem.Animation.quick, value: isHovered)
    }
}

private struct PreviewImportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private extension DeckMergePlan.Assignment {
    var isMerging: Bool {
        if case .existing = destination { return true }
        return false
    }

    var targetDeck: DeckMergeTarget? {
        if case .existing(let target) = destination {
            return target
        }
        return nil
    }
}


#if DEBUG
import SwiftUI

private extension ImportPreview {
    static let sample: ImportPreview = .init(
        formatIdentifier: "revu",
        formatName: "Revu",
        deckCount: 2,
        cardCount: 42,
        decks: [
            .init(
                id: UUID(),
                name: "Biology",
                cardCount: 20,
                token: ImportDeckToken(sourceIndex: 0, originalID: nil)
            ),
            .init(
                id: UUID(),
                name: "Chemistry",
                cardCount: 22,
                token: ImportDeckToken(sourceIndex: 1, originalID: nil)
            )
        ],
        errors: []
    )

    static let sampleWithIssues: ImportPreview = .init(
        formatIdentifier: "revu",
        formatName: "Revu",
        deckCount: 3,
        cardCount: 50,
        decks: [
            .init(
                id: UUID(),
                name: "French Nouns",
                cardCount: 18,
                token: ImportDeckToken(sourceIndex: 0, originalID: nil)
            ),
            .init(
                id: UUID(),
                name: "Spanish Verbs",
                cardCount: 21,
                token: ImportDeckToken(sourceIndex: 1, originalID: nil)
            ),
            .init(
                id: UUID(),
                name: "German Phrases",
                cardCount: 11,
                token: ImportDeckToken(sourceIndex: 2, originalID: nil)
            )
        ],
        errors: [
            .init(line: 14, path: "Row 14 → Back", message: "Missing answer text"),
            .init(line: 27, path: "Row 27 → Front", message: "Unexpected delimiter; split into multiple fields"),
            .init(line: nil, path: "Deck: Spanish Verbs", message: "Found duplicate card; will merge on import")
        ]
    )
}

#Preview("Typical file") {
    ImportPreviewContainer(
        preview: .sample,
        targets: DeckMergeTarget.previewTargets
    )
}

#Preview("With validation issues") {
    ImportPreviewContainer(
        preview: .sampleWithIssues,
        targets: DeckMergeTarget.previewTargets
    )
}

private struct ImportPreviewContainer: View {
    let preview: ImportPreview
    let targets: [DeckMergeTarget]
    @State private var plan: DeckMergePlan

    init(preview: ImportPreview, targets: [DeckMergeTarget]) {
        self.preview = preview
        self.targets = targets
        _plan = State(initialValue: ImportPreviewContainer.bootstrapPlan(preview: preview, targets: targets))
    }

    var body: some View {
        ImportPreviewView(
            preview: preview,
            existingDecks: targets,
            mergePlan: $plan,
            onImport: {},
            onCancel: {},
            overlayState: nil
        )
        .frame(width: 800, height: 600)
    }

    private static func bootstrapPlan(preview: ImportPreview, targets: [DeckMergeTarget]) -> DeckMergePlan {
        var plan = DeckMergePlan()
        if let first = preview.decks.first, let target = targets.first {
            plan.setAssignment(.init(destination: .existing(target)), for: first.token)
        }
        return plan
    }
}

private extension DeckMergeTarget {
    static let previewTargets: [DeckMergeTarget] = [
        .init(id: UUID(), parentId: nil, name: "Biology", note: nil, dueDate: nil, isArchived: false),
        .init(id: UUID(), parentId: nil, name: "Chemistry", note: nil, dueDate: nil, isArchived: false),
        .init(id: UUID(), parentId: nil, name: "Archived Deck", note: nil, dueDate: nil, isArchived: true)
    ]
}
#endif
