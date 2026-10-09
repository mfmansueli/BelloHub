//
//  AppleNonceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("AppleNonce")
struct AppleNonceTests {
    @Test("The hash is the known SHA-256 of the raw value, in lowercase hex")
    func knownHash() {
        #expect(AppleNonce.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(AppleNonce(raw: "abc").hashed == AppleNonce.sha256("abc"))
    }

    @Test("A nonce has the requested length and only allowed characters")
    func lengthAndAlphabet() {
        let nonce = AppleNonce.make(length: 64)
        #expect(nonce.raw.count == 64)
        #expect(nonce.raw.allSatisfy { AppleNonce.alphabet.contains($0) })
    }

    @Test("Two nonces from the system generator differ")
    func differs() {
        #expect(AppleNonce.make().raw != AppleNonce.make().raw)
    }

    @Test("Bytes that would bias the alphabet are skipped")
    func rejectionSampling() {
        // 256 % 64 == 0 would accept everything; the alphabet has 65 characters, so the top bytes are refused.
        var bytes: [UInt8] = [255, 254, 0, 1, 2]
        let nonce = AppleNonce.make(length: 3) { bytes.removeFirst() }
        #expect(nonce.raw == String(AppleNonce.alphabet[0...2]))
    }
}
