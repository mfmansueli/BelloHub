//
//  VaultVectors.swift
//  BelloHubTests
//

import Foundation

/// Known answers for the key hierarchy, computed without CryptoKit by `scripts/vault-vectors.py` (HKDF from the
/// standard library, X25519 as the RFC 7748 ladder, BIP-39 checked against the published vectors).
/// **Never change these values without a migration**: they pin the keys every existing record was encrypted with.
enum VaultVectors {
    static let entropy = Data(hexString: "00112233445566778899aabbccddeeff")
    static let mnemonic = "abandon math mimic master filter design carbon crystal rookie group knife young"
    static let rootKey = "3f65e9462a97a6275ca6892d8cd9c6551d6b233cb5dfe25ae637805bcb1c9289"
    static let vaultKey = "49ec5ae6879a12c737bf0b3721968fbdb5cb6555eb6decd0a17a89147f3b9eb4"
    static let inboxSeed1 = "32abb76ac2d473500cea08ba1dce0556b7d7c19b53c398380ac65b964055bd98"
    static let inboxPublicKey1 = "ddad9a7d22f610a15fa49c104dd417e491689b577603a3adaed97ff218524c11"
    static let keyID1 = "CFrwKa1-Up0"
    static let inboxSeed2 = "4d0ce45f475ea4bdd4c1e93258ef5ffa3265d81c6619496c727fa4cdce100c4a"
    static let inboxPublicKey2 = "5b6812caefc9149a93f5edb3212b87c26fd34a9309278f6ecd858016820e7139"
    static let keyID2 = "oUBejtbIthY"

    /// The four vectors published with BIP-39 for 128-bit entropy.
    static let bip39: [(entropy: String, words: String)] = [
        ("00000000000000000000000000000000",
         "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"),
        ("7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
         "legal winner thank year wave sausage worth useful legal winner thank yellow"),
        ("80808080808080808080808080808080",
         "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"),
        ("ffffffffffffffffffffffffffffffff",
         "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong")
    ]
}

extension Data {
    /// Test helper: bytes from a hex string. Fails loudly on bad input.
    init(hexString: String) {
        var bytes: [UInt8] = []
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            bytes.append(UInt8(hexString[index..<next], radix: 16) ?? 0)
            index = next
        }
        self.init(bytes)
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
