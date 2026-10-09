//
//  RecoveryKeyServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

/// The recovery key door (7.9) and the exit criterion of S10: wipe the vault key, type the 12 words back, and the
/// records sealed before decrypt again.
@MainActor
@Suite("RecoveryKeyService")
struct RecoveryKeyServiceTests {
    private let recordID = UUID()

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "recovery-key-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite) ?? .standard, suite)
    }

    private func seal(_ text: String, with manager: KeyManager) throws -> Data {
        try VaultFieldCodec(keys: manager.keyProvider)
            .sealData(Data(text.utf8), model: "record", id: recordID, field: "notes")
    }

    private func open(_ data: Data, with manager: KeyManager) throws -> String {
        let bytes = try VaultFieldCodec(keys: manager.keyProvider)
            .openData(data, model: "record", id: recordID, field: "notes")
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    @Test("The words are revealed only after Face ID succeeded; a refusal and a cancel show nothing")
    func reveal() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = KeyManager(store: InMemoryKeyStore(seed: VaultVectors.entropy))
        try manager.prepare(createIfMissing: false)
        let biometrics = FakeBiometrics([.failed, .cancelled, .success])
        let service = RecoveryKeyService(keyManager: manager, biometrics: biometrics, defaults: defaults)

        #expect(await service.reveal() == .notRecognized)
        #expect(await service.reveal() == .cancelled)
        let outcome = await service.reveal()
        guard case .revealed(let phrase) = outcome else {
            Issue.record("expected the phrase, got \(outcome)")
            return
        }
        #expect(phrase.words.joined(separator: " ") == VaultVectors.mnemonic, "the known-answer vector")
        #expect(biometrics.calls == 3, "one prompt per call, never cached")
    }

    @Test("Without a passcode there is nothing stronger to ask, so the words show; without a seed there is no key")
    func unavailableAndNoKey() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = KeyManager(store: InMemoryKeyStore(seed: VaultVectors.entropy))
        try manager.prepare(createIfMissing: false)
        let open = RecoveryKeyService(
            keyManager: manager, biometrics: FakeBiometrics([.unavailable]), defaults: defaults
        )
        if case .revealed = await open.reveal() {} else { Issue.record("expected the phrase") }

        let empty = RecoveryKeyService(
            keyManager: KeyManager(store: InMemoryKeyStore()), biometrics: FakeBiometrics([.success]),
            defaults: defaults
        )
        #expect(await empty.reveal() == .noKey)
    }

    @Test("Restore on a new phone: wipe the seed, type the 12 words, the old records decrypt")
    func restoreFromWords() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let oldPhone = KeyManager(store: InMemoryKeyStore())
        try oldPhone.prepare(createIfMissing: true)
        let sealed = try seal("Sentinel-NOTES", with: oldPhone)
        let words = try oldPhone.recoveryPhrase().words.joined(separator: " ")

        let newStore = InMemoryKeyStore()
        let newPhone = KeyManager(store: newStore)
        try newPhone.prepare(createIfMissing: false)
        #expect(newPhone.status == .needsRestore)
        #expect(throws: (any Error).self) { _ = try open(sealed, with: newPhone) }
        let service = RecoveryKeyService(
            keyManager: newPhone, biometrics: FakeBiometrics([.success]), defaults: defaults
        )

        try service.restore(words: "  " + words.uppercased() + "\n")

        #expect(newPhone.status == .unlocked)
        #expect(try open(sealed, with: newPhone) == "Sentinel-NOTES")
        #expect(try newStore.loadSeed() == (try oldPhone.recoveryPhrase().entropy))
    }

    @Test("A wrong word, a wrong count and a bad checksum are named, and nothing is installed")
    func restoreFailures() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = InMemoryKeyStore()
        let service = RecoveryKeyService(
            keyManager: KeyManager(store: store), biometrics: FakeBiometrics([.success]), defaults: defaults
        )
        var words = VaultVectors.mnemonic.split(separator: " ").map(String.init)

        #expect(throws: RecoveryPhrase.Failure.wrongWordCount(11)) {
            try service.restore(words: words.dropLast().joined(separator: " "))
        }
        words[2] = "zzzz"
        #expect(throws: RecoveryPhrase.Failure.unknownWord(position: 3)) {
            try service.restore(words: words.joined(separator: " "))
        }
        words[2] = "mimic"
        words[11] = "abandon"
        #expect(throws: RecoveryPhrase.Failure.checksumMismatch) {
            try service.restore(words: words.joined(separator: " "))
        }
        #expect(try store.loadSeed() == nil)
    }

    @Test("The saved status is a local date that survives a new service, and nothing secret")
    func savedStatus() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = KeyManager(store: InMemoryKeyStore())
        let service = RecoveryKeyService(keyManager: manager, defaults: defaults, now: { TestClock.now })
        #expect(service.status == .notSaved)

        service.markSaved()

        #expect(service.status == .saved(on: TestClock.now))
        #expect(RecoveryKeyService(keyManager: manager, defaults: defaults).status.savedAt == TestClock.now)
        #expect(defaults.dictionaryRepresentation().values.compactMap { $0 as? String }
            .allSatisfy { !$0.contains("abandon") })
    }
}
