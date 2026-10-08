//
//  VaultKeyHolder.swift
//  BelloHub
//

import CryptoKit
import Foundation
import os

/// The derived keys, in memory only and cleared on lock. A separate handle class (CLAUDE.md section 2,
/// concurrency) so it can be read from the repository's actor and torn down without the main actor.
final class VaultKeyHolder: VaultKeyProviding, Sendable {
    private struct Keys {
        var root: SymmetricKey?
        var vault: SymmetricKey?
    }

    private let keys = OSAllocatedUnfairLock(initialState: Keys())

    func install(entropy: Data) {
        let root = KeyDerivation.rootKey(entropy: entropy)
        let vault = KeyDerivation.vaultKey(rootKey: root)
        keys.withLock {
            $0.root = root
            $0.vault = vault
        }
    }

    func clear() {
        keys.withLock {
            $0.root = nil
            $0.vault = nil
        }
    }

    var isUnlocked: Bool {
        keys.withLock { $0.vault != nil }
    }

    func vaultKey() throws -> SymmetricKey {
        guard let key = keys.withLock({ $0.vault }) else { throw VaultError.locked }
        return key
    }

    func rootKey() throws -> SymmetricKey {
        guard let key = keys.withLock({ $0.root }) else { throw VaultError.locked }
        return key
    }
}
