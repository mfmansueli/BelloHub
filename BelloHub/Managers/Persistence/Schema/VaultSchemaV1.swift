//
//  VaultSchemaV1.swift
//  BelloHub
//

import Foundation
import SwiftData

/// Version 1 of the vault schema: **one** table. Every kind of record is a `VaultItem` told apart by `kindRaw`, with
/// a few clear columns to query by, the non-sensitive JSON, and the sealed sensitive part. Why one table:
/// - The CloudKit schema only grows in production. A new kind of record is a new `kindRaw`, not a new record type,
///   so adding features never changes the CloudKit schema.
/// - Every attribute has a default or is optional, there is no unique constraint and no relationship, which is
///   everything CloudKit sync requires. Relations are ids, and the repository cascades deletes itself.
/// The trade-off, recorded in `docs/spikes/SPIKE-swiftdata-cloudkit.md`: a conflict between two devices editing the
/// same record is resolved for the whole record (last writer wins), not field by field.
enum VaultSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
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
        /// The record as JSON with the sensitive properties removed.
        var plain: Data = Data()
        /// The sensitive properties, sealed with AES-GCM (nil when the record has none).
        var sealed: Data?
        /// A small sealed image for grids.
        var thumbnail: Data?
        /// Sealed photo bytes, kept as a file outside the database.
        @Attribute(.externalStorage) var blob: Data?
        var createdAt: Date = Date(timeIntervalSince1970: 0)
        var updatedAt: Date = Date(timeIntervalSince1970: 0)

        init(id: UUID, kindRaw: String, createdAt: Date, updatedAt: Date) {
            self.id = id
            self.kindRaw = kindRaw
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

/// The version the app runs on. A future version replaces this alias and adds a stage to `VaultMigrationPlan`.
typealias VaultItem = VaultSchemaV1.VaultItem
typealias CurrentVaultSchema = VaultSchemaV1
