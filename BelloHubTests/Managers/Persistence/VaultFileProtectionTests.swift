//
//  VaultFileProtectionTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// docs/06 section 4.4: the vault store's protection class is set explicitly, on the store, its SQLite companions and
/// its folder, and read back from the file system.
@Suite("VaultFileProtection")
struct VaultFileProtectionTests {
    @Test("The class is the one docs/06 asks for: readable for background sync after the first unlock")
    func level() {
        #expect(VaultFileProtection.level == .completeUntilFirstUserAuthentication)
    }

    @Test("The store's SQLite companions are covered")
    func files() {
        let store = URL(fileURLWithPath: "/tmp/vault/default.store")
        #expect(VaultFileProtection.files(of: store).map(\.lastPathComponent)
            == ["default.store", "default.store-wal", "default.store-shm"])
    }

    @Test("A real store opened through the factory gets the class with no failure")
    func appliedByFactory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("protection-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("vault.store")

        _ = try VaultContainerFactory.make(storage: .file(store))

        #expect(VaultFileProtection.apply(to: store).isEmpty, "every existing file accepted the class")
        #expect(VaultFileProtection.isProtected(store))
        for file in VaultFileProtection.files(of: store) where FileManager.default.fileExists(atPath: file.path) {
            #expect(VaultFileProtection.isProtected(file), "\(file.lastPathComponent)")
        }
    }
}
