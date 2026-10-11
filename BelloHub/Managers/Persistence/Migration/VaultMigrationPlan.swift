//
//  VaultMigrationPlan.swift
//  BelloHub
//

import SwiftData

/// The ordered schema versions and how to move between them. Only version 1 exists, so there are no stages yet. A
/// new version adds its `VersionedSchema` here and a stage; additive changes (a new optional column) are
/// `.lightweight`, and `VaultMigrationTests` proves that path on a real store.
enum VaultMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [VaultSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
