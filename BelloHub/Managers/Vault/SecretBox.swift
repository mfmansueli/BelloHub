//
//  SecretBox.swift
//  BelloHub
//

import CryptoKit
import Foundation

/// AES-256-GCM authenticated encryption for vault fields and photo bytes (D26). Output layout:
/// `version (1 byte) | nonce (12) | ciphertext | tag (16)`. The nonce is random per call, so sealing the same
/// bytes twice gives different output. `aad` is bound to the ciphertext: opening with a different `aad` fails,
/// which is how a field cannot be moved to another record or another column.
enum SecretBox {
    enum Failure: Error, Equatable {
        /// Too short to hold a version, a nonce and a tag.
        case malformed
        case unsupportedVersion(UInt8)
        /// Wrong key, wrong `aad`, or the bytes were changed. Deliberately one case: no oracle.
        case authenticationFailed
    }

    static let currentVersion: UInt8 = 1
    private static let overhead = 1 + 12 + 16

    static func seal(_ plaintext: Data, using key: SymmetricKey, authenticating aad: Data) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: aad)
        return assemble(box)
    }

    /// Fixed-nonce variant for known-answer tests only. Reusing a nonce with one key breaks GCM, so this is
    /// not reachable from the app: it is `internal` and only the tests call it.
    static func seal(_ plaintext: Data, using key: SymmetricKey, authenticating aad: Data, nonce: AES.GCM.Nonce) throws
        -> Data {
        assemble(try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad))
    }

    static func open(_ sealed: Data, using key: SymmetricKey, authenticating aad: Data) throws -> Data {
        guard sealed.count >= overhead else { throw Failure.malformed }
        let version = sealed[sealed.startIndex]
        guard version == currentVersion else { throw Failure.unsupportedVersion(version) }
        do {
            let box = try AES.GCM.SealedBox(combined: sealed.dropFirst())
            return try AES.GCM.open(box, using: key, authenticating: aad)
        } catch {
            throw Failure.authenticationFailed
        }
    }

    private static func assemble(_ box: AES.GCM.SealedBox) -> Data {
        var output = Data([currentVersion])
        output.append(box.combined ?? Data())
        return output
    }
}
