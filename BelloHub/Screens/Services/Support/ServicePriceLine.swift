//
//  ServicePriceLine.swift
//  BelloHub
//

import Foundation

/// What the price of a service reads in her own list. It follows `Pricing.label` (the rule the booking page uses) and
/// adds the one case only she needs to see: a price she has switched off, so she does not wonder where it went.
enum ServicePriceLine: Equatable, Sendable {
    /// No price to show: none entered, and nothing to say about it.
    case none
    case exact(Decimal)
    case startingFrom(Decimal)
    case onRequest
    /// She chose not to show the price on her page.
    case hidden

    init(_ service: Service) {
        if service.priceDisplay == .hide {
            self = .hidden
            return
        }
        switch Pricing.label(amount: service.priceAmount, display: service.priceDisplay) {
        case .hidden: self = .none
        case .exact(let amount): self = .exact(amount)
        case .startingFrom(let amount): self = .startingFrom(amount)
        case .onRequest: self = .onRequest
        }
    }
}
