//
//  PriceLabel.swift
//  BelloHub
//

import Foundation

/// What the page shows for one price. Information only: nothing is ever charged (D4).
enum PriceLabel: Equatable, Sendable {
    case hidden
    case exact(Decimal)
    case startingFrom(Decimal)
    case onRequest
}
