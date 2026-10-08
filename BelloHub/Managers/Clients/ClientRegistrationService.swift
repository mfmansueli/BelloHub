//
//  ClientRegistrationService.swift
//  BelloHub
//

import Foundation
import Observation

/// The registration gate over the vault. It reads the ledger (every client id ever registered, deleted ones included),
/// asks `RegistrationQuota` what is allowed and saves through the repository, which appends the ledger entry the first
/// time an id is saved. Created once at the root and read with `@Environment(ClientRegistrationService.self)`.
@MainActor
@Observable
final class ClientRegistrationService: ClientRegistering {
    private(set) var usage = RegistrationUsage.unknown

    private let vault: VaultService
    private let subscription: any SubscriptionStatusProviding

    init(vault: VaultService, subscription: any SubscriptionStatusProviding = UnsubscribedStatus()) {
        self.vault = vault
        self.subscription = subscription
    }

    // MARK: - Counter

    func refreshUsage() async {
        guard let repository = vault.repository, let ledger = try? await repository.registrationLedger() else { return }
        usage = RegistrationUsage(quota: quota(ledgerCount: ledger.count))
    }

    // MARK: - One client

    func register(_ client: Client) async throws -> RegistrationOutcome {
        let repository = try openRepository()
        let existing = try await repository.allClients()
        if let match = ClientDuplicateRules.existing(matching: client, in: existing) {
            // The same id is an edit; the same phone under another id is a duplicate and saves nothing.
            guard match.id == client.id else { return .duplicate(existingID: match.id) }
            try await repository.save(client)
            return .updated
        }
        let ledger = try await repository.registrationLedger()
        guard quota(ledgerCount: ledger.count).decision(forNewClients: 1) == .allowed else {
            usage = RegistrationUsage(quota: quota(ledgerCount: ledger.count))
            return .needsSubscription
        }
        try await repository.save(client)
        await refreshUsage()
        return .registered
    }

    // MARK: - Many clients

    func importClients(_ clients: [Client]) async throws -> ClientImportResult {
        let repository = try openRepository()
        let (fresh, duplicates) = ClientDuplicateRules.partition(clients, existing: try await repository.allClients())
        var result = ClientImportResult(duplicates: duplicates.count)
        let ledger = try await repository.registrationLedger()
        let allowed: Int
        switch quota(ledgerCount: ledger.count).decision(forNewClients: fresh.count) {
        case .allowed: allowed = fresh.count
        case .allowedPartially(let count): allowed = count
        case .needsSubscription: allowed = 0
        }
        for client in fresh.prefix(allowed) {
            try await repository.save(client)
            result.registered += 1
        }
        result.blocked = fresh.count - allowed
        await refreshUsage()
        return result
    }

    // MARK: - Private

    private func quota(ledgerCount: Int) -> RegistrationQuota {
        RegistrationQuota(ledgerCount: ledgerCount, hasActivePlan: subscription.hasActivePlan)
    }

    private func openRepository() throws -> any ClientRecordRepository {
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        return repository
    }
}
