//
//  ClientDataDeletionService.swift
//  BelloHub
//

import Foundation
import Observation

/// Deleting a client's data when she asks (D30, product rule 8): everything on the phone goes at once (the vault's
/// cascade: visits, records, photos, forms, consents, plans; the registration-ledger entry stays, D42), and the server
/// is told to forget her through the `OutboundQueue`, so the request survives being offline or a relaunch and is
/// retried until the server took it. Created with the inbox Services and read with `@Environment`.
@MainActor
@Observable
final class ClientDataDeletionService {
    private(set) var isDeleting = false

    @ObservationIgnored private let vault: VaultService
    @ObservationIgnored private let queue: OutboundQueue

    init(vault: VaultService, queue: OutboundQueue) {
        self.vault = vault
        self.queue = queue
    }

    /// Deletes her on the phone, then queues the server deletion. Throws when the vault could not delete (nothing is
    /// queued then: the server keeps her as long as the phone does).
    func deleteClientData(clientID: UUID) async throws {
        guard !isDeleting else { return }
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        isDeleting = true
        defer { isDeleting = false }
        let client = try await repository.client(id: clientID)
        let bookingIDs = try await repository.appointments(for: clientID).compactMap(\.bookingID)
        try await repository.deleteClient(id: clientID)
        for action in ClientServerDeletionPlan.actions(phone: client?.phoneE164, bookingIDs: bookingIDs) {
            queue.enqueue(action)
        }
    }
}
