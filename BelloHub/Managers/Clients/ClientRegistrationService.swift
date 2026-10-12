//
//  ClientRegistrationService.swift
//  BelloHub
//

import Foundation
import Observation

/// The registration gate (D42, D59): the only way a client is created in the app. The free allowance is counted on
/// this iPhone, with no server call: the count is the larger of the vault ledger (every client id ever registered,
/// deleted ones included, in her iCloud) and the count kept in this iPhone's Keychain (`RegistrationAllowanceStoring`),
/// which survives deleting the app. A new, distinct client raises it by one; an edit or a duplicate (same id, or the
/// same phone as an existing client) does not; deleting a client never lowers it. Up to 10 are free; with a plan
/// (`SubscriptionStatusProviding`, proven on this iPhone) registrations are unlimited.
///
/// The first read after this version installs also raises the Keychain count to the ledger's, so accounts that already
/// registered clients keep their count (the migration of D59).
///
/// Created once at the root and read with `@Environment(ClientRegistrationService.self)`.
@MainActor
@Observable
final class ClientRegistrationService: ClientRegistering {
    private(set) var usage = RegistrationUsage.unknown

    @ObservationIgnored private let vault: VaultService
    @ObservationIgnored private let subscription: any SubscriptionStatusProviding
    @ObservationIgnored private let allowance: any RegistrationAllowanceStoring

    /// The app passes `KeychainRegistrationAllowanceStore`; UI-test launches, previews and tests keep the count in
    /// memory.
    init(
        vault: VaultService, subscription: any SubscriptionStatusProviding = UnsubscribedStatus(),
        allowance: any RegistrationAllowanceStoring = InMemoryRegistrationAllowanceStore()
    ) {
        self.vault = vault
        self.subscription = subscription
        self.allowance = allowance
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
        let current = quota(ledgerCount: ledger.count)
        guard current.decision(forNewClients: 1) == .allowed else {
            usage = RegistrationUsage(quota: current)
            return .needsSubscription
        }
        try await repository.save(client)
        // An id the ledger already holds (a deleted client's, coming back) was counted the first time.
        count(newClients: ledger.contains { $0.clientID == client.id } ? 0 : 1, before: current.used)
        await refreshUsage()
        return .registered
    }

    // MARK: - Many clients

    func knownClients() async throws -> [Client] {
        try await openRepository().allClients()
    }

    func importClients(_ clients: [Client]) async throws -> ClientImportResult {
        let repository = try openRepository()
        let (fresh, duplicates) = ClientDuplicateRules.partition(clients, existing: try await repository.allClients())
        var result = ClientImportResult(duplicates: duplicates.count)
        let ledger = try await repository.registrationLedger()
        let counted = Set(ledger.map(\.clientID))
        let current = quota(ledgerCount: ledger.count)
        let allowed: Int
        switch current.decision(forNewClients: fresh.count) {
        case .allowed: allowed = fresh.count
        case .allowedPartially(let count): allowed = count
        case .needsSubscription: allowed = 0
        }
        var newlyCounted = 0
        for client in fresh.prefix(allowed) {
            try await repository.save(client)
            result.registered += 1
            if !counted.contains(client.id) { newlyCounted += 1 }
        }
        count(newClients: newlyCounted, before: current.used)
        result.blocked = fresh.count - result.registered
        await refreshUsage()
        return result
    }

    // MARK: - Private

    /// The count as this iPhone knows it: the Keychain is raised to the ledger whenever the ledger is ahead (the first
    /// read after the update, or clients that arrived from the booking page), and never lowered.
    private func quota(ledgerCount: Int) -> RegistrationQuota {
        let stored = allowance.load() ?? 0
        if ledgerCount > stored { allowance.save(ledgerCount) }
        return RegistrationQuota(
            ledgerCount: ledgerCount, allowanceCount: stored, hasActivePlan: subscription.hasActivePlan
        )
    }

    /// `newClients` were just saved: the Keychain count goes up by that many from what was counted before.
    private func count(newClients: Int, before used: Int) {
        guard newClients > 0 else { return }
        allowance.save(max(allowance.load() ?? 0, used + newClients))
    }

    private func openRepository() throws -> any ClientRecordRepository {
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        return repository
    }
}
