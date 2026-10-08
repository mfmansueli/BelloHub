//
//  ImportUITestSeeding.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// The clients a UI test wants registered before the import starts (`-uiRegisteredClients 8`), so the free-registration
/// limit can be reached with a few contacts. They go straight to the vault, then the counter is refreshed. DEBUG only.
enum ImportUITestSeeding {
    @MainActor
    static func seedIfRequested(_ dependencies: AppDependencies, options: LaunchOptions) async {
        guard let count = options.uiRegisteredClients, count > 0,
              let repository = dependencies.vault.repository else { return }
        for index in 1...count {
            let client = Client(
                name: "Seeded Client \(index)", phoneE164: String(format: "+1415555%04d", index), createdAt: Date()
            )
            _ = try? await repository.save(client)
        }
        await dependencies.registration.refreshUsage()
    }
}
#endif
