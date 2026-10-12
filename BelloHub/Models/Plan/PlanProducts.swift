//
//  PlanProducts.swift
//  BelloHub
//

import Foundation

/// The two products of the one paid plan "Bello Hub Pro" (D33): same features, no trial, no introductory offer. The
/// ids come from `Config/App.xcconfig` (`BELLO_PLAN_MONTHLY_PRODUCT_ID`, `BELLO_PLAN_YEARLY_PRODUCT_ID`) through the
/// Info.plist, so no Swift file holds them; the fallback is only for a build whose settings are broken.
struct PlanProducts: Equatable, Sendable {
    /// The plan's name, a brand: never localized.
    static let groupName = "Bello Hub Pro"

    let monthly: String
    let yearly: String

    static let monthlyKey = "BelloPlanMonthlyProductID"
    static let yearlyKey = "BelloPlanYearlyProductID"

    /// D33's ids, used only when the Info.plist has no value.
    static let fallback = PlanProducts(monthly: "com.bellohub.pro.monthly", yearly: "com.bellohub.pro.yearly")

    /// What this build was configured with.
    static let current = PlanProducts(info: Bundle.main.infoDictionary ?? [:])

    init(monthly: String, yearly: String) {
        self.monthly = monthly
        self.yearly = yearly
    }

    /// Reads the two keys of an Info.plist dictionary; a missing or blank value falls back one by one.
    init(info: [String: Any]) {
        monthly = Self.value(info[Self.monthlyKey]) ?? Self.fallback.monthly
        yearly = Self.value(info[Self.yearlyKey]) ?? Self.fallback.yearly
    }

    var all: [String] { [monthly, yearly] }

    func productID(for period: PlanPeriod) -> String {
        switch period {
        case .monthly: monthly
        case .yearly: yearly
        }
    }

    /// The period a store product id stands for; nil for anything that is not this plan.
    func period(forProductID id: String) -> PlanPeriod? {
        switch id {
        case monthly: .monthly
        case yearly: .yearly
        default: nil
        }
    }

    private static func value(_ raw: Any?) -> String? {
        guard let text = (raw as? String)?.trimmingCharacters(in: .whitespaces), !text.isEmpty,
              !text.hasPrefix("$(") else { return nil }
        return text
    }
}
