//
//  PriceDisplay.swift
//  BelloHub
//

/// How a service price appears on the public page. Prices are information only; nothing is ever charged (D4).
enum PriceDisplay: String, PersistedEnum {
    case show
    case startingFrom
    case onRequest
    case hide

    /// An unknown mode hides the price rather than showing a wrong one.
    static let fallback = PriceDisplay.hide
}
