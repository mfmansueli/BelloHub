//
//  RegistrationAllowanceStoring.swift
//  BelloHub
//

import Foundation

/// Where this iPhone keeps how many clients were ever registered for the free allowance (D42, D59). The app keeps it
/// in the Keychain, on this device only (`KeychainRegistrationAllowanceStore`), so deleting and reinstalling the app on
/// this iPhone does not reset it; nothing of the Security framework reaches a View or a ViewModel. The count only ever
/// goes up: callers save the larger value.
protocol RegistrationAllowanceStoring: Sendable {
    /// The stored count; nil when nothing is stored yet or it could not be read (the caller then relies on the ledger).
    func load() -> Int?
    /// Stores the count. A failure is logged inside, without personal data, and never stops a registration.
    func save(_ count: Int)
}
