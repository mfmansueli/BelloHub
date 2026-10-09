//
//  PlanPresentation.swift
//  BelloHub
//

import Foundation

/// What the Plan screen (7.3) derives from the store's answer: the saving on the yearly plan (from the localized
/// prices, D42), which period is highlighted, and the status line. Pure, so the arithmetic and the wording rules are
/// tested without StoreKit.
struct PlanPresentation: Equatable, Sendable {
    let offers: [PlanOffer]
    let state: SubscriptionState

    /// The yearly saving in whole percent, when both prices are known and the yearly one is cheaper.
    var savingsPercent: Int? {
        guard let monthly = offers.first(where: { $0.period == .monthly }),
              let yearly = offers.first(where: { $0.period == .yearly }) else { return nil }
        return PlanSavings.annualSavingsPercent(monthlyPrice: monthly.price, yearlyPrice: yearly.price)
    }

    /// The yearly plan is highlighted whenever it saves something; otherwise nothing is.
    var highlighted: PlanPeriod? {
        savingsPercent == nil ? nil : .yearly
    }

    /// The period a new buyer starts on: the highlighted one, else monthly.
    var defaultChoice: PlanPeriod { highlighted ?? .monthly }

    var isActive: Bool { state.hasActivePlan }

    /// The features every plan includes (D33: identical on both periods), in display order.
    static let features: [String] = [
        "plan.feature.unlimited", "plan.feature.booking", "plan.feature.followUps", "plan.feature.photos",
        "plan.feature.records"
    ]
}
