//
//  PricingTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Pricing")
struct PricingTests {
    private func price(_ text: String) -> Decimal {
        Decimal(string: text) ?? 0
    }

    @Test("Each display mode decides what is shown, and a missing price is never invented")
    func labels() {
        #expect(Pricing.label(amount: price("120"), display: .show) == .exact(price("120")))
        #expect(Pricing.label(amount: price("120"), display: .startingFrom) == .startingFrom(price("120")))
        #expect(Pricing.label(amount: price("120"), display: .onRequest) == .onRequest)
        #expect(Pricing.label(amount: price("120"), display: .hide) == .hidden)
        #expect(Pricing.label(amount: nil, display: .show) == .hidden)
        #expect(Pricing.label(amount: nil, display: .startingFrom) == .onRequest)
    }

    @Test("The total adds what is shown: service 120 plus add-on 30 is 150")
    func exactTotal() {
        let service = Pricing.Item(amount: price("120"), display: .show)
        let addOn = Pricing.Item(amount: price("30"), display: .show)

        #expect(Pricing.total(of: [service, addOn]) == PriceTotal(amount: price("150"), isStartingFrom: false))
    }

    @Test("A hidden, on-request or from price makes the total a floor, never an exact sum")
    func floorTotal() {
        let shown = Pricing.Item(amount: price("120"), display: .show)

        #expect(Pricing.total(of: [shown, Pricing.Item(amount: price("30"), display: .hide)])?.isStartingFrom == true)
        #expect(Pricing.total(of: [shown, Pricing.Item(amount: nil, display: .onRequest)])?.isStartingFrom == true)
        #expect(Pricing.total(of: [Pricing.Item(amount: price("120"), display: .startingFrom)])
            == PriceTotal(amount: price("120"), isStartingFrom: true))
    }

    @Test("Nothing shown means no total")
    func noTotal() {
        #expect(Pricing.total(of: []) == nil)
        #expect(Pricing.total(of: [Pricing.Item(amount: price("50"), display: .hide)]) == nil)
        #expect(Pricing.total(of: [Pricing.Item(amount: nil, display: .show)]) == nil)
    }

    @Test("Decimal sums have no floating-point drift: 0.1 + 0.2 is exactly 0.3")
    func decimalExactness() {
        let first = Pricing.Item(amount: price("0.1"), display: .show)
        let second = Pricing.Item(amount: price("0.2"), display: .show)

        #expect(Pricing.total(of: [first, second])?.amount == price("0.3"))
    }

    @Test("A service and an add-on are built into items by the same rule")
    func itemsFromModels() {
        let service = Service(name: "Glow Facial", durationMinutes: 60, priceAmount: price("120"), priceDisplay: .show)
        let addOn = AddOn(id: UUID(), name: "Eyebrows", minutes: 15, priceAmount: price("30"), isOffered: true,
                          position: 0)
        let total = Pricing.total(of: [Pricing.Item(service), Pricing.Item(addOn, display: service.priceDisplay)])

        #expect(total?.amount == price("150"))
    }
}
