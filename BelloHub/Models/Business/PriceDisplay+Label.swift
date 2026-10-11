//
//  PriceDisplay+Label.swift
//  BelloHub
//

import Foundation

extension PriceDisplay {
    /// The choice as the service form words it: "Show price", "Starting from", "Price on request", "Hide price".
    var label: LocalizedStringResource {
        switch self {
        case .show: "services.priceMode.show"
        case .startingFrom: "services.priceMode.startingFrom"
        case .onRequest: "services.priceMode.onRequest"
        case .hide: "services.priceMode.hide"
        }
    }
}
