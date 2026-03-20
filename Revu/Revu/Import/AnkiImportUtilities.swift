import Foundation
import AppKit

enum AnkiImportUtilities {
    static func parseNoteFields(_ raw: String) -> [String] {
        raw.split(separator: "\u{1f}", omittingEmptySubsequences: false).map(String.init)
    }

    static func parseTags(_ raw: String?) -> [String] {
        let normalized = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        return normalized
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    static func plainText(fromHTML html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if !trimmed.contains("<") {
            return normalizeWhitespace(trimmed)
        }

        guard let data = trimmed.data(using: .utf8) else {
            return normalizeWhitespace(trimmed)
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return normalizeWhitespace(attributed.string)
        }

        return normalizeWhitespace(trimmed)
    }

    static func normalizeWhitespace(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func mediaReferences(in html: String) -> [String] {
        guard !html.isEmpty else { return [] }
        var references: [String] = []

        let patterns: [String] = [
            #"<img[^>]+src\s*=\s*["']([^"']+)["'][^>]*>"#,
            #"<source[^>]+src\s*=\s*["']([^"']+)["'][^>]*>"#,
            #"<audio[^>]+src\s*=\s*["']([^"']+)["'][^>]*>"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(html.startIndex..., in: html)
            regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1 else { return }
                guard let srcRange = Range(match.range(at: 1), in: html) else { return }
                let value = String(html[srcRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return }
                references.append(value)
            }
        }

        if let regex = try? NSRegularExpression(pattern: #"\[sound:([^\]]+)\]"#, options: [.caseInsensitive]) {
            let range = NSRange(html.startIndex..., in: html)
            regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1 else { return }
                guard let valueRange = Range(match.range(at: 1), in: html) else { return }
                let value = String(html[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return }
                references.append(value)
            }
        }

        return references.map { normalizeMediaReference($0) }.filter { !$0.isEmpty }
    }

    static func stripSoundMarkup(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[sound:[^\]]+\]"#, options: [.caseInsensitive]) else {
            return input
        }
        let range = NSRange(input.startIndex..., in: input)
        let output = regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "")
        return normalizeWhitespace(output)
    }

    static func normalizeMediaReference(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: cleaned), url.scheme != nil {
            cleaned = url.lastPathComponent
        }
        cleaned = cleaned.replacingOccurrences(of: "\\", with: "/")
        cleaned = cleaned.split(separator: "/").last.map(String.init) ?? cleaned
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stripHTMLAnswerDivider(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<hr[^>]*id\s*=\s*['"]?answer['"]?[^>]*>"#,
            options: [.caseInsensitive]
        ) else {
            return html
        }
        let nsRange = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, options: [], range: nsRange),
           let range = Range(match.range, in: html)
        {
            return String(html[range.upperBound...])
        }
        return html
    }

    static func renderTemplate(
        _ template: String,
        fields: [String: String],
        tags: [String],
        frontSide: String? = nil
    ) -> String {
        var output = template

        output = applyConditionals(output, fields: fields)
        output = output.replacingOccurrences(of: "{{FrontSide}}", with: frontSide ?? "")
        output = output.replacingOccurrences(of: "{{Tags}}", with: tags.joined(separator: " "))

        let placeholderRegex = try? NSRegularExpression(pattern: #"\{\{([^\}]+)\}\}"#, options: [])
        if let placeholderRegex {
            let nsRange = NSRange(output.startIndex..., in: output)
            let matches = placeholderRegex.matches(in: output, range: nsRange).reversed()
            for match in matches {
                guard match.numberOfRanges > 1, let keyRange = Range(match.range(at: 1), in: output) else { continue }
                let rawKey = String(output[keyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let replacement = resolveFieldPlaceholder(rawKey, fields: fields)
                if let fullRange = Range(match.range, in: output) {
                    output.replaceSubrange(fullRange, with: replacement)
                }
            }
        }

        return output
    }

    static func extractClozeFieldName(from template: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\{\{\s*cloze:([^\}]+)\}\}"#, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(template.startIndex..., in: template)
        guard let match = regex.firstMatch(in: template, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: template)
        else {
            return nil
        }
        let raw = String(template[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : raw
    }

    static func clozeSource(from raw: String, targetIndex: Int) -> String {
        let fragments = ClozeRenderer.linearFragments(from: raw)
        guard !fragments.isEmpty else { return raw }
        var output = ""
        output.reserveCapacity(raw.count)

        for fragment in fragments {
            switch fragment {
            case .text(let value):
                output.append(value)
            case .deletion(let index, let answer, let hint):
                if index == targetIndex {
                    if let hint, !hint.isEmpty {
                        output.append("{{c\(index)::\(answer)::\(hint)}}")
                    } else {
                        output.append("{{c\(index)::\(answer)}}")
                    }
                } else {
                    output.append(answer)
                }
            }
        }

        return output
    }

    private static func applyConditionals(_ input: String, fields: [String: String]) -> String {
        var output = input

        let positive = try? NSRegularExpression(pattern: #"\{\{#([^\}]+)\}\}(.*?)\{\{/\1\}\}"#, options: [.dotMatchesLineSeparators])
        if let positive {
            while true {
                let range = NSRange(output.startIndex..., in: output)
                guard let match = positive.firstMatch(in: output, options: [], range: range),
                      match.numberOfRanges > 2,
                      let fieldRange = Range(match.range(at: 1), in: output),
                      let bodyRange = Range(match.range(at: 2), in: output),
                      let wholeRange = Range(match.range, in: output)
                else {
                    break
                }
                let fieldName = String(output[fieldRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let body = String(output[bodyRange])
                let shouldInclude = !(fields[fieldName] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                output.replaceSubrange(wholeRange, with: shouldInclude ? body : "")
            }
        }

        let negative = try? NSRegularExpression(pattern: #"\{\{\^([^\}]+)\}\}(.*?)\{\{/\1\}\}"#, options: [.dotMatchesLineSeparators])
        if let negative {
            while true {
                let range = NSRange(output.startIndex..., in: output)
                guard let match = negative.firstMatch(in: output, options: [], range: range),
                      match.numberOfRanges > 2,
                      let fieldRange = Range(match.range(at: 1), in: output),
                      let bodyRange = Range(match.range(at: 2), in: output),
                      let wholeRange = Range(match.range, in: output)
                else {
                    break
                }
                let fieldName = String(output[fieldRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let body = String(output[bodyRange])
                let shouldInclude = (fields[fieldName] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                output.replaceSubrange(wholeRange, with: shouldInclude ? body : "")
            }
        }

        return output
    }

    private static func resolveFieldPlaceholder(_ rawKey: String, fields: [String: String]) -> String {
        let normalized = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.lowercased().hasPrefix("text:") {
            let name = String(normalized.dropFirst("text:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return plainText(fromHTML: fields[name] ?? "")
        }

        if normalized.lowercased().hasPrefix("cloze:") {
            let name = String(normalized.dropFirst("cloze:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return fields[name] ?? ""
        }

        return fields[normalized] ?? ""
    }
}

