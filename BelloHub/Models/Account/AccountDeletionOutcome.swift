//
//  AccountDeletionOutcome.swift
//  BelloHub
//

/// What the server answered to a deletion. The device side (vault, key, session) is cleared whatever the answer, once
/// she confirmed; the outcome only decides what the last screen says.
enum AccountDeletionOutcome: Equatable, Sendable {
    /// The server removed her account, bookings and mailbox, and revoked the Apple token when there was one.
    case deleted
    /// The server removed the account but could not revoke the Apple token: she can do it in Settings > Apple ID.
    case deletedWithoutAppleRevocation
    /// A DEBUG launch with no server (UI tests, `-devLogin`): only this iPhone was cleared. The app itself never
    /// answers this: when the server cannot be reached nothing is deleted and she is asked to try again.
    case deviceOnly
}
