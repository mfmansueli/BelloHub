//
//  SubscriptionVerifying.swift
//  BelloHub
//

/// The server's word on a purchase (CLAUDE.md section 2: purchases are re-verified on the server before anything is
/// unlocked; D33: App Store Server Notifications). S8 wires the real call; until then the offline verifier trusts
/// the store's own signed transaction, which StoreKit 2 already verifies on the device.
protocol SubscriptionVerifying: Sendable {
    /// Tells the server a purchase or renewal happened and returns what the server now believes. A thrown error means
    /// the server could not be reached; the caller keeps the store's answer and tries again later.
    func verify(_ state: SubscriptionState) async throws -> SubscriptionState
}
