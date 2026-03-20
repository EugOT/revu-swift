import SwiftUI
import Combine

class SpeedQuizViewModel: ObservableObject {
    struct Question: Identifiable {
        let id = UUID()
        let card: Card
        let choices: [String]
        let correctAnswerIndex: Int
    }
    
    enum GameState {
        case playing
        case finished
    }
    
    @Published var currentQuestionIndex: Int = 0
    @Published var questions: [Question] = []
    @Published var gameState: GameState = .playing
    @Published var timeRemaining: TimeInterval = 10.0 // Time per question
    @Published var score: Int = 0
    @Published var streak: Int = 0
    @Published var selectedChoiceIndex: Int?
    @Published var isAnswerRevealed: Bool = false
    @Published var isCorrect: Bool = false
    
    private var timer: AnyCancellable?
    private let allCards: [Card]
    
    init(cards: [Card], questionCount: Int = 10) {
        self.allCards = cards
        generateQuestions(count: questionCount)
        startTimer()
    }
    
    private func generateQuestions(count: Int) {
        let shuffledCards = allCards.shuffled().prefix(count)
        var newQuestions: [Question] = []
        
        for card in shuffledCards {
            // Generate distractors
            var choices: [String] = []
            let correctAnswer = card.back
            choices.append(correctAnswer)
            
            // Pick 3 random other cards as distractors
            let distractors = allCards
                .filter { $0.id != card.id }
                .shuffled()
                .prefix(3)
                .map { $0.back }
            
            choices.append(contentsOf: distractors)
            choices.shuffle()
            
            let correctIndex = choices.firstIndex(of: correctAnswer) ?? 0
            
            newQuestions.append(Question(card: card, choices: choices, correctAnswerIndex: correctIndex))
        }
        
        self.questions = newQuestions
    }
    
    func selectChoice(at index: Int) {
        guard !isAnswerRevealed else { return }
        
        selectedChoiceIndex = index
        isAnswerRevealed = true
        timer?.cancel()
        
        let question = questions[currentQuestionIndex]
        if index == question.correctAnswerIndex {
            // Correct
            isCorrect = true
            streak += 1
            let timeBonus = Int(timeRemaining * 10)
            score += 100 + (streak * 10) + timeBonus
        } else {
            // Incorrect
            isCorrect = false
            streak = 0
        }
        
        // Auto advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.nextQuestion()
        }
    }
    
    private func nextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
            resetRound()
        } else {
            endGame()
        }
    }
    
    private func resetRound() {
        selectedChoiceIndex = nil
        isAnswerRevealed = false
        isCorrect = false
        timeRemaining = 10.0
        startTimer()
    }
    
    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 0.1
                } else {
                    self.timeOut()
                }
            }
    }
    
    private func timeOut() {
        timer?.cancel()
        isAnswerRevealed = true
        isCorrect = false
        streak = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.nextQuestion()
        }
    }
    
    private func endGame() {
        gameState = .finished
        timer?.cancel()
    }
    
    deinit {
        timer?.cancel()
    }
}
