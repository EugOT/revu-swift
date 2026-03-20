import Foundation

extension Card.Kind {
    static func importKind(from rawValue: String?) -> Card.Kind? {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if let direct = Card.Kind(rawValue: raw) {
            return direct
        }

        let normalized = Card.Kind.normalize(raw)
        return Card.Kind.allCases.first { Card.Kind.normalize($0.rawValue) == normalized }
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}
