//
//  PriceTotal.swift
//  BelloHub
//

import Foundation

/// The summed price of a visit, when enough of it is shown to add up.
struct PriceTotal: Equatable, Sendable {
    let amount: Decimal
    /// Some part has no shown price, or is "from": the total is a floor, not an exact sum.
    let isStartingFrom: Bool
}
