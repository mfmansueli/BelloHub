//
//  PlanSavingsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PlanSavings and PlanProduct")
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

    @Test("The two product ids and the group are the ones of D33")
    func productIdentifiers() {
        #expect(PlanProduct.monthly.rawValue == "com.bellohub.pro.monthly")
        #expect(PlanProduct.yearly.rawValue == "com.bellohub.pro.yearly")
        #expect(PlanProduct.groupName == "Bello Hub Pro")
        #expect(PlanProduct.allCases.count == 2)
    }
}
