import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct DeckDragPayload: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .revuDeckIdentifier)
    }
}

extension UTType {
    static let revuDeckIdentifier = UTType(exportedAs: "com.example.revu-swift.deck")
}
