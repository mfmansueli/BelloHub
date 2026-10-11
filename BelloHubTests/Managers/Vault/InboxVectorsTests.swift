//
//  InboxVectorsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

/// The sealed-mailbox vectors the web page and the backend test against (`web/test/vectors/inbox-v1.json`, copied into
/// the bundle by `scripts/sync-server-contract.sh`), opened with CryptoKit: proves the app's suite (docs/06 section 3)
/// is the one the page seals to, and that the key id the app publishes is the one the page and the server compute.
/// Reading the mailbox in the app is a later slice; this only pins the suite.
@Suite("Inbox vectors")
struct InboxVectorsTests {
    private final class BundleToken {}

    private static let suite = HPKE.Ciphersuite(kem: .Curve25519_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .chaChaPoly)

    private struct VectorRecipient: Decodable {
        let privateKey: String
        let publicKey: String
        let keyId: String
    }

    private struct VectorEnvelope: Decodable {
        let keyId: String
        let kind: String
        let itemId: String
        let enc: String
        let ct: String

        /// `bellohub/v1|<kind>|<itemId>|<keyId>`: what the page authenticates with, built from the envelope itself.
        var aad: Data { Data("bellohub/v1|\(kind)|\(itemId)|\(keyId)".utf8) }
    }

    private struct PositiveVector: Decodable {
        let name: String
        let recipient: String
        let aad: String
        let plaintext: String
        let envelope: VectorEnvelope
    }

    private struct NegativeVector: Decodable {
        let name: String
        let recipient: String
        let expect: String
        let envelope: VectorEnvelope
    }

    private struct Vectors: Decodable {
        let info: String
        let recipients: [String: VectorRecipient]
        let positive: [PositiveVector]
        let negative: [NegativeVector]
    }

    private static func vectors() throws -> Vectors {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "inbox-v1", withExtension: "json"))
        return try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: url))
    }

    private static func bytes(_ base64URL: String) throws -> Data {
        var text = base64URL.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        text += String(repeating: "=", count: (4 - text.count % 4) % 4)
        return try #require(Data(base64Encoded: text))
    }

    @Test("The key id the app publishes is the one the page and the server derive from the public key")
    func keyIDs() throws {
        let vectors = try Self.vectors()
        #expect(!vectors.recipients.isEmpty)
        for recipient in vectors.recipients.values {
            let publicKey = try Self.bytes(recipient.publicKey)
            #expect(KeyDerivation.keyID(forPublicKey: publicKey) == recipient.keyId)
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Self.bytes(recipient.privateKey))
            #expect(InboxPublicKey(publicKey: privateKey.publicKey).pub == recipient.publicKey)
        }
    }

    @Test("Every envelope the page seals opens with CryptoKit to the exact plaintext")
    func opensPositiveCases() throws {
        let vectors = try Self.vectors()
        #expect(!vectors.positive.isEmpty)
        for vector in vectors.positive {
            let recipient = try #require(vectors.recipients[vector.recipient])
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Self.bytes(recipient.privateKey))
            var opener = try HPKE.Recipient(
                privateKey: privateKey, ciphersuite: Self.suite, info: Data(vectors.info.utf8),
                encapsulatedKey: Self.bytes(vector.envelope.enc)
            )
            #expect(vector.envelope.aad == Data(vector.aad.utf8), "the AAD format is the envelope's fields")
            let opened = try opener.open(Self.bytes(vector.envelope.ct), authenticating: vector.envelope.aad)
            #expect(String(bytes: opened, encoding: .utf8) == vector.plaintext, Comment(rawValue: vector.name))
        }
    }

    @Test("A tampered or misaddressed envelope does not open")
    func rejectsNegativeCases() throws {
        let vectors = try Self.vectors()
        let cases = vectors.negative.filter { $0.expect == "open-fails" }
        #expect(!cases.isEmpty)
        for vector in cases {
            let recipient = try #require(vectors.recipients[vector.recipient])
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Self.bytes(recipient.privateKey))
            #expect(throws: (any Error).self, Comment(rawValue: "\(vector.name) must not open")) {
                var opener = try HPKE.Recipient(
                    privateKey: privateKey, ciphersuite: Self.suite, info: Data(vectors.info.utf8),
                    encapsulatedKey: Self.bytes(vector.envelope.enc)
                )
                _ = try opener.open(Self.bytes(vector.envelope.ct), authenticating: vector.envelope.aad)
            }
        }
    }
}
