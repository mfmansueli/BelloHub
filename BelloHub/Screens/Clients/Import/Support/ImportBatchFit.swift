//
//  ImportBatchFit.swift
//  BelloHub
//

/// How much of a chosen batch the free registrations cover (D42). It only looks at the counter, so it is an upper
/// bound: the gate may skip duplicates first, which leaves free slots for more rows. The exact figures come back in
/// the result.
struct ImportBatchFit: Equatable, Sendable {
    /// The most that can be registered now.
    let willImport: Int
    /// What the free registrations do not cover: the paywall is offered for these.
    let waiting: Int

    init(selected: Int, usage: RegistrationUsage) {
        let chosen = max(selected, 0)
        willImport = usage.isUnlimited ? chosen : min(chosen, usage.remainingFree)
        waiting = chosen - willImport
    }

    var needsPlan: Bool { waiting > 0 }
}
