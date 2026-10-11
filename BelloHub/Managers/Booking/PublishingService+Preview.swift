//
//  PublishingService+Preview.swift
//  BelloHub
//

extension PublishingService {
    /// A service with no server and no vault, for `#Preview` blocks: it never publishes and stays "not online".
    static var preview: PublishingService {
        PublishingService(
            repository: OfflineBookingRepository(),
            source: VaultPublishingSource(vault: VaultService(repository: nil), keys: KeyManager())
        )
    }
}
