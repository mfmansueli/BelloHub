//
//  VaultService.swift
//  BelloHub
//

import Foundation
import Observation

/// Owns the vault's one door for the app session: the repository every ViewModel reads and writes through.
/// Created once at the root (CLAUDE.md section 2) and read with `@Environment(VaultService.self)`.
@MainActor
@Observable
final class VaultService {
    /// Nil when the store could not be opened; `RootView` then shows an explanation instead of the app.
    let repository: (any ClientRecordRepository)?

    init(repository: (any ClientRecordRepository)?) {
        self.repository = repository
    }

    var isAvailable: Bool { repository != nil }

    /// The real vault on SwiftData. CloudKit stays off until the schema is deployed (human task H2); passing the
    /// container id here is all that turns sync on.
    static func live(keyManager: KeyManager, cloudKitContainerID: String? = nil) -> VaultService {
        do {
            let container = try VaultContainerFactory.make(storage: .standard, cloudKitContainerID: cloudKitContainerID)
            let codec = VaultFieldCodec(keys: keyManager.keyProvider)
            return VaultService(repository: SwiftDataClientRecordRepository(modelContainer: container, codec: codec))
        } catch {
            return VaultService(repository: nil)
        }
    }
}
