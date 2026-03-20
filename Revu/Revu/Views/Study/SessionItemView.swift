import SwiftUI

/// Router view that renders the correct sub-view based on `SessionItem` type.
/// Flashcard cases are handled by the parent `StudySessionView`, so
/// `.flashcard` returns `EmptyView` here.
struct SessionItemView: View {
    let item: SessionItem
    let onComplete: (Bool) -> Void  // wasSuccessful
    let onRequestExplanation: ((Card) -> Void)?

    var body: some View {
        Group {
            switch item {
            case .flashcard:
                // Handled by the parent StudySessionView; should not reach here.
                EmptyView()
            case .explanation(let explanation):
                ExplanationItemView(item: explanation, onDismiss: onComplete)
            case .conceptCheck(let check):
                ConceptCheckItemView(item: check, onAnswer: onComplete)
            case .examQuestion(let question):
                ExamQuestionItemView(item: question, onAnswer: onComplete)
            case .readingBlock(let reading):
                ReadingBlockView(item: reading, onDone: { onComplete(true) })
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}
