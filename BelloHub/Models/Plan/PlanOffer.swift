//
//  PlanOffer.swift
//  BelloHub
//

import Foundation

/// One purchasable product as the store describes it: the **localized** price StoreKit returns (`displayPrice`),
/// never a price typed in code (D33), plus the decimal value `PlanSavings` compares.
struct PlanOffer: Hashable, Identifiable, Sendable {
    let period: PlanPeriod
    /// "R$ 39,90", "€14.99": written by the storefront, shown as is.
    let displayPrice: String
    let price: Decimal

    var id: PlanPeriod { period }
}
