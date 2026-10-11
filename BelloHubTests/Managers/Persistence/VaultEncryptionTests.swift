//
//  VaultEncryptionTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import SwiftData
import Testing

/// What reaches the disk (docs/06-PRIVACY-SECURITY.md section 11, tests 1 to 4). These run against a real SQLite file.
@Suite("Vault encryption on disk", .serialized)
@MainActor
struct VaultEncryptionTests {
    private let clock = MutableClock()

    /// A throwaway folder for one store, removed when the test ends.
    private struct Scratch {
        let directory: URL
        var store: URL { directory.appendingPathComponent("vault.store") }

        init() throws {
            let name = "vault-test-\(UUID().uuidString)"
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }

        /// Every byte of every file the store wrote: the database, its write-ahead log, and external storage.
        func allBytes() throws -> [Data] {
            let enumerator = FileManager.default.enumerator(at: directory,
                                                            includingPropertiesForKeys: [.isRegularFileKey])
            var found: [Data] = []
            while let url = enumerator?.nextObject() as? URL {
                if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    found.append(try Data(contentsOf: url))
                }
            }
            return found
        }
    }

    private func makeRepository(
        at url: URL, key: SymmetricKey, cloudKit: String? = nil
    ) throws -> (SwiftDataClientRecordRepository, ModelContainer) {
        let container = try VaultContainerFactory.make(storage: .file(url), cloudKitContainerID: cloudKit)
        let codec = VaultFieldCodec(keys: FixedKeyProvider(key: key))
        let clock = self.clock
        let repository = SwiftDataClientRecordRepository(modelContainer: container, codec: codec,
                                                         clock: { clock.now })
        return (repository, container)
    }

    // MARK: - No clinical plaintext on disk

    /// Writes a sentinel string into every sensitive field of every kind.
    private func writeSentinelRecords(_ repository: SwiftDataClientRecordRepository) async throws {
        let start = TestClock.date("2026-09-30 15:00")

        let client = Client(
            name: "Ana Costa", phoneE164: "+5511987654321", createdAt: start,
            importantNote: "SENTINEL-CLIENT-NOTE", allergies: ["SENTINEL-ALLERGY"], sensitivities: ["SENTINEL-SENS"],
            preferences: ["SENTINEL-PREF"], recurringRequests: ["SENTINEL-REQUEST"], stopReason: "SENTINEL-STOP"
        )
        try await repository.save(client)
        try await repository.save(Appointment(clientID: client.id, serviceName: "Glow Facial", startsAt: start,
                                              endsAt: start.addingTimeInterval(3_600), createdAt: start,
                                              privateNote: "SENTINEL-APPT"))
        let record = TreatmentRecord(clientID: client.id, serviceName: "Glow Facial", createdAt: start,
                                     notes: "SENTINEL-NOTES", technique: "SENTINEL-TECH",
                                     productsUsed: ["SENTINEL-PRODUCT"],
                                     resultDetail: "SENTINEL-RESULT", aftercare: "SENTINEL-AFTER",
                                     nextSessionSuggestion: "SENTINEL-NEXT")
        try await repository.save(record)
        clock.set(record.lockedAt.addingTimeInterval(1))
        try await repository.addCorrection(RecordCorrection(id: UUID(), recordID: record.id, createdAt: clock.now,
                                                            fieldKey: "notes", oldValue: "SENTINEL-OLD",
                                                            newValue: "SENTINEL-NEW", reason: "SENTINEL-WHY"))
        try await repository.save(Incident(id: UUID(), clientID: client.id, recordID: record.id, occurredAt: start,
                                           severity: .mild, lockedAt: start, needsFollowUp: false,
                                           symptoms: "SENTINEL-SYMPTOMS", area: "SENTINEL-AREA",
                                           actionTaken: "SENTINEL-ACTION", followUp: "SENTINEL-FOLLOW"))
        try await repository.save(HealthForm(id: UUID(), clientID: client.id, formVersion: 1, filledBy: .client,
                                             isForMinor: true, signedAt: start, importedFromItemID: "item-9",
                                             answers: ["conditions": .text("SENTINEL-ANSWER")],
                                             minorName: "SENTINEL-MINOR"))
        try await repository.save(ConsentRecord(
            id: UUID(), clientID: client.id, kind: .treatment, isSigned: true, signedAt: start, createdAt: start,
            label: "SENTINEL-LABEL", note: "SENTINEL-CONSENTNOTE",
            document: ConsentDocument(
                kind: .photo, fileName: "SENTINEL-FILENAME", contentType: "public.jpeg",
                data: Data("SENTINEL-CONSENTIMG".utf8), thumbnail: Data("SENTINEL-CONSENTTHUMB".utf8)
            )
        ))
        let photoBytes = Data("SENTINEL-PHOTO-BYTES-".utf8) + Data(repeating: 0xAB, count: 4_000)
        try await repository.save(Photo(id: UUID(), clientID: client.id, recordID: record.id, takenAt: start,
                                        kind: .before, visibility: .professionalOnly),
                                  data: PhotoData(image: photoBytes, thumbnail: Data("SENTINEL-THUMB".utf8)))
    }

    @Test("No sensitive field of any kind is readable in the store files, while the clear columns are")
    func sentinelsAreNotOnDisk() async throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let (repository, _) = try makeRepository(at: scratch.store, key: SymmetricKey(size: .bits256))
        try await writeSentinelRecords(repository)

        let files = try scratch.allBytes()
        let sentinels = [
            "SENTINEL-CLIENT-NOTE", "SENTINEL-ALLERGY", "SENTINEL-SENS", "SENTINEL-PREF", "SENTINEL-REQUEST",
            "SENTINEL-STOP", "SENTINEL-APPT", "SENTINEL-NOTES", "SENTINEL-TECH", "SENTINEL-PRODUCT",
            "SENTINEL-RESULT", "SENTINEL-AFTER", "SENTINEL-NEXT", "SENTINEL-OLD", "SENTINEL-NEW",
            "SENTINEL-WHY", "SENTINEL-SYMPTOMS", "SENTINEL-AREA", "SENTINEL-ACTION", "SENTINEL-FOLLOW",
            "SENTINEL-ANSWER", "SENTINEL-MINOR", "SENTINEL-LABEL", "SENTINEL-CONSENTNOTE", "SENTINEL-FILENAME",
            "SENTINEL-CONSENTIMG", "SENTINEL-CONSENTTHUMB", "SENTINEL-PHOTO-BYTES-", "SENTINEL-THUMB"
        ]

        #expect(!files.isEmpty)
        for sentinel in sentinels {
            let needle = Data(sentinel.utf8)
            #expect(!files.contains { $0.range(of: needle) != nil }, "\(sentinel) is readable on disk")
        }
        // Positive control: the clear columns do hold the name, so a scan that finds nothing is not just blind.
        #expect(files.contains { $0.range(of: Data("Ana Costa".utf8)) != nil })
    }

    @Test("The clear JSON of every kind holds none of its sensitive keys")
    func plainJSONExcludesSensitiveKeys() throws {
        let start = TestClock.date("2026-09-30 15:00")
        let client = Client(name: "Ana", createdAt: start, importantNote: "x", allergies: ["a"], stopReason: "r")
        let appointment = Appointment(clientID: client.id, serviceName: "Glow", startsAt: start,
                                      endsAt: start.addingTimeInterval(60), createdAt: start, privateNote: "p")
        let record = TreatmentRecord(clientID: client.id, serviceName: "Glow", createdAt: start, notes: "n",
                                     technique: "t", productsUsed: ["p"], resultDetail: "d", aftercare: "a",
                                     nextSessionSuggestion: "s")

        func plainKeys<Value: VaultStorable>(_ value: Value) throws -> Set<String> {
            let split = try VaultCoding.split(value)
            let object = try JSONSerialization.jsonObject(with: split.plain) as? [String: Any]
            return Set(object?.keys.map { $0 } ?? [])
        }

        #expect(try plainKeys(client).isDisjoint(with: Client.sensitiveKeys))
        #expect(try plainKeys(appointment).isDisjoint(with: Appointment.sensitiveKeys))
        #expect(try plainKeys(record).isDisjoint(with: TreatmentRecord.sensitiveKeys))
        #expect(try VaultCoding.split(client).sensitive != nil)
    }

    @Test("The sensitive keys are exactly the ones docs/05-DATA-MODEL.md section 1 lists")
    func sensitiveKeysMatchTheDataModel() {
        #expect(Client.sensitiveKeys == ["importantNote", "allergies", "sensitivities", "preferences",
                                         "recurringRequests", "stopReason"])
        #expect(Appointment.sensitiveKeys == ["privateNote"])
        #expect(TreatmentRecord.sensitiveKeys == ["notes", "technique", "productsUsed", "resultDetail", "aftercare",
                                                  "nextSessionSuggestion", "fieldEntries"])
        #expect(RecordCorrection.sensitiveKeys == ["oldValue", "newValue", "reason"])
        #expect(Incident.sensitiveKeys == ["symptoms", "area", "actionTaken", "followUp"])
        #expect(HealthForm.sensitiveKeys == ["answers", "minorName"])
        #expect(ConsentRecord.sensitiveKeys == ["label", "note", "document"])
        #expect(Photo.sensitiveKeys.isEmpty, "photo bytes are sealed separately, not as JSON keys")
    }

    // MARK: - Keys

    @Test("Data written with one key reads back after reopening the store with the same key")
    func reopenWithSameKey() async throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let key = SymmetricKey(size: .bits256)
        let client = Client(name: "Ana", createdAt: clock.now, importantNote: "kept")
        do {
            let (repository, _) = try makeRepository(at: scratch.store, key: key)
            try await repository.save(client)
        }

        let (reopened, _) = try makeRepository(at: scratch.store, key: key)

        #expect(try await reopened.client(id: client.id)?.importantNote == "kept")
    }

    @Test("A wrong key never looks like an empty vault: reading fails")
    func wrongKeyFails() async throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        do {
            let (repository, _) = try makeRepository(at: scratch.store, key: SymmetricKey(size: .bits256))
            try await repository.save(Client(name: "Ana", createdAt: clock.now, importantNote: "secret"))
        }

        let (stranger, _) = try makeRepository(at: scratch.store, key: SymmetricKey(size: .bits256))

        await #expect(throws: VaultRepositoryError.unreadable) { _ = try await stranger.allClients() }
    }

    @Test("A locked vault can neither read nor write")
    func lockedVault() async throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let key = SymmetricKey(size: .bits256)
        let (open, container) = try makeRepository(at: scratch.store, key: key)
        try await open.save(Client(name: "Ana", createdAt: clock.now, importantNote: "secret"))

        let locked = SwiftDataClientRecordRepository(
            modelContainer: container, codec: VaultFieldCodec(keys: FixedKeyProvider(key: nil))
        )

        await #expect(throws: VaultError.locked) { _ = try await locked.allClients() }
        await #expect(throws: VaultError.locked) {
            try await locked.save(Client(name: "Bia", createdAt: TestClock.now, importantNote: "x"))
        }
    }

    @Test("Restoring on a new phone with the 12 words opens records written on the old one")
    func restoreFromRecoveryWords() async throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let oldPhone = KeyManager(store: InMemoryKeyStore())
        try oldPhone.prepare(createIfMissing: true)
        let words = try oldPhone.recoveryPhrase().displayText
        let client = Client(name: "Ana", createdAt: clock.now, importantNote: "Sentinel-RESTORE", allergies: ["a"])
        do {
            let container = try VaultContainerFactory.make(storage: .file(scratch.store))
            let repository = SwiftDataClientRecordRepository(
                modelContainer: container, codec: VaultFieldCodec(keys: oldPhone.keyProvider)
            )
            try await repository.save(client)
        }

        let newPhone = KeyManager(store: InMemoryKeyStore())
        try newPhone.restore(from: RecordedPhrase.parse(words))
        let container = try VaultContainerFactory.make(storage: .file(scratch.store))
        let restored = SwiftDataClientRecordRepository(
            modelContainer: container, codec: VaultFieldCodec(keys: newPhone.keyProvider)
        )

        #expect(try await restored.client(id: client.id)?.importantNote == "Sentinel-RESTORE")
    }

    // MARK: - Tampering and binding

    private func flipAByte(in container: ModelContainer, kind: VaultKind, named name: String) throws {
        let context = ModelContext(container)
        let raw = kind.rawValue
        let items = try context.fetch(FetchDescriptor<VaultItem>(predicate: #Predicate { $0.kindRaw == raw }))
        let target = try #require(items.first { $0.textKey == name })
        var sealed = try #require(target.sealed)
        sealed[sealed.startIndex + 20] ^= 0x01
        target.sealed = sealed
        try context.save()
    }

    @Test("A flipped byte in a sealed field makes that record unreadable, and the others still read")
    func tamperIsDetected() async throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let (repository, container) = try makeRepository(at: scratch.store, key: SymmetricKey(size: .bits256))
        let ana = Client(name: "Ana", createdAt: clock.now, importantNote: "a")
        let bia = Client(name: "Bia", createdAt: clock.now, importantNote: "b")
        try await repository.save(ana)
        try await repository.save(bia)

        try flipAByte(in: container, kind: .client, named: "Ana")

        await #expect(throws: VaultRepositoryError.unreadable) { _ = try await repository.client(id: ana.id) }
        #expect(try await repository.allClients().map(\.name) == ["Bia"])
    }

    @Test("A sealed field copied onto another record does not open there")
    func sealedFieldCannotBeMoved() async throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let (repository, container) = try makeRepository(at: scratch.store, key: SymmetricKey(size: .bits256))
        let ana = Client(name: "Ana", createdAt: clock.now, importantNote: "a")
        let bia = Client(name: "Bia", createdAt: clock.now, importantNote: "b")
        try await repository.save(ana)
        try await repository.save(bia)

        let context = ModelContext(container)
        let items = try context.fetch(FetchDescriptor<VaultItem>(predicate: #Predicate { $0.kindRaw == "client" }))
        let anaItem = try #require(items.first { $0.textKey == "Ana" })
        let biaItem = try #require(items.first { $0.textKey == "Bia" })
        biaItem.sealed = anaItem.sealed
        try context.save()

        await #expect(throws: VaultRepositoryError.unreadable) { _ = try await repository.client(id: bia.id) }
        #expect(try await repository.client(id: ana.id)?.importantNote == "a")
    }

    // MARK: - Photos

    @Test("Photo bytes are sealed in external storage and the thumbnail decrypts")
    func photoBytesAreSealed() async throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let (repository, _) = try makeRepository(at: scratch.store, key: SymmetricKey(size: .bits256))
        let client = Client(name: "Ana", createdAt: clock.now)
        try await repository.save(client)
        let marker = Data("PHOTO-MARKER-0123456789".utf8)
        let photo = Photo(id: UUID(), clientID: client.id, recordID: nil, takenAt: clock.now, kind: .before,
                          visibility: .professionalOnly)
        let image = marker + Data((0..<8_000).map { UInt8($0 % 256) })
        try await repository.save(photo, data: PhotoData(image: image, thumbnail: Data("thumb".utf8)))

        let files = try scratch.allBytes()

        #expect(!files.contains { $0.range(of: marker) != nil })
        #expect(try await repository.photoData(id: photo.id).thumbnail == Data("thumb".utf8))
        #expect(try await repository.photoData(id: photo.id).image == image)
    }
}

/// Test-only shorthand for parsing recovery words.
enum RecordedPhrase {
    static func parse(_ words: String) throws -> RecoveryPhrase {
        try RecoveryPhrase(parsing: words)
    }
}
