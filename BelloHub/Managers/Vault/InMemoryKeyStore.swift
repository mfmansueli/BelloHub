//
//  InMemoryKeyStore.swift
//  BelloHub
//

#if DEBUG
import Foundation
import os

/// A seed that lives only in memory: previews, the Design Catalog and UI-test launches that must not touch the
/// real Keychain. In DEBUG only, because a Release build must never run without the real store.
final class InMemoryKeyStore: KeyStoring, Sendable {
    private let seed: OSAllocatedUnfairLock<Data?>

    init(seed: Data? = nil) {
        self.seed = OSAllocatedUnfairLock(initialState: seed)
    }

    func loadSeed() throws -> Data? {
        seed.withLock { $0 }
    }

    func saveSeed(_ newSeed: Data) throws {
        seed.withLock { $0 = newSeed }
    }

    func deleteSeed() throws {
        seed.withLock { $0 = nil }
    }
}
#endif
