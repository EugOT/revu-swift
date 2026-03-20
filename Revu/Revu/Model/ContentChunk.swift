@preconcurrency import Foundation

/// A chunk of content from an imported material, indexed for retrieval.
struct ContentChunk: Identifiable, Sendable {
    let id: UUID
    let materialId: UUID?            // Link to CourseMaterial if available
    let courseId: UUID?
    let sourceFilename: String
    let sourcePage: Int?              // PDF page number
    let sectionHeading: String?       // Heading text if found
    let content: String               // The actual text chunk
    let wordCount: Int
    let conceptKeys: [String]         // Normalized concept/topic tags
    let createdAt: Date

    var tokenEstimate: Int { wordCount / 3 }  // Rough token estimate
}
