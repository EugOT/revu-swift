import SwiftUI
import Combine

class MatchGameViewModel: ObservableObject {
    struct Tile: Identifiable, Equatable {
        let id = UUID()
        let cardId: UUID
        let content: String
        let isFront: Bool
        var isMatched: Bool = false
        var isSelected: Bool = false
        var isError: Bool = false
    }

    enum GameState {
        case playing
        case finished
    }

    @Published var tiles: [Tile] = []
    @Published var gameState: GameState = .playing
    @Published var timeRemaining: TimeInterval = 60.0
    @Published var score: Int = 0
    @Published var matchedPairs: Int = 0
    @Published var comboStreak: Int = 0
    @Published var lastMatchTime: Date?
    
    private var timer: AnyCancellable?
    private var selection1: Int?
    private var selection2: Int?
    private let totalPairs: Int
    
    init(cards: [Card], pairCount: Int = 6) {
        // Select random cards
        let shuffledCards = cards.shuffled().prefix(pairCount)
        self.totalPairs = shuffledCards.count
        
        var newTiles: [Tile] = []
        for card in shuffledCards {
            newTiles.append(Tile(cardId: card.id, content: card.front, isFront: true))
            newTiles.append(Tile(cardId: card.id, content: card.back, isFront: false))
        }
        
        self.tiles = newTiles.shuffled()
        startTimer()
    }
    
    func selectTile(at index: Int) {
        guard gameState == .playing else { return }
        guard !tiles[index].isMatched else { return }
        guard selection2 == nil else { return } // Block input while processing mismatch
        guard selection1 != index else { return } // Prevent re-selecting same tile
        
        // Reset error state if any
        resetErrors()

        if let firstIndex = selection1 {
            // Second selection
            selection2 = index
            tiles[index].isSelected = true
            checkForMatch(index1: firstIndex, index2: index)
        } else {
            // First selection
            selection1 = index
            tiles[index].isSelected = true
        }
    }
    
    private func checkForMatch(index1: Int, index2: Int) {
        let tile1 = tiles[index1]
        let tile2 = tiles[index2]
        
        if tile1.cardId == tile2.cardId {
            // Match!
            handleMatch(index1: index1, index2: index2)
        } else {
            // Mismatch
            handleMismatch(index1: index1, index2: index2)
        }
    }
    
    private func handleMatch(index1: Int, index2: Int) {
        // Calculate combo
        let now = Date()
        if let last = lastMatchTime, now.timeIntervalSince(last) < 2.0 {
            comboStreak += 1
        } else {
            comboStreak = 1
        }
        lastMatchTime = now
        
        let multiplier = min(comboStreak, 5)
        let points = 100 * multiplier
        
        // Delay slightly to show the selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.tiles[index1].isMatched = true
                self.tiles[index2].isMatched = true
                self.tiles[index1].isSelected = false
                self.tiles[index2].isSelected = false
            }
            self.selection1 = nil
            self.selection2 = nil
            self.score += points
            self.matchedPairs += 1
            
            if self.matchedPairs == self.totalPairs {
                self.endGame()
            }
        }
    }
    
    private func handleMismatch(index1: Int, index2: Int) {
        withAnimation {
            tiles[index1].isError = true
            tiles[index2].isError = true
        }
        
        // Penalty
        timeRemaining = max(0, timeRemaining - 2)
        comboStreak = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                self.tiles[index1].isSelected = false
                self.tiles[index2].isSelected = false
                self.tiles[index1].isError = false
                self.tiles[index2].isError = false
            }
            self.selection1 = nil
            self.selection2 = nil
        }
    }
    
    private func resetErrors() {
        for i in tiles.indices {
            tiles[i].isError = false
        }
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 0.1
                } else {
                    self.endGame()
                }
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
