//
//  OfflineSubscriptionVerifier.swift
//  BelloHub
//

/// No server yet: the store's own answer stands. Replaced by the Firebase function in S8.
struct OfflineSubscriptionVerifier: SubscriptionVerifying {
    func verify(_ state: SubscriptionState) async throws -> SubscriptionState {
        state
    }
}
