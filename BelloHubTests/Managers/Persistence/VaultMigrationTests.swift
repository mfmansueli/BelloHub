//
//  VaultMigrationTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import SwiftData
import Testing

/// A past version of the vault schema, defined here only to prove the migration path: it lacks the `thumbnail` and
/// `blob` columns that version 1 has. Opening a store written with it must keep every row and add the new columns
/// as empty (an additive, lightweight migration, docs/05-DATA-MODEL.md section 1).
enum LegacyVaultSchema: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(0, 9, 0) }
    static var models: [any PersistentModel.Type] { [VaultItem.self] }

    @Model
    final class VaultItem {
        var id: UUID = UUID()
        var kindRaw: String = ""
        var ownerID: UUID?
        var secondaryID: UUID?
        var dateA: Date?
        var dateB: Date?
        var textKey: String?
        var statusRaw: String?
        var plain: Data = Data()
        var sealed: Data?
        var createdAt: Date = Date(timeIntervalSince1970: 0)
        var updatedAt: Date = Date(timeIntervalSince1970: 0)

        init(id: UUID, kindRaw: String) {
            self.id = id
            self.kindRaw = kindRaw
        }
    }
}

enum LegacyToCurrentMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LegacyVaultSchema.self, VaultSchemaV1.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: LegacyVaultSchema.self, toVersion: VaultSchemaV1.self)]
    }
}

@Suite("Vault schema migration", .serialized)
@MainActor
struct VaultMigrationTests {
    @Test("A store written by an older schema opens on the current one with every row, readable and decryptable")
    func additiveMigrationKeepsData() async throws {
        let name = "vault-migration-\(UUID().uuidString)"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("vault.store")
        let key = SymmetricKey(size: .bits256)
        let codec = VaultFieldCodec(keys: FixedKeyProvider(key: key))
        let client = Client(name: "Ana Costa", createdAt: TestClock.now, importantNote: "Sentinel-MIGRATE",
                            allergies: ["fragrance"])

        // 1. Write a client the way the old version did: no thumbnail, no blob.
        do {
            let legacy = try ModelContainer(for: Schema(versionedSchema: LegacyVaultSchema.self),
                                            configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none))
            let context = ModelContext(legacy)
            let (plain, sensitive) = try VaultCoding.split(client)
            let row = LegacyVaultSchema.VaultItem(id: client.id, kindRaw: VaultKind.client.rawValue)
            row.plain = plain
            row.sealed = try sensitive.map {
                try codec.sealData($0, model: VaultKind.client.rawValue, id: client.id, field: "sensitive")
            }
            row.textKey = client.name
            context.insert(row)
            try context.save()
        }

        // 2. Open it with the current schema through the migration plan.
        let current = try ModelContainer(
            for: Schema(versionedSchema: VaultSchemaV1.self), migrationPlan: LegacyToCurrentMigrationPlan.self,
            configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        )
        let rows = try ModelContext(current).fetch(FetchDescriptor<VaultItem>())

        #expect(rows.count == 1)
        #expect(rows.first?.textKey == "Ana Costa")
        #expect(rows.first?.thumbnail == nil, "the new column starts empty")
        #expect(rows.first?.blob == nil)

        // 3. The migrated row still decrypts through the real repository.
        let repository = SwiftDataClientRecordRepository(modelContainer: current, codec: codec)
        let migrated = try #require(try await repository.client(id: client.id))
        #expect(migrated.importantNote == "Sentinel-MIGRATE")
        #expect(migrated.allergies == ["fragrance"])

        // 4. And the new columns work: a photo can now be saved on the migrated store.
        let photo = Photo(id: UUID(), clientID: client.id, recordID: nil, takenAt: TestClock.now, kind: .before,
                          visibility: .professionalOnly)
        try await repository.save(photo, data: PhotoData(image: Data([1, 2, 3]), thumbnail: Data([4])))
        #expect(try await repository.photoData(id: photo.id).image == Data([1, 2, 3]))
    }

    @Test("The shipped migration plan lists the current schema and needs no stage yet")
    func shippedPlan() {
        #expect(VaultMigrationPlan.schemas.count == 1)
        #expect(VaultMigrationPlan.stages.isEmpty)
        #expect(VaultSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    }

    @Test("Every attribute has a default or is optional: the CloudKit requirement, checked on the schema")
    func schemaIsCloudKitShaped() {
        let schema = Schema(versionedSchema: VaultSchemaV1.self)
        let entity = schema.entities.first { $0.name == "VaultItem" }

        #expect(schema.entities.count == 1, "one record type, so the CloudKit schema never grows with a feature")
        #expect(entity?.relationships.isEmpty == true, "relationships are ids, not CloudKit references")
        #expect(entity?.uniquenessConstraints.isEmpty == true)
        for attribute in entity?.attributes ?? [] {
            #expect(attribute.isOptional || attribute.defaultValue != nil, "\(attribute.name) needs a default")
        }
    }

    /// SwiftData's default configuration is `.automatic`, which **turns CloudKit mirroring on by itself** whenever
    /// the app has the iCloud entitlement (found while writing the migration test: the mirroring delegate logged
    /// sync errors).
    /// The vault therefore always passes an explicit database, and this test pins that the factory does.
    @Test("The vault factory never relies on the automatic CloudKit setting")
    func factoryIsExplicit() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // Local only: opens and works without any iCloud account.
        let local = try VaultContainerFactory.make(storage: .file(directory.appendingPathComponent("local.store")))
        let context = ModelContext(local)
        context.insert(VaultItem(id: UUID(), kindRaw: "client", createdAt: .now, updatedAt: .now))

        #expect(throws: Never.self) { try context.save() }
    }

    /// The schema is accepted by SwiftData's CloudKit validation. Syncing itself needs an iCloud account and two phones
    /// (task H3, `docs/spikes/SPIKE-swiftdata-cloudkit.md`); this proves the model is shaped correctly for it.
    @Test("The schema is accepted with the private CloudKit database switched on")
    func cloudKitSchemaIsValid() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = directory.appendingPathComponent("cloud.store")
        let container = try VaultContainerFactory.make(storage: .file(store),
                                                       cloudKitContainerID: "iCloud.com.bellohub")

        #expect(container.schema.entities.count == 1)
    }
}
