//
//  ClientRegistrationService.swift
//  BelloHub
//

import Foundation
import Observation

/// The registration gate (D42). The **server is the authority** for the count (`reserveRegistrations`): a new client
/// is saved only after the server counted her, or refused when the server says the free registrations are used and
/// there is no plan. The vault ledger (every client id ever registered, deleted ones included) and the last count the
/// server gave are the cache that answers at once and while offline:
/// - the cache already says "paywall": nothing is asked of the server and nothing is saved;
/// - the server cannot be reached: the client is saved on the cache's word and the claim waits in the
///   `OutboundQueue`, which replays it when the server answers (it never undoes her work afterwards);
/// - the server refused it for good (a phone with no server, a refused token): the cache's word stands.
///
/// Created once at the root and read with `@Environment(ClientRegistrationService.self)`.
@MainActor
@Observable
final class ClientRegistrationService: ClientRegistering {
    private(set) var usage = RegistrationUsage.unknown
    /// The last count the server gave (cache; the vault ledger may be higher after an offline registration).
    private(set) var serverCount: Int?

    @ObservationIgnored private let vault: VaultService
    @ObservationIgnored private let subscription: any SubscriptionStatusProviding
    @ObservationIgnored private let server: (any InboxRepository)?
    @ObservationIgnored private let queue: OutboundQueue?

    /// `server` and `queue` are nil in UI-test launches and previews: the vault ledger is the only count then.
    init(
        vault: VaultService, subscription: any SubscriptionStatusProviding = UnsubscribedStatus(),
        server: (any InboxRepository)? = nil, queue: OutboundQueue? = nil
    ) {
        self.vault = vault
        self.subscription = subscription
        self.server = server
        self.queue = queue
        queue?.observe { [weak self] _, outcome in
            guard case .registrations(let reservation) = outcome else { return }
            self?.adopt(serverCount: reservation.count)
        }
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
        guard quota(ledgerCount: ledger.count).decision(forNewClients: 1) == .allowed,
              await reserve([RegistrationClaim(client)]).contains(client.id) else {
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
        let allowedByCache: Int
        switch quota(ledgerCount: ledger.count).decision(forNewClients: fresh.count) {
        case .allowed: allowedByCache = fresh.count
        case .allowedPartially(let count): allowedByCache = count
        case .needsSubscription: allowedByCache = 0
        }
        let candidates = Array(fresh.prefix(allowedByCache))
        let allowed = await reserve(candidates.map(RegistrationClaim.init))
        for client in candidates where allowed.contains(client.id) {
            try await repository.save(client)
            result.registered += 1
        }
        result.blocked = fresh.count - result.registered
        await refreshUsage()
        return result
    }

    // MARK: - Server

    /// The ids the server counted, in groups of 200. Offline, every claim is allowed on the cache's word and queued
    /// for the server; with no server, or a permanent refusal of the call, the cache's word stands.
    private func reserve(_ claims: [RegistrationClaim]) async -> Set<UUID> {
        let everyone = Set(claims.map(\.clientID))
        guard let server, !claims.isEmpty else { return everyone }
        var allowed = Set<UUID>()
        for start in stride(from: 0, to: claims.count, by: Self.maxClaimsPerCall) {
            let chunk = Array(claims[start..<min(start + Self.maxClaimsPerCall, claims.count)])
            do {
                let reservation = try await server.reserveRegistrations(chunk)
                adopt(serverCount: reservation.count)
                allowed.formUnion(reservation.allowed)
            } catch let error as BookingRepositoryError where error == .unreachable || error == .busy {
                queue?.enqueue(.reserveRegistrations(claims: chunk))
                allowed.formUnion(chunk.map(\.clientID))
            } catch {
                allowed.formUnion(chunk.map(\.clientID))
            }
        }
        return allowed
    }

    /// The contract's cap for one `reserveRegistrations` call.
    private static let maxClaimsPerCall = 200

    private func adopt(serverCount count: Int) {
        serverCount = max(serverCount ?? 0, count)
        usage = RegistrationUsage(quota: RegistrationQuota(
            ledgerCount: usage.used, serverCount: serverCount, hasActivePlan: subscription.hasActivePlan
        ))
    }

    // MARK: - Private

    private func quota(ledgerCount: Int) -> RegistrationQuota {
        RegistrationQuota(ledgerCount: ledgerCount, serverCount: serverCount, hasActivePlan: subscription.hasActivePlan)
    }

    private func openRepository() throws -> any ClientRecordRepository {
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        return repository
    }
}
