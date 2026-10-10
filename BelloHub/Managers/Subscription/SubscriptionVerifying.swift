//
//  SubscriptionVerifying.swift
//  BelloHub
//

import Foundation

/// The server's word on a purchase (CLAUDE.md section 2: purchases are re-verified on the server before anything is
/// unlocked; D33, D42). The app uses `RemoteSubscriptionVerifier` (`ensureAccount` + `syncPlan`); DEBUG launches
/// without a server use `OfflineSubscriptionVerifier`, which trusts the store's own signed transaction.
protocol SubscriptionVerifying: Sendable {
    /// The account token the server issued for her (`ensureAccount.appAccountToken`), handed to the store at purchase
    /// so the transaction is tied to her account and the server can match it (`syncPlan`, App Store Server
    /// Notifications). Nil when the environment has no server. Throws when the server cannot be reached: a purchase
    /// without the token could never be matched to her, so it is not started.
    func purchaseToken() async throws -> UUID?

    /// Hands the store's signed transaction (the StoreKit 2 JWS of her current entitlement, nil when there is none) to
    /// the server and returns what the server now believes. A thrown error means the server could not be reached or is
    /// not set up; the caller keeps the store's answer and tries again later.
    func verify(_ state: SubscriptionState, signedTransaction: String?) async throws -> SubscriptionState
}
