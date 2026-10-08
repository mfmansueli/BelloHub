//
//  RegistrationLedgerEntry.swift
//  BelloHub
//

import Foundation

/// One line of the registration ledger: a client id and the day it was first saved. **No name, no phone, no personal
/// data**, which is why it may stay after the client is deleted (the client's own data is erased; this only keeps
/// the count honest). One entry per client id ever registered, and an entry is never removed.
struct RegistrationLedgerEntry: Identifiable, Hashable, Codable, Sendable {
    var id: UUID { clientID }
    let clientID: UUID
    let registeredAt: Date
}
