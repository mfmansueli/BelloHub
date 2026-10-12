//
//  PlanSavingsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PlanSavings and PlanProducts")
struct PlanSavingsTests {
    @Test("Europe and the United States save about 17 percent: 149.99 against 12 x 14.99",
          arguments: [(Decimal(string: "14.99") ?? 0, Decimal(string: "149.99") ?? 0)])
    func euroAndDollar(monthly: Decimal, yearly: Decimal) {
        #expect(PlanSavings.annualSavingsPercent(monthlyPrice: monthly, yearlyPrice: yearly) == 17)
    }

    @Test("Brazil saves 16.5 percent: 399.90 against 12 x 39.90, shown as 16")
    func brazil() {
        let percent = PlanSavings.annualSavingsPercent(
            monthlyPrice: Decimal(string: "39.90") ?? 0, yearlyPrice: Decimal(string: "399.90") ?? 0
        )

        #expect(percent == 16)
    }

    @Test("A yearly price of exactly two months free is 17 percent")
    func twoMonthsFree() {
        #expect(PlanSavings.annualSavingsPercent(monthlyPrice: 10, yearlyPrice: 100) == 17)
    }

    @Test("No saving is shown when the yearly plan is not cheaper, or only by a fraction of a percent",
          arguments: [("10", "120"), ("10", "130"), ("10", "119.9"), ("0", "100"), ("10", "0"), ("-5", "50")])
    func noSaving(monthly: String, yearly: String) {
        let saving = PlanSavings.annualSavingsPercent(
            monthlyPrice: Decimal(string: monthly) ?? 0, yearlyPrice: Decimal(string: yearly) ?? 0
        )

        #expect(saving == nil)
    }

    @Test("The product ids come from the Info.plist, fall back to D33's one by one, and map back to their period")
    func productIdentifiers() {
        #expect(PlanProducts.fallback.monthly == "com.bellohub.pro.monthly")
        #expect(PlanProducts.fallback.yearly == "com.bellohub.pro.yearly")
        #expect(PlanProducts.groupName == "Bello Hub Pro")

        let configured = PlanProducts(info: [PlanProducts.monthlyKey: "x.monthly", PlanProducts.yearlyKey: " "])
        #expect(configured.monthly == "x.monthly")
        #expect(configured.yearly == PlanProducts.fallback.yearly, "a blank value falls back")
        #expect(PlanProducts(info: [PlanProducts.monthlyKey: "$(BELLO_PLAN_MONTHLY_PRODUCT_ID)"]).monthly
            == PlanProducts.fallback.monthly, "an unexpanded build setting falls back")
        #expect(configured.period(forProductID: "x.monthly") == .monthly)
        #expect(configured.period(forProductID: "other") == nil)
        #expect(configured.productID(for: .yearly) == PlanProducts.fallback.yearly)
    }
}
