//
//  KeychainKeyStoreTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

/// Runs against the real iOS Keychain of the simulator. Each test uses its own service name and deletes its item.
@Suite("KeychainKeyStore")
struct KeychainKeyStoreTests {
    private func makeStore() -> KeychainKeyStore {
        KeychainKeyStore(
            service: "app.bellohub.tests.\(UUID().uuidString)", account: "seed.v1", isSynchronizable: false
        )
    }

    @Test("Nothing is stored at first, a saved seed is read back, and delete removes it")
    func saveLoadDelete() throws {
        let store = makeStore()
        defer { try? store.deleteSeed() }

        #expect(try store.loadSeed() == nil)
        try store.saveSeed(VaultVectors.entropy)
        #expect(try store.loadSeed() == VaultVectors.entropy)
        try store.deleteSeed()
        #expect(try store.loadSeed() == nil)
    }

    @Test("Saving again replaces the seed instead of failing on the duplicate")
    func saveTwiceReplaces() throws {
        let store = makeStore()
        defer { try? store.deleteSeed() }

        try store.saveSeed(Data(repeating: 1, count: 16))
        try store.saveSeed(Data(repeating: 2, count: 16))

        #expect(try store.loadSeed() == Data(repeating: 2, count: 16))
    }

    @Test("Deleting a seed that is not there is not an error")
    func deleteMissing() throws {
        try makeStore().deleteSeed()
    }

    @Test("A KeyManager on the real Keychain keeps the same keys across instances")
    @MainActor
    func keyManagerOnKeychain() throws {
        let store = makeStore()
        defer { try? store.deleteSeed() }

        let first = KeyManager(store: store)
        try first.prepare(createIfMissing: true)
        let firstKey = try first.keyProvider.vaultKey().withUnsafeBytes { Data($0).hexString }

        let second = KeyManager(store: store)
        try second.prepare(createIfMissing: false)
        let secondKey = try second.keyProvider.vaultKey().withUnsafeBytes { Data($0).hexString }

        #expect(firstKey == secondKey)
    }
}
