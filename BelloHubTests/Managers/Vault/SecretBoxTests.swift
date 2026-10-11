//
//  SecretBoxTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

@Suite("SecretBox")
struct SecretBoxTests {
    private let key = SymmetricKey(size: .bits256)
    private let aad = Data("client|1|importantNote".utf8)
    private let plaintext = Data("Allergic to fragrance. Sentinel-7Q2K".utf8)

    @Test("A sealed value opens to the original bytes")
    func roundTrip() throws {
        let sealed = try SecretBox.seal(plaintext, using: key, authenticating: aad)

        #expect(try SecretBox.open(sealed, using: key, authenticating: aad) == plaintext)
    }

    @Test("Empty and large payloads round-trip, and the version byte leads")
    func sizes() throws {
        for size in [0, 1, 16, 4_096, 400_000] {
            let payload = Data(repeating: 0xAB, count: size)
            let sealed = try SecretBox.seal(payload, using: key, authenticating: aad)

            #expect(sealed.first == SecretBox.currentVersion)
            #expect(sealed.count == size + 1 + 12 + 16, "size \(size)")
            #expect(try SecretBox.open(sealed, using: key, authenticating: aad) == payload)
        }
    }

    @Test("The plaintext never appears in the sealed bytes")
    func plaintextIsNotVisible() throws {
        let sealed = try SecretBox.seal(plaintext, using: key, authenticating: aad)

        #expect(sealed.range(of: Data("Sentinel-7Q2K".utf8)) == nil)
    }

    @Test("Sealing the same bytes twice gives different output (random nonce)")
    func nonceIsRandom() throws {
        let first = try SecretBox.seal(plaintext, using: key, authenticating: aad)
        let second = try SecretBox.seal(plaintext, using: key, authenticating: aad)

        #expect(first != second)
    }

    @Test("Flipping any single byte makes opening fail", arguments: [1, 5, 12, 13, 20, 30])
    func tamperedByteFails(position: Int) throws {
        var sealed = try SecretBox.seal(plaintext, using: key, authenticating: aad)
        let index = min(position, sealed.count - 1)
        sealed[sealed.startIndex + index] ^= 0x01

        #expect(throws: SecretBox.Failure.authenticationFailed) {
            try SecretBox.open(sealed, using: key, authenticating: aad)
        }
    }

    @Test("A different key fails")
    func wrongKeyFails() throws {
        let sealed = try SecretBox.seal(plaintext, using: key, authenticating: aad)

        #expect(throws: SecretBox.Failure.authenticationFailed) {
            try SecretBox.open(sealed, using: SymmetricKey(size: .bits256), authenticating: aad)
        }
    }

    @Test("Different associated data fails, so a field cannot move to another record")
    func wrongAADFails() throws {
        let sealed = try SecretBox.seal(plaintext, using: key, authenticating: aad)

        #expect(throws: SecretBox.Failure.authenticationFailed) {
            try SecretBox.open(sealed, using: key, authenticating: Data("client|2|importantNote".utf8))
        }
    }

    @Test("Truncated or empty input is malformed, an unknown version is reported")
    func malformedInput() throws {
        let sealed = try SecretBox.seal(plaintext, using: key, authenticating: aad)

        #expect(throws: SecretBox.Failure.malformed) { try SecretBox.open(Data(), using: key, authenticating: aad) }
        #expect(throws: SecretBox.Failure.malformed) {
            try SecretBox.open(sealed.prefix(20), using: key, authenticating: aad)
        }
        var future = sealed
        future[future.startIndex] = 9
        #expect(throws: SecretBox.Failure.unsupportedVersion(9)) {
            try SecretBox.open(future, using: key, authenticating: aad)
        }
    }

    @Test("A truncated tail fails authentication")
    func truncatedTail() throws {
        let sealed = try SecretBox.seal(plaintext, using: key, authenticating: aad)

        #expect(throws: SecretBox.Failure.authenticationFailed) {
            try SecretBox.open(sealed.dropLast(), using: key, authenticating: aad)
        }
    }

    /// NIST GCM specification, test case 3 (128-bit key, 96-bit IV, no AAD). Proves the wrapper adds nothing but
    /// the version byte to what AES-GCM itself produces.
    @Test("The wrapper's output matches a published AES-GCM known answer")
    func knownAnswer() throws {
        let key = SymmetricKey(data: Data(hexString: "feffe9928665731c6d6a8f9467308308"))
        let nonce = try AES.GCM.Nonce(data: Data(hexString: "cafebabefacedbaddecaf888"))
        let plaintext = Data(hexString: """
            d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a72\
            1c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255
            """)
        let expectedCiphertext = """
            42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e\
            21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091473f5985
            """
        let expectedTag = "4d5c2af327cd64a62cf35abd2ba6fab4"

        let sealed = try SecretBox.seal(plaintext, using: key, authenticating: Data(), nonce: nonce)

        #expect(sealed.hexString == "01" + "cafebabefacedbaddecaf888" + expectedCiphertext + expectedTag)
        #expect(try SecretBox.open(sealed, using: key, authenticating: Data()) == plaintext)
    }
}
