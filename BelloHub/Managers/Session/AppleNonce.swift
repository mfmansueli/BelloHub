//
//  AppleNonce.swift
//  BelloHub
//

import CryptoKit
import Foundation
import Security

/// The replay protection of a Sign in with Apple request: Apple puts the SHA-256 of `raw` into the token and the
/// backend checks the raw value, so a stolen token cannot be used for another sign-in. Pure, so it is tested.
struct AppleNonce: Equatable, Sendable {
    /// Characters allowed by the OAuth nonce convention.
    static let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

    let raw: String

    /// Hex SHA-256 of `raw`: what goes into the Apple request.
    var hashed: String { Self.sha256(raw) }

    /// A new nonce. `randomByte` is injectable for tests; the default is the system's secure generator.
    static func make(length: Int = 32, randomByte: () -> UInt8 = AppleNonce.secureRandomByte) -> AppleNonce {
        precondition(length > 0)
        var characters: [Character] = []
        characters.reserveCapacity(length)
        // Rejection sampling: discard bytes that would make some characters likelier than others.
        let limit = UInt8(256 - 256 % alphabet.count)
        while characters.count < length {
            let byte = randomByte()
            if byte < limit { characters.append(alphabet[Int(byte) % alphabet.count]) }
        }
        return AppleNonce(raw: String(characters))
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func secureRandomByte() -> UInt8 {
        var byte: UInt8 = 0
        let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
        precondition(status == errSecSuccess, "the system random generator failed")
        return byte
    }
}
