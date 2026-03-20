@preconcurrency import Foundation

// MARK: - Concept Key

/// Stable identifier for a concept derived from card tags or deck path
struct ConceptKey: Codable, Hashable, Sendable {
    /// Normalized, stable key (lowercase, trimmed)
    let key: String
    
    /// User-friendly display name (preserves original casing)
    let displayName: String
    
    init(key: String, displayName: String) {
        self.key = key.trimmingCharacters(in: .whitespaces).lowercased()
        self.displayName = displayName.trimmingCharacters(in: .whitespaces)
    }
    
    /// Create a concept key from a tag
    static func fromTag(_ tag: String) -> ConceptKey {
        ConceptKey(key: tag, displayName: tag)
    }
    
    /// Create a concept key from a deck path/name
    static func fromDeckPath(_ path: String) -> ConceptKey {
        ConceptKey(key: path, displayName: path)
    }
}

// MARK: - Concept State

/// Bayesian Knowledge Tracing state for a single concept
struct ConceptState: Codable, Equatable, Sendable {
    /// Concept identifier (normalized)
    var key: String
    
    /// User-friendly display name
    var displayName: String
    
    /// Probability of knowledge (0–1)
    var pKnown: Double
    
    /// Total attempts across all cards for this concept
    var attempts: Int
    
    /// Correct attempts across all cards for this concept
    var corrects: Int
    
    /// Last update timestamp
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case key
        case displayName
        case pKnown
        case attempts
        case corrects
        case updatedAt
    }
    
    init(
        key: String,
        displayName: String,
        pKnown: Double = 0.3,
        attempts: Int = 0,
        corrects: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.key = key
        self.displayName = displayName
        self.pKnown = pKnown
        self.attempts = attempts
        self.corrects = corrects
        self.updatedAt = updatedAt
    }
    
    /// Backward-compatible decoding with safe defaults
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? key
        pKnown = try container.decodeIfPresent(Double.self, forKey: .pKnown) ?? 0.3
        attempts = try container.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
        corrects = try container.decodeIfPresent(Int.self, forKey: .corrects) ?? 0
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}
