//
//  OfflineSubscriptionVerifier.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// No server: the store's own answer stands and a purchase carries no account token. DEBUG only, for UI-test launches
/// (no network) and previews; the app uses `RemoteSubscriptionVerifier`.
struct OfflineSubscriptionVerifier: SubscriptionVerifying {
    func purchaseToken() async throws -> UUID? {
        nil
    }

    func verify(_ state: SubscriptionState, signedTransaction: String?) async throws -> SubscriptionState {
        state
    }
}
#endif
