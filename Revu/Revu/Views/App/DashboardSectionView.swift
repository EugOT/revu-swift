import SwiftUI

/// A sophisticated dashboard section containing the "Continue Learning" and "AI Deck Generator" cards.
/// Designed to be a drop-in replacement for the existing learning intelligence section in the sidebar.
struct DashboardSectionView: View {
    // MARK: - Properties
    
    /// The current active learning session, if any.
    /// In a real app, this would come from the data model.
    var session: SessionPreview?
    
    /// Action handler for tapping the "Continue Learning" card.
    var onContinueLearning: () -> Void
    
    /// Action handler for tapping the "AI Deck Generator" card.
    var onOpenAIGenerator: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            continueLearningCard
            aiGeneratorCard
        }
    }
    
    // MARK: - Components
    
    private var continueLearningCard: some View {
        Button(action: onContinueLearning) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Header
                HStack(spacing: DesignSystem.Spacing.sm) {
                    StatusIndicator(isActive: session != nil)
                    
                    Text(session != nil ? "Continue learning" : "Ready to study")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    
                    Spacer()
                }
                
                // Content
                if let session = session {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text(session.deckName)
                                .font(DesignSystem.Typography.smallMedium)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.12))
                                )
                            
                            Spacer()
                            
                            Text(session.dueString)
                                .font(DesignSystem.Typography.small)
                                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        }
                        
                        Text(session.concept)
                            .font(DesignSystem.Typography.small)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                } else {
                    // Empty state / Ready to study suggestion
                    Text("Select a deck to start a new session.")
                        .font(DesignSystem.Typography.small)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .fill(DesignSystem.Colors.window)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .stroke(DesignSystem.Colors.borderOverlay, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.03),
                radius: 8,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(DashboardCardButtonStyle())
    }
    
    private var aiGeneratorCard: some View {
        Button(action: onOpenAIGenerator) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    
                    Text("AI deck generator")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                }
                
                Text("Spin up fresh cards with foundation models or your own API key.")
                    .font(DesignSystem.Typography.small)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .fill(DesignSystem.Colors.window)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .stroke(DesignSystem.Colors.borderOverlay, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.03),
                radius: 8,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(DashboardCardButtonStyle())
    }
}

// MARK: - Supporting Views

private struct StatusIndicator: View {
    let isActive: Bool
    
    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
            }
        }
        .frame(width: 12, height: 12)
    }
}

struct DashboardCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Models

/// A simple model to represent the session data for the view.
struct SessionPreview {
    let deckName: String
    let concept: String
    let dueString: String
}

// MARK: - Previews

struct DashboardSectionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // State 1: Active Session
            DashboardSectionView(
                session: SessionPreview(
                    deckName: "Linear Algebra — Lectures 1–3",
                    concept: "Onto vs one-to-one for T(x)=Ax",
                    dueString: "now"
                ),
                onContinueLearning: {},
                onOpenAIGenerator: {}
            )
            
            Divider()
            
            // State 2: No Active Session
            DashboardSectionView(
                session: nil,
                onContinueLearning: {},
                onOpenAIGenerator: {}
            )
        }
        .padding()
        .frame(width: 300)
        .background(DesignSystem.Colors.sidebarBackground)
        .previewDisplayName("Dashboard Section States")
    }
}
