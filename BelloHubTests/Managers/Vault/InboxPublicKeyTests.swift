//
//  InboxPublicKeyTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

@Suite("InboxPublicKey")
@MainActor
struct InboxPublicKeyTests {
    private let seed = Data(repeating: 0x42, count: 16)

    @Test("The published key is the public half of the derived pair, in the shape the server checks")
    func shape() throws {
        let manager = KeyManager(store: InMemoryKeyStore(seed: seed))
        try manager.prepare(createIfMissing: false)
        let key = try manager.currentInboxPublicKey()

        let pair = try manager.inboxPrivateKey(generation: 1)
        #expect(key.pub == pair.publicKey.rawRepresentation.base64URLEncodedString())
        #expect(key.keyId == KeyDerivation.keyID(forPublicKey: pair.publicKey.rawRepresentation))
        #expect(key.alg == "hpke-v1")
        #expect(key.pub.count == 43 && key.keyId.count == 11)
        #expect(key.pub.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil)
        #expect(key.keyId.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil)
    }

    @Test("The same recovery seed gives the same key on a new phone, a different seed a different key")
    func recoverable() throws {
        let first = KeyManager(store: InMemoryKeyStore(seed: seed))
        let restored = KeyManager(store: InMemoryKeyStore(seed: seed))
        let other = KeyManager(store: InMemoryKeyStore(seed: Data(repeating: 0x43, count: 16)))
        for manager in [first, restored, other] { try manager.prepare(createIfMissing: false) }
        #expect(try first.currentInboxPublicKey() == restored.currentInboxPublicKey())
        #expect(try first.currentInboxPublicKey() != other.currentInboxPublicKey())
    }

    @Test("While the keys are locked there is no key to publish")
    func locked() throws {
        let manager = KeyManager(store: InMemoryKeyStore(seed: seed))
        try manager.prepare(createIfMissing: false)
        manager.lock()
        #expect(throws: VaultError.locked) { try manager.currentInboxPublicKey() }
    }

    @Test("The key id is the first eight bytes of the SHA-256 of the public key, as the server recomputes it")
    func keyID() {
        let raw = Data((0..<32).map(UInt8.init))
        let expected = Data(SHA256.hash(data: raw).prefix(8)).base64URLEncodedString()
        #expect(KeyDerivation.keyID(forPublicKey: raw) == expected)
    }
}
