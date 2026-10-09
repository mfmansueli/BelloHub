//
//  PlanPeriod.swift
//  BelloHub
//

import Foundation

/// How often the one plan bills (D33). Both periods include exactly the same features.
enum PlanPeriod: String, CaseIterable, Identifiable, Sendable {
    case monthly
    case yearly

    var id: String { rawValue }

    var product: PlanProduct {
        switch self {
        case .monthly: .monthly
        case .yearly: .yearly
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .monthly: "plan.monthly"
        case .yearly: "plan.yearly"
        }
    }

    /// "a month" / "a year", after the price.
    var perPeriod: LocalizedStringResource {
        switch self {
        case .monthly: "plan.perMonth"
        case .yearly: "plan.perYear"
        }
    }

    init?(productID: String) {
        guard let product = PlanProduct(rawValue: productID) else { return nil }
        self = product == .monthly ? .monthly : .yearly
    }
}
