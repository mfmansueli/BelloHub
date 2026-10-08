//
//  KeyDerivationTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

@Suite("KeyDerivation")
struct KeyDerivationTests {
    private var root: SymmetricKey { KeyDerivation.rootKey(entropy: VaultVectors.entropy) }

    private func bytes(_ key: SymmetricKey) -> String {
        key.withUnsafeBytes { Data($0).hexString }
    }

    @Test("Known answers: root key, vault key, inbox seeds, public keys and key ids (computed outside CryptoKit)")
    func knownAnswers() throws {
        #expect(bytes(root) == VaultVectors.rootKey)
        #expect(bytes(KeyDerivation.vaultKey(rootKey: root)) == VaultVectors.vaultKey)
        #expect(KeyDerivation.inboxSeed(rootKey: root, generation: 1).hexString == VaultVectors.inboxSeed1)
        #expect(KeyDerivation.inboxSeed(rootKey: root, generation: 2).hexString == VaultVectors.inboxSeed2)

        let first = try KeyDerivation.inboxPrivateKey(rootKey: root, generation: 1).publicKey.rawRepresentation
        let second = try KeyDerivation.inboxPrivateKey(rootKey: root, generation: 2).publicKey.rawRepresentation
        #expect(first.hexString == VaultVectors.inboxPublicKey1)
        #expect(second.hexString == VaultVectors.inboxPublicKey2)
        #expect(KeyDerivation.keyID(forPublicKey: first) == VaultVectors.keyID1)
        #expect(KeyDerivation.keyID(forPublicKey: second) == VaultVectors.keyID2)
    }

    @Test("Derivation is deterministic: the same words give the same keys on any phone")
    func deterministic() {
        let again = KeyDerivation.rootKey(entropy: VaultVectors.entropy)

        #expect(bytes(again) == bytes(root))
    }

    @Test("Different entropy gives different keys")
    func differentEntropy() {
        let other = KeyDerivation.rootKey(entropy: Data(repeating: 1, count: 16))

        #expect(bytes(other) != bytes(root))
    }

    @Test("The vault key and the inbox seeds are independent of each other")
    func domainSeparation() {
        let vault = bytes(KeyDerivation.vaultKey(rootKey: root))
        let inbox1 = KeyDerivation.inboxSeed(rootKey: root, generation: 1).hexString
        let inbox2 = KeyDerivation.inboxSeed(rootKey: root, generation: 2).hexString

        #expect(Set([vault, inbox1, inbox2, bytes(root)]).count == 4)
    }

    @Test("A key id is 11 URL-safe characters and carries no padding")
    func keyIDShape() {
        #expect(VaultVectors.keyID1.count == 11)
        for id in [VaultVectors.keyID1, VaultVectors.keyID2] {
            #expect(id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        }
    }

    @Test("base64url has no plus, slash or padding")
    func base64URL() {
        #expect(Data([0xFB, 0xFF, 0xFE]).base64URLEncodedString() == "-__-")
        #expect(Data([0x01]).base64URLEncodedString() == "AQ")
    }
}
