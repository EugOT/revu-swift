import Foundation

/// Service layer for storing and retrieving chunked content from imported materials.
///
/// Wraps storage chunk methods with budget-aware retrieval, enabling the AI
/// to reference specific sections of student materials within token limits.
struct ContentChunkService {
    private let storage: any Storage

    init(storage: any Storage) {
        self.storage = storage
    }

    @MainActor
    init() {
        self.init(storage: DataController.shared.storage)
    }

    /// Retrieve chunks relevant to a set of concept keys, within a token budget.
    func relevantChunks(
        courseId: UUID,
        conceptKeys: [String],
        tokenBudget: Int = 2000
    ) async throws -> [ContentChunk] {
        let candidates = try await storage.searchChunks(
            courseId: courseId,
            keywords: conceptKeys,
            limit: 10
        )

        // Accumulate chunks within budget
        var selected: [ContentChunk] = []
        var usedTokens = 0
        for chunk in candidates {
            let tokens = chunk.tokenEstimate
            if usedTokens + tokens > tokenBudget { break }
            selected.append(chunk)
            usedTokens += tokens
        }
        return selected
    }

    /// Store chunks from a chunking operation.
    func store(chunks: [ContentChunk]) async throws {
        for chunk in chunks {
            try await storage.upsert(chunk: chunk)
        }
    }
}
