import SwiftUI

struct SpeedQuizView: View {
    @StateObject private var viewModel: SpeedQuizViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let onDismiss: () -> Void
    
    init(cards: [Card], onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SpeedQuizViewModel(cards: cards))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                DesignSystem.Colors.window
                    .ignoresSafeArea()
                
                if viewModel.gameState == .finished {
                    gameOverView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    VStack(spacing: 0) {
                        progressBar
                        
                        ScrollView {
                            VStack(spacing: 32) {
                                header
                                
                                if !viewModel.questions.isEmpty {
                                    let question = viewModel.questions[viewModel.currentQuestionIndex]
                                    
                                    VStack(spacing: 24) {
                                        questionCard(question)
                                        choicesView(question)
                                    }
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                                    .id(question.id)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 32)
                        }
                    }
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.lightOverlay)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("SPEED QUIZ")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .textCase(.uppercase)
                    .tracking(0.8)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange.opacity(0.8))
                        Text("\(viewModel.streak)")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                            .contentTransition(.numericText(countsDown: false))
                    }
                    
                    Text("•")
                        .foregroundStyle(DesignSystem.Colors.separator)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow.opacity(0.8))
                        Text("\(viewModel.score)")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                            .contentTransition(.numericText(countsDown: false))
                    }
                }
            }
            
            Spacer()
            
            // Balance
            Color.clear.frame(width: 36, height: 36)
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(DesignSystem.Colors.separator.opacity(0.2))
                
                // Progress bar with gradient
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                progressColor.opacity(0.6),
                                progressColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * (viewModel.timeRemaining / 10.0))
                    .shadow(color: progressColor.opacity(0.3), radius: 4, x: 0, y: 0)
                    .animation(.linear(duration: 0.1), value: viewModel.timeRemaining)
            }
        }
        .frame(height: 3)
    }
    
    private var progressColor: Color {
        if viewModel.timeRemaining < 3 { return .red }
        if viewModel.timeRemaining < 6 { return .orange }
        return DesignSystem.Colors.primaryText
    }
    
    private func questionCard(_ question: SpeedQuizViewModel.Question) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("QUESTION \(viewModel.currentQuestionIndex + 1)/\(viewModel.questions.count)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    .tracking(1)
                Spacer()
            }
            
            MarkdownText(question.card.front)
                .font(DesignSystem.Typography.heading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DesignSystem.Colors.window)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
        )
        .shadow(
            color: Color(light: Color.black.opacity(0.04), dark: Color.black.opacity(0.5)),
            radius: 20,
            x: 0,
            y: 8
        )
    }
    
    private func choicesView(_ question: SpeedQuizViewModel.Question) -> some View {
        VStack(spacing: 12) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    viewModel.selectChoice(at: index)
                } label: {
                    HStack {
                        MarkdownText(choice, color: choiceTextColor(at: index, correctIndex: question.correctAnswerIndex))
                            .font(DesignSystem.Typography.body)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        if viewModel.isAnswerRevealed {
                            if index == question.correctAnswerIndex {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if index == viewModel.selectedChoiceIndex {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(DesignSystem.Colors.tertiaryText.opacity(0.5))
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(choiceBackgroundColor(at: index, correctIndex: question.correctAnswerIndex))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(choiceBorderColor(at: index, correctIndex: question.correctAnswerIndex), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(viewModel.isAnswerRevealed)
            }
        }
    }
    
    private func choiceBackgroundColor(at index: Int, correctIndex: Int) -> Color {
        if viewModel.isAnswerRevealed {
            if index == correctIndex {
                return Color.green.opacity(0.1)
            }
            if index == viewModel.selectedChoiceIndex {
                return Color.red.opacity(0.1)
            }
        }
        return DesignSystem.Colors.lightOverlay
    }
    
    private func choiceBorderColor(at index: Int, correctIndex: Int) -> Color {
        if viewModel.isAnswerRevealed {
            if index == correctIndex {
                return Color.green.opacity(0.5)
            }
            if index == viewModel.selectedChoiceIndex {
                return Color.red.opacity(0.5)
            }
        }
        return DesignSystem.Colors.separator.opacity(0.5)
    }
    
    private func choiceTextColor(at index: Int, correctIndex: Int) -> Color {
        if viewModel.isAnswerRevealed {
            if index == correctIndex {
                return .green
            }
            if index == viewModel.selectedChoiceIndex {
                return .red
            }
        }
        return DesignSystem.Colors.primaryText
    }
    
    private var gameOverView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.lightOverlay)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .strokeBorder(DesignSystem.Colors.separator, lineWidth: 1)
                    )
                
                Image(systemName: "flag.checkered")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            .scaleEffect(1.1)
            .animation(.spring(response: 0.5, dampingFraction: 0.6).repeatForever(autoreverses: true), value: true)
            
            VStack(spacing: 12) {
                Text("Quiz Complete")
                    .font(DesignSystem.Typography.hero)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                
                Text("Final Score: \(viewModel.score)")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            
            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.window)
    }
}

#if DEBUG
#Preview("SpeedQuizView") {
    let cards = [
        Card(kind: .basic, front: "Capital of France?", back: "Paris"),
        Card(kind: .basic, front: "2 + 2 = ?", back: "4"),
        Card(kind: .basic, front: "Derivative of $x^2$?", back: "$2x$"),
        Card(kind: .basic, front: "Largest planet?", back: "Jupiter"),
    ]
    return SpeedQuizView(cards: cards, onDismiss: {})
        .frame(width: 980, height: 720)
}
#endif
