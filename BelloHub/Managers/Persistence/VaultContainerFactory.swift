//
//  VaultContainerFactory.swift
//  BelloHub
//

import Foundation
import SwiftData

/// Builds the `ModelContainer` of the vault. Everything about where and how it is stored is decided here.
enum VaultContainerFactory {
    enum Storage: Equatable, Sendable {
        case inMemory
        case file(URL)
        /// The default store location of the app.
        case standard
    }

    /// - Parameters:
    ///   - cloudKitContainerID: pass `iCloud.com.bellohub` to sync through the professional's private CloudKit
    ///     database. Nil keeps the vault on this phone only (the default until the schema is deployed, H2).
    static func make(storage: Storage, cloudKitContainerID: String? = nil) throws -> ModelContainer {
        let cloudKit: ModelConfiguration.CloudKitDatabase = cloudKitContainerID.map { .private($0) } ?? .none
        let configuration: ModelConfiguration
        switch storage {
        case .inMemory:
            configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        case .file(let url):
            configuration = ModelConfiguration(url: url, cloudKitDatabase: cloudKit)
        case .standard:
            configuration = ModelConfiguration(cloudKitDatabase: cloudKit)
        }
        let container = try ModelContainer(
            for: Schema(versionedSchema: CurrentVaultSchema.self),
            migrationPlan: VaultMigrationPlan.self,
            configurations: configuration
        )
        if storage != .inMemory {
            // docs/06 section 4.4: the protection class is chosen here, not left to the default.
            VaultFileProtection.apply(to: configuration.url)
        }
        return container
    }
}
