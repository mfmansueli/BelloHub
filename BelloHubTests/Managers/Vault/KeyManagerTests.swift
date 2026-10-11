//
//  KeyManagerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

@MainActor
@Suite("KeyManager")
struct KeyManagerTests {
    private let id = UUID()

    private func seal(_ text: String, with manager: KeyManager) throws -> Data {
        try VaultFieldCodec(keys: manager.keyProvider)
            .sealData(Data(text.utf8), model: "client", id: id, field: "note")
    }

    private func open(_ data: Data, with manager: KeyManager) throws -> String {
        let plaintext = try VaultFieldCodec(keys: manager.keyProvider)
            .openData(data, model: "client", id: id, field: "note")
        return String(bytes: plaintext, encoding: .utf8) ?? ""
    }

    @Test("A first launch creates a seed and unlocks")
    func firstLaunch() throws {
        let store = InMemoryKeyStore()
        let manager = KeyManager(store: store)

        try manager.prepare(createIfMissing: true)

        #expect(manager.status == .unlocked)
        #expect(try store.loadSeed()?.count == 16)
    }

    @Test("A device that lost its seed asks to restore instead of silently starting a new vault")
    func missingSeedNeedsRestore() throws {
        let manager = KeyManager(store: InMemoryKeyStore())

        try manager.prepare(createIfMissing: false)

        #expect(manager.status == .needsRestore)
        #expect(throws: VaultError.locked) { _ = try seal("x", with: manager) }
    }

    @Test("An existing seed is used, not replaced")
    func existingSeedIsKept() throws {
        let store = InMemoryKeyStore(seed: VaultVectors.entropy)
        let manager = KeyManager(store: store)

        try manager.prepare(createIfMissing: true)

        #expect(try store.loadSeed() == VaultVectors.entropy)
        let vaultBytes = try manager.keyProvider.vaultKey().withUnsafeBytes { Data($0).hexString }
        #expect(vaultBytes == VaultVectors.vaultKey)
    }

    @Test("Locking clears the keys from memory and unlocking brings them back")
    func lockAndUnlock() throws {
        let manager = KeyManager(store: InMemoryKeyStore())
        try manager.prepare(createIfMissing: true)
        let sealed = try seal("Sentinel-LOCK", with: manager)

        manager.lock()
        #expect(manager.status == .locked)
        #expect(throws: VaultError.locked) { _ = try open(sealed, with: manager) }
        #expect(throws: VaultError.locked) { _ = try manager.inboxPrivateKey() }

        try manager.unlock()
        #expect(manager.status == .unlocked)
        #expect(try open(sealed, with: manager) == "Sentinel-LOCK")
    }

    @Test("Unlocking with no seed reports it")
    func unlockWithoutSeed() {
        let manager = KeyManager(store: InMemoryKeyStore())

        #expect(throws: VaultError.noSeed) { try manager.unlock() }
        #expect(manager.status == .needsRestore)
    }

    @Test("The recovery words restore a lost vault: records sealed before decrypt after a restore on an empty phone")
    func restoreOnAFreshPhone() throws {
        let original = KeyManager(store: InMemoryKeyStore())
        try original.prepare(createIfMissing: true)
        let sealed = try seal("Sentinel-RESTORE", with: original)
        let words = try original.recoveryPhrase().displayText

        let newPhone = KeyManager(store: InMemoryKeyStore())
        try newPhone.prepare(createIfMissing: false)
        #expect(newPhone.status == .needsRestore)
        try newPhone.restore(from: RecoveryPhrase(parsing: words))

        #expect(newPhone.status == .unlocked)
        #expect(try open(sealed, with: newPhone) == "Sentinel-RESTORE")
    }

    @Test("Wrong words do not open the old records")
    func wrongWordsDoNotDecrypt() throws {
        let original = KeyManager(store: InMemoryKeyStore())
        try original.prepare(createIfMissing: true)
        let sealed = try seal("Sentinel-WRONG", with: original)

        let stranger = KeyManager(store: InMemoryKeyStore())
        try stranger.restore(from: RecoveryPhrase(entropy: Data(repeating: 9, count: 16)))

        #expect(throws: SecretBox.Failure.authenticationFailed) { _ = try open(sealed, with: stranger) }
    }

    @Test("The inbox key of a restored vault is the same key: pending envelopes still open")
    func inboxKeySurvivesRestore() throws {
        let original = KeyManager(store: InMemoryKeyStore(seed: VaultVectors.entropy))
        try original.prepare(createIfMissing: false)
        let restored = KeyManager(store: InMemoryKeyStore())
        try restored.restore(from: RecoveryPhrase(parsing: VaultVectors.mnemonic))

        let first = try original.inboxPrivateKey(generation: 1).publicKey.rawRepresentation
        let second = try restored.inboxPrivateKey(generation: 1).publicKey.rawRepresentation

        #expect(first == second)
        #expect(first.hexString == VaultVectors.inboxPublicKey1)
    }

    @Test("Older inbox generations stay derivable after a rotation")
    func olderGenerationsStayAvailable() throws {
        let manager = KeyManager(store: InMemoryKeyStore(seed: VaultVectors.entropy))
        try manager.prepare(createIfMissing: false)

        #expect(try manager.inboxPrivateKey(generation: 1).publicKey.rawRepresentation.hexString
            == VaultVectors.inboxPublicKey1)
        #expect(try manager.inboxPrivateKey(generation: 2).publicKey.rawRepresentation.hexString
            == VaultVectors.inboxPublicKey2)
    }
}
