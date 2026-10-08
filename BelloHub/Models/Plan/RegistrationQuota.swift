//
//  RegistrationQuota.swift
//  BelloHub
//

/// The free-registration rule (D42): the first 10 clients ever registered are free, the count is cumulative and a
/// deleted client never gives a slot back. It is **the only place** that knows the number 10.
///
/// `used` is the larger of the vault ledger (ids and dates in her iCloud, survives a delete and a reinstall) and the
/// server's count when it is known, so deleting local data can never lower it. Existing clients are never touched:
/// this type only answers whether a *new* client may be added.
struct RegistrationQuota: Equatable, Sendable {
    static let freeLimit = 10

    let used: Int
    let hasActivePlan: Bool

    init(ledgerCount: Int, serverCount: Int? = nil, hasActivePlan: Bool) {
        self.used = max(ledgerCount, serverCount ?? 0, 0)
        self.hasActivePlan = hasActivePlan
    }

    var remainingFree: Int {
        max(Self.freeLimit - used, 0)
    }

    /// The free registrations are all used. With a plan registrations are unlimited, but the count keeps going.
    var isFreeAllowanceUsed: Bool {
        used >= Self.freeLimit
    }

    /// May `count` new clients be added now? Importing 30 contacts with 4 free slots left allows 4 and offers the
    /// paywall for the rest. A plan allows everything.
    func decision(forNewClients count: Int = 1) -> RegistrationDecision {
        guard count > 0, !hasActivePlan else { return .allowed }
        if count <= remainingFree { return .allowed }
        return remainingFree > 0 ? .allowedPartially(count: remainingFree) : .needsSubscription
    }
}
