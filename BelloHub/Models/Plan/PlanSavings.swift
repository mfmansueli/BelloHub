//
//  PlanSavings.swift
//  BelloHub
//

import Foundation

/// How much cheaper the yearly plan is than twelve monthly payments, from the **localized prices StoreKit returns**,
/// so the percentage is right in every storefront and never typed in code.
enum PlanSavings {
    /// The saving in whole percent, rounded to the nearest, or nil when the yearly plan is not cheaper by at least
    /// one percent. 149.99 against 12 x 14.99 is 17 %; 399.90 against 12 x 39.90 is 16.5 %, shown as 16 %.
    static func annualSavingsPercent(monthlyPrice: Decimal, yearlyPrice: Decimal) -> Int? {
        let twelveMonths = monthlyPrice * 12
        guard monthlyPrice > 0, yearlyPrice > 0, yearlyPrice < twelveMonths else { return nil }
        var fraction = (twelveMonths - yearlyPrice) / twelveMonths * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &fraction, 0, .plain)
        let percent = NSDecimalNumber(decimal: rounded).intValue
        return percent >= 1 ? percent : nil
    }
}
