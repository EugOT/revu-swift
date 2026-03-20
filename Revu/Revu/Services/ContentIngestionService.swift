import Foundation
import PDFKit
import Speech
import AVFoundation

/// Service responsible for ingesting various file types and converting them into text for AI processing.
/// Supports:
/// - PDF (text extraction)
/// - Audio (transcription via SFSpeechRecognizer)
/// - Text/Markdown/JSON (direct read)
actor ContentIngestionService {
    
    enum IngestionError: LocalizedError {
        case fileAccessFailed
        case unsupportedFileType(String)
        case pdfExtractionFailed
        case audioTranscriptionFailed(String)
        case audioPermissionDenied
        case textDecodingFailed
        
        var errorDescription: String? {
            switch self {
            case .fileAccessFailed: return "Could not access the file. Check permissions."
            case .unsupportedFileType(let ext): return "File type '.\(ext)' is not supported."
            case .pdfExtractionFailed: return "Could not extract text from the PDF."
            case .audioTranscriptionFailed(let reason): return "Audio transcription failed: \(reason)"
            case .audioPermissionDenied: return "Speech recognition permission was denied."
            case .textDecodingFailed: return "Could not decode text file. Ensure it is UTF-8."
            }
        }
    }
    
    /// Ingests a file at the given URL and returns its textual content.
    func ingest(url: URL) async throws -> String {
        let ext = url.pathExtension.lowercased()
        
        // Ensure we can access the file if it's security scoped
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        
        switch ext {
        case "pdf":
            return try extractTextFromPDF(url: url)
        case "mp3", "m4a", "wav":
            return try await transcribeAudio(url: url)
        case "txt", "md", "json", "csv", "html":
            return try readText(url: url)
        default:
            throw IngestionError.unsupportedFileType(ext)
        }
    }
    
    private func readText(url: URL) throws -> String {
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                throw IngestionError.textDecodingFailed
            }
            return text
        } catch {
            throw IngestionError.fileAccessFailed
        }
    }
    
    private func extractTextFromPDF(url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw IngestionError.pdfExtractionFailed
        }
        
        var fullText = ""
        let pageCount = pdf.pageCount
        
        for i in 0..<pageCount {
            guard let page = pdf.page(at: i), let pageText = page.string else { continue }
            fullText += pageText + "\n"
        }
        
        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw IngestionError.pdfExtractionFailed
        }
        
        return fullText
    }
    
    private func transcribeAudio(url: URL) async throws -> String {
        // Check permissions first
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .denied || status == .restricted {
            throw IngestionError.audioPermissionDenied
        }
        // If not determined, we might need to request, but SFSpeechRecognizer.requestAuthorization is async callback based.
        // For simplicity in this actor, we assume the app has requested or will trigger the system prompt.
        
        return try await withCheckedThrowingContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                guard authStatus == .authorized else {
                    continuation.resume(throwing: IngestionError.audioPermissionDenied)
                    return
                }
                
                self.performTranscription(url: url, continuation: continuation)
            }
        }
    }
    
    private func performTranscription(url: URL, continuation: CheckedContinuation<String, Error>) {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            continuation.resume(throwing: IngestionError.audioTranscriptionFailed("Speech recognizer unavailable"))
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false // Allow server-side if better, or set true for privacy

        recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                continuation.resume(throwing: IngestionError.audioTranscriptionFailed(error.localizedDescription))
                return
            }

            if let result = result, result.isFinal {
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }

    // MARK: - Chunking

    /// Chunks extracted text into retrievable sections.
    /// Strategies: heading-based for structured docs, paragraph-based for plain text.
    func chunk(
        text: String,
        sourceFilename: String,
        materialId: UUID? = nil,
        courseId: UUID? = nil
    ) -> [ContentChunk] {
        let lines = text.components(separatedBy: .newlines)
        var chunks: [ContentChunk] = []
        var currentHeading: String? = nil
        var currentContent: [String] = []
        var currentPage: Int? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect page breaks (PDF convention: "\f" or "--- Page N ---")
            if trimmed.hasPrefix("\u{0C}") || trimmed.contains("Page ") {
                currentPage = (currentPage ?? 0) + 1
            }

            // Detect headings (ALL CAPS lines, lines ending with ":", short bold lines)
            if isHeading(trimmed) {
                // Flush current chunk
                if !currentContent.isEmpty {
                    chunks.append(makeChunk(
                        heading: currentHeading,
                        content: currentContent.joined(separator: "\n"),
                        page: currentPage,
                        filename: sourceFilename,
                        materialId: materialId,
                        courseId: courseId
                    ))
                    currentContent = []
                }
                currentHeading = trimmed
            } else if !trimmed.isEmpty {
                currentContent.append(trimmed)
            }

            // Size limit: flush if chunk exceeds ~500 words
            let wordCount = currentContent.joined(separator: " ").split(whereSeparator: \.isWhitespace).count
            if wordCount > 500 {
                chunks.append(makeChunk(
                    heading: currentHeading,
                    content: currentContent.joined(separator: "\n"),
                    page: currentPage,
                    filename: sourceFilename,
                    materialId: materialId,
                    courseId: courseId
                ))
                currentContent = []
            }
        }

        // Flush remaining
        if !currentContent.isEmpty {
            chunks.append(makeChunk(
                heading: currentHeading,
                content: currentContent.joined(separator: "\n"),
                page: currentPage,
                filename: sourceFilename,
                materialId: materialId,
                courseId: courseId
            ))
        }

        return chunks
    }

    private func isHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count < 120 else { return false }
        // ALL CAPS with at least 3 chars
        if trimmed.count >= 3 && trimmed == trimmed.uppercased() && trimmed.rangeOfCharacter(from: .letters) != nil {
            return true
        }
        // Ends with colon and is short
        if trimmed.hasSuffix(":") && trimmed.count < 80 { return true }
        // Numbered section: "1.", "1.1", "Chapter 1"
        if trimmed.range(of: "^(\\d+\\.?\\d*|Chapter \\d+)", options: .regularExpression) != nil { return true }
        return false
    }

    private func makeChunk(heading: String?, content: String, page: Int?, filename: String, materialId: UUID?, courseId: UUID?) -> ContentChunk {
        let words = content.split(whereSeparator: \.isWhitespace)
        let conceptKeys = extractConceptKeys(from: content, heading: heading)
        return ContentChunk(
            id: UUID(),
            materialId: materialId,
            courseId: courseId,
            sourceFilename: filename,
            sourcePage: page,
            sectionHeading: heading,
            content: content,
            wordCount: words.count,
            conceptKeys: conceptKeys,
            createdAt: Date()
        )
    }

    private func extractConceptKeys(from text: String, heading: String?) -> [String] {
        // Extract key terms: heading words + most frequent multi-word terms
        var keys: [String] = []
        if let heading = heading {
            keys.append(heading.lowercased().trimmingCharacters(in: .punctuationCharacters))
        }
        return keys
    }
}
