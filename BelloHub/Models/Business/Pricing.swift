//
//  Pricing.swift
//  BelloHub
//

import Foundation

/// Display-only price rules. There is no payment, deposit, invoice or revenue anywhere in the product.
enum Pricing {
    struct Item: Sendable {
        let amount: Decimal?
        let display: PriceDisplay

        init(amount: Decimal?, display: PriceDisplay) {
            self.amount = amount
            self.display = display
        }

        init(_ service: Service) {
            self.init(amount: service.priceAmount, display: service.priceDisplay)
        }

        /// An add-on is shown by the same rule as its service.
        init(_ addOn: AddOn, display: PriceDisplay) {
            self.init(amount: addOn.priceAmount, display: display)
        }
    }

    static func label(amount: Decimal?, display: PriceDisplay) -> PriceLabel {
        switch display {
        case .hide: .hidden
        case .onRequest: .onRequest
        case .show: amount.map(PriceLabel.exact) ?? .hidden
        case .startingFrom: amount.map(PriceLabel.startingFrom) ?? .onRequest
        }
    }

    /// The total of what is shown. Nil when nothing shown has an amount. A part that is hidden, on request or "from"
    /// makes the total a floor.
    static func total(of items: [Item]) -> PriceTotal? {
        var sum = Decimal.zero
        var shown = 0
        var isFloor = false
        for item in items {
            switch label(amount: item.amount, display: item.display) {
            case .exact(let amount):
                sum += amount
                shown += 1
            case .startingFrom(let amount):
                sum += amount
                shown += 1
                isFloor = true
            case .hidden, .onRequest:
                isFloor = true
            }
        }
        return shown == 0 ? nil : PriceTotal(amount: sum, isStartingFrom: isFloor)
    }
}
