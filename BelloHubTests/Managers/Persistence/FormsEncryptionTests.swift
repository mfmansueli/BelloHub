//
//  FormsEncryptionTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import SwiftData
import Testing

/// What reaches the disk for the S4 health records (docs/06-PRIVACY-SECURITY.md section 11, test 1): a sentinel
/// written through every sensitive field of a patch test, a health form and a guardian consent is not readable in the
/// store files, while the clear columns are. Follows `VaultEncryptionTests`.
@Suite("Health records encryption on disk", .serialized)
@MainActor
struct FormsEncryptionTests {
    private let clock = MutableClock()

    private struct Scratch {
        let directory: URL
        var store: URL { directory.appendingPathComponent("vault.store") }

        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("forms-test-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }

        func allBytes() throws -> [Data] {
            let enumerator = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey]
            )
            var found: [Data] = []
            while let url = enumerator?.nextObject() as? URL {
                if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    found.append(try Data(contentsOf: url))
                }
            }
            return found
        }
    }

    @Test("Patch test, health form and guardian consent sentinels are not readable on disk")
    func sentinelsAreNotOnDisk() async throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let container = try VaultContainerFactory.make(storage: .file(scratch.store), cloudKitContainerID: nil)
        let codec = VaultFieldCodec(keys: FixedKeyProvider(key: SymmetricKey(size: .bits256)))
        let now = clock.now
        let repository = SwiftDataClientRecordRepository(modelContainer: container, codec: codec, clock: { now })

        let client = Client(name: "Ana Costa", phoneE164: "+5511987654321", createdAt: now)
        try await repository.save(client)
        try await repository.save(PatchTest(
            id: UUID(), clientID: client.id, testedAt: now, observedHours: 48, product: "SENTINEL-PRODUCT",
            area: "SENTINEL-AREA", result: .mildReaction, notes: "SENTINEL-PATCHNOTES"
        ))
        try await repository.save(HealthForm(
            id: UUID(), clientID: client.id, formVersion: 1, filledBy: .professional, isForMinor: true, signedAt: now,
            importedFromItemID: nil, answers: ["notes": .text("SENTINEL-ANSWER"), "allergies": .choices(["latex"])],
            signatureImage: nil, guardianName: "SENTINEL-GUARDIAN", minorName: "SENTINEL-MINOR"
        ))
        try await repository.save(Consent(
            id: UUID(), clientID: client.id, kind: .guardian, signedAt: now, textVersion: "2026-10", localeID: "pt-BR",
            typedSignature: "SENTINEL-SIGNATURE", signatureImage: nil
        ))
        try await repository.save(makeHealthTemplate(version: 1, keys: ["allergies", "notes"]))

        let files = try scratch.allBytes()
        #expect(!files.isEmpty)
        for sentinel in ["SENTINEL-PRODUCT", "SENTINEL-AREA", "SENTINEL-PATCHNOTES", "SENTINEL-ANSWER",
                         "SENTINEL-GUARDIAN", "SENTINEL-MINOR", "SENTINEL-SIGNATURE"] {
            let needle = Data(sentinel.utf8)
            #expect(!files.contains { $0.range(of: needle) != nil }, "\(sentinel) is readable on disk")
        }
        // The result is health information too: its raw value is not stored in the clear JSON of the patch test.
        #expect(!files.contains { $0.range(of: Data("mildReaction".utf8)) != nil }, "the result is readable on disk")
        // Positive controls: the clear columns hold the name and the template's keys, so the scan is not blind.
        #expect(files.contains { $0.range(of: Data("Ana Costa".utf8)) != nil })
        #expect(files.contains { $0.range(of: Data("questionKeys".utf8)) != nil })
    }

    @Test("The sensitive keys are exactly the ones docs/05-DATA-MODEL.md lists, plus the patch test's")
    func sensitiveKeys() {
        #expect(PatchTest.sensitiveKeys == ["product", "area", "result", "notes"])
        #expect(HealthFormTemplate.sensitiveKeys.isEmpty, "which questions she asks is not clinical")
        #expect(HealthForm.sensitiveKeys == ["answers", "signatureImage", "guardianName", "minorName"])
        #expect(Consent.sensitiveKeys == ["typedSignature", "signatureImage"])
    }

    @Test("The clear JSON of a patch test holds none of its sensitive keys")
    func plainJSONExcludesSensitiveKeys() throws {
        let entry = PatchTest(
            id: UUID(), clientID: UUID(), testedAt: clock.now, observedHours: 24, product: "p", area: "a",
            result: .reaction, notes: "n"
        )
        let split = try VaultCoding.split(entry)
        let object = try #require(try JSONSerialization.jsonObject(with: split.plain) as? [String: Any])
        #expect(Set(object.keys).isDisjoint(with: PatchTest.sensitiveKeys))
        #expect(split.sensitive != nil)
    }

    @Test("A new vault kind never reuses a raw value, and the patch test and template kinds are new")
    func vaultKindsAreAppendOnly() {
        let raws = VaultKind.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
        #expect(VaultKind.healthFormTemplate.rawValue == "healthFormTemplate")
        #expect(VaultKind.patchTest.rawValue == "patchTest")
        // The kinds S2 and S3 shipped keep their names: they are part of every sealed field's associated data.
        for existing in ["client", "appointment", "service", "treatmentRecord", "correction", "incident", "photo",
                         "healthForm", "consent", "sessionPlan", "registration", "profile", "tag", "recordTemplate"] {
            #expect(raws.contains(existing))
        }
    }
}
