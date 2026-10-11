//
//  TimeBlockEncryptionTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

@Suite("Time block encryption", .serialized)
@MainActor
struct TimeBlockEncryptionTests {
    @Test("The reason is the one sealed field, and the clear JSON never holds it")
    func sealedReason() throws {
        #expect(TimeBlock.sensitiveKeys == ["reason"])
        let item = makeBlock(start: TestClock.date("2026-10-08 09:00"), reason: "Sentinel-BLOCK-REASON")
        let split = try VaultCoding.split(item)
        let object = try JSONSerialization.jsonObject(with: split.plain) as? [String: Any]
        #expect(object?["reason"] == nil)
        #expect(object?["startsAt"] != nil)
        #expect(split.sensitive != nil)
    }

    @Test("The reason never reaches the disk in the clear")
    func notOnDisk() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("block-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try VaultContainerFactory.make(storage: .file(directory.appendingPathComponent("vault.store")))
        let codec = VaultFieldCodec(keys: FixedKeyProvider(key: SymmetricKey(size: .bits256)))
        let repository = SwiftDataClientRecordRepository(modelContainer: container, codec: codec)
        try await repository.save(makeBlock(start: TestClock.date("2026-10-08 09:00"), reason: "Sentinel-BLOCK-REASON"))

        let urls = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)?.allObjects
            .compactMap { $0 as? URL } ?? []
        let files = urls.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .compactMap { try? Data(contentsOf: $0) }
        #expect(!files.isEmpty)
        #expect(!files.contains { $0.range(of: Data("Sentinel-BLOCK-REASON".utf8)) != nil })
    }
}
