//
//  StoreEntitlement.swift
//  BelloHub
//

import Foundation

/// One subscription as the App Store signed it, in the app's own terms: what `StoreKitSubscriptionProvider` hands on
/// after StoreKit checked Apple's signature (`VerificationResult.verified`). An unverified transaction never becomes
/// one of these. No StoreKit type crosses this line, so the rules that read it are pure and tested without a store.
struct StoreEntitlement: Equatable, Sendable {
    /// Where the subscription stands (StoreKit's `Product.SubscriptionInfo.RenewalState`).
    enum Renewal: String, Sendable {
        case subscribed
        case expired
        /// The last payment failed and Apple keeps retrying; access stops unless a grace period applies.
        case billingRetry
        /// The last payment failed and Apple keeps access open while she fixes it (Billing Grace Period).
        case gracePeriod
        /// Refunded or revoked by Apple.
        case revoked
    }

    let productID: String
    let renewal: Renewal
    /// The signed end of the period paid for (`Transaction.expirationDate`).
    let expiresAt: Date?
    /// Set when Apple refunded or revoked the transaction (`Transaction.revocationDate`).
    let revokedAt: Date?
    /// The signed end of the grace period (`RenewalInfo.gracePeriodExpirationDate`), when there is one.
    let graceExpiresAt: Date?
    let willAutoRenew: Bool

    init(
        productID: String, renewal: Renewal, expiresAt: Date?, revokedAt: Date? = nil, graceExpiresAt: Date? = nil,
        willAutoRenew: Bool = true
    ) {
        self.productID = productID
        self.renewal = renewal
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
        self.graceExpiresAt = graceExpiresAt
        self.willAutoRenew = willAutoRenew
    }
}
