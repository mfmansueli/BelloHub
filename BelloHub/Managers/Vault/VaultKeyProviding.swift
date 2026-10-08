//
//  VaultKeyProviding.swift
//  BelloHub
//

import CryptoKit

/// Where the codec gets the vault key. It is a protocol so tests inject a fixed key, and `Sendable` because
/// the repository runs off the main actor while `KeyManager` lives on it.
protocol VaultKeyProviding: Sendable {
    /// The vault key, or `VaultError.locked` while the app is locked.
    func vaultKey() throws -> SymmetricKey
}
