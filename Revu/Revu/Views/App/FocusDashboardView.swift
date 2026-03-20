import SwiftUI

/// The "Focus Hub": A dashboard section for the sidebar featuring a hero session card,
/// and an optional quick import action.
struct FocusDashboardView: View {
    // MARK: - Properties

    /// The current active learning session.
    var session: FocusSession?

    /// Action handlers
    var onContinueLearning: () -> Void
    var onQuickImport: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHoveringHero = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            heroSessionCard
            if let onQuickImport {
                quickImportButton(action: onQuickImport)
            }
        }
    }

    // MARK: - Hero Card

    private var heroSessionCard: some View {
        Button(action: onContinueLearning) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    if let session = session {
                        // Active State
                        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xxs) {
                            Text("\(session.dueCount)")
                                .font(DesignSystem.Typography.hero)
                                .foregroundStyle(DesignSystem.Colors.primaryText)

                            Text("due")
                                .font(DesignSystem.Typography.subheading)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }

                        Text(session.deckName)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                            .lineLimit(1)

                        Text(session.nextConcept)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .lineLimit(1)
                    } else {
                        // Empty / Done State
                        Text("All Caught Up")
                            .font(DesignSystem.Typography.heading)
                            .foregroundStyle(DesignSystem.Colors.primaryText)

                        Text("Great job! You've cleared your queue.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .lineLimit(2)
                    }
                }
                .padding(DesignSystem.Spacing.lg)

                Spacer()

                // Play Button / Status Icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.window)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

                    Image(systemName: session != nil ? "play.fill" : "checkmark")
                        .font(DesignSystem.Typography.subheading)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                }
                .padding(.trailing, DesignSystem.Spacing.lg)
                .scaleEffect(isHoveringHero ? 1.05 : 1.0)
                .animation(DesignSystem.Animation.quick, value: isHoveringHero)
            }
            .background(heroBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.03),
                radius: DesignSystem.Spacing.xs,
                x: 0,
                y: DesignSystem.Spacing.xxs
            )
        }
        .buttonStyle(FocusCardButtonStyle())
        .onHover { isHoveringHero = $0 }
    }

    private var heroBackground: some View {
        ZStack {
            DesignSystem.Colors.window

            DesignSystem.Colors.lightOverlay
        }
    }

    // MARK: - Import Action

    private func quickImportButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "square.and.arrow.down")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Text("Import Material")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.primaryText)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .frame(height: 40)
            .background(DesignSystem.Colors.window)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(DesignSystem.Colors.separator, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.02),
                radius: 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(FocusCardButtonStyle())
        .help("Import study material")
    }
}

// MARK: - Supporting Views

struct FocusCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Models

struct FocusSession {
    let deckName: String
    let dueCount: Int
    let nextConcept: String
    let color: Color
}

// MARK: - Previews

struct FocusDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Active Session
            FocusDashboardView(
                session: FocusSession(
                    deckName: "Linear Algebra",
                    dueCount: 12,
                    nextConcept: "Eigenvalues",
                    color: .orange
                ),
                onContinueLearning: {},
                onQuickImport: {}
            )

            Divider()

            // Empty State
            FocusDashboardView(
                session: nil,
                onContinueLearning: {},
                onQuickImport: {}
            )
        }
        .padding()
        .frame(width: 320)
        .background(DesignSystem.Colors.sidebarBackground)
        .previewDisplayName("Focus Hub")
    }
}
