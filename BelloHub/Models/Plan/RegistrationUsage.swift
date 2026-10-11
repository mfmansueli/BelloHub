//
//  RegistrationUsage.swift
//  BelloHub
//

import Foundation

/// How many of the free client registrations she has used (D42), for the "x of 10 used" counter. A snapshot of
/// `RegistrationQuota` in the words a screen needs.
struct RegistrationUsage: Equatable, Sendable {
    let used: Int
    let limit: Int
    /// With a plan registrations are unlimited: the counter and the limit message are hidden.
    let isUnlimited: Bool

    init(quota: RegistrationQuota) {
        used = quota.used
        limit = RegistrationQuota.freeLimit
        isUnlimited = quota.hasActivePlan
    }

    /// Nothing known yet (the first instant, before the ledger was read).
    static let unknown = RegistrationUsage(quota: RegistrationQuota(ledgerCount: 0, hasActivePlan: false))

    var remainingFree: Int { max(limit - used, 0) }
    var isFreeAllowanceUsed: Bool { used >= limit }
}
