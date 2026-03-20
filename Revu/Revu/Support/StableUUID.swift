import CryptoKit
import Foundation

enum StableUUID {
    static func deckPathID(_ path: String) -> UUID {
        stableUUID("revu.deckpath.\(path.lowercased())")
    }

    private static func stableUUID(_ name: String) -> UUID {
        let digest = SHA256.hash(data: Data(name.utf8))
        let bytes = Array(digest)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
