//
//  RecoveryKeyViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("RecoveryKeyViewModel, RestoreKeyViewModel and RecoveryWordsPresentation")
struct RecoveryKeyViewModelTests {
    private struct World {
        let service: RecoveryKeyService
        let printer: FakeDocumentPrinter
        let viewModel: RecoveryKeyViewModel
        let defaults: UserDefaults
        let suite: String
    }

    private func makeWorld(biometrics: [BiometricResult] = [.success]) throws -> World {
        let suite = "recovery-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let manager = KeyManager(store: InMemoryKeyStore(seed: VaultVectors.entropy))
        try manager.prepare(createIfMissing: false)
        let service = RecoveryKeyService(
            keyManager: manager, biometrics: FakeBiometrics(biometrics), defaults: defaults, now: { TestClock.now }
        )
        let printer = FakeDocumentPrinter()
        let viewModel = RecoveryKeyViewModel(service: service, printer: printer, businessName: "Glow Studio")
        return World(service: service, printer: printer, viewModel: viewModel, defaults: defaults, suite: suite)
    }

    @Test("The grid is masked until Face ID reveals it, and confirming needs the words shown plus the switch")
    func revealAndConfirm() async throws {
        let world = try makeWorld()
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel
        #expect(viewModel.cells.count == 12)
        #expect(viewModel.cells.allSatisfy { $0.text == RecoveryWordsPresentation.mask })
        viewModel.confirmsSafe = true
        #expect(!viewModel.canConfirm, "she cannot confirm what she has not seen")
        viewModel.confirmSaved()
        #expect(viewModel.status == .notSaved)

        await viewModel.revealAsync()

        #expect(viewModel.isRevealed)
        #expect(viewModel.cells.map(\.text).joined(separator: " ") == VaultVectors.mnemonic)
        #expect(viewModel.cells.map(\.position) == Array(1...12))
        #expect(viewModel.canConfirm)
        viewModel.confirmSaved()
        #expect(viewModel.done)
        #expect(viewModel.status == .saved(on: TestClock.now))

        viewModel.clear()
        #expect(!viewModel.isRevealed, "the words leave memory with the screen")
    }

    @Test("A failed Face ID shows the notice; a missing key names the restore path")
    func revealNotices() async throws {
        let world = try makeWorld(biometrics: [.failed])
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        await world.viewModel.revealAsync()
        #expect(world.viewModel.revealNotice == .notRecognized)
        #expect(!world.viewModel.isRevealed)

        let suite = "recovery-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }
        let noKey = RecoveryKeyViewModel(
            service: RecoveryKeyService(
                keyManager: KeyManager(store: InMemoryKeyStore()), biometrics: FakeBiometrics([.success]),
                defaults: defaults
            ),
            printer: FakeDocumentPrinter(), businessName: ""
        )
        await noKey.revealAsync()
        #expect(noKey.revealNotice == .noKey)
    }

    @Test("Save to Files writes a protected text file with the numbered words; print sends the same text")
    func fileAndPrint() async throws {
        let world = try makeWorld()
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel
        #expect(viewModel.prepareFile(locale: Locale(identifier: "en")) == nil, "nothing before the reveal")
        await viewModel.revealAsync()

        let url = try #require(viewModel.prepareFile(locale: Locale(identifier: "en")))
        let text = try String(contentsOf: url, encoding: .utf8)

        #expect(url.lastPathComponent == RecoveryWordsPresentation.fileName)
        #expect(text.hasPrefix("Bello Hub recovery key\nGlow Studio\n\n1. abandon\n2. math\n"))
        #expect(text.contains("12. young\n"))
        #expect(text.contains("Keep this away from your iPhone."))
        viewModel.printKey(locale: Locale(identifier: "en"))
        #expect(world.printer.jobs.first?.text == text)
        #expect(world.printer.jobs.first?.jobName == RecoveryWordsPresentation.fileName)

        viewModel.discardExport()
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Restore counts the typed words, names a bad one by position, and installs a good phrase")
    func restore() throws {
        let suite = "restore-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = InMemoryKeyStore()
        let manager = KeyManager(store: store)
        try manager.prepare(createIfMissing: false)
        let viewModel = RestoreKeyViewModel(service: RecoveryKeyService(
            keyManager: manager, biometrics: FakeBiometrics([.success]), defaults: defaults
        ))

        viewModel.text = "abandon math mimic"
        #expect(viewModel.typedCount == 3)
        #expect(!viewModel.canRestore)
        viewModel.restore()
        #expect(viewModel.issue == .wordCount(3))

        viewModel.text = VaultVectors.mnemonic.replacingOccurrences(of: "filter", with: "fliter")
        #expect(viewModel.canRestore)
        viewModel.restore()
        #expect(viewModel.issue == .unknownWord(position: 5))
        #expect(!viewModel.restored)

        viewModel.text = VaultVectors.mnemonic
        viewModel.restore()
        #expect(viewModel.restored)
        #expect(viewModel.issue == nil)
        #expect(try store.loadSeed() == VaultVectors.entropy)
        #expect(manager.status == .unlocked)
    }

    @Test("Typed words are counted on any whitespace")
    func typedCount() {
        #expect(RecoveryWordsPresentation.typedWordCount("  a \n b\tc  ") == 3)
        #expect(RecoveryWordsPresentation.typedWordCount("") == 0)
    }
}
