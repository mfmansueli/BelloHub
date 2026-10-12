//
//  SubscriptionError.swift
//  BelloHub
//

/// What the store can refuse.
enum SubscriptionError: Error, Equatable {
    /// The product is not in this storefront (or App Store Connect has not been set up, H14).
    case productUnavailable
    /// Apple's signature on the transaction did not check out: nothing is unlocked.
    case unverified
}
