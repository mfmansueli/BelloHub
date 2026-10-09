//
//  ServicePriceLineTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ServicePriceLine")
struct ServicePriceLineTests {
    private func line(_ amount: Decimal?, _ display: PriceDisplay) -> ServicePriceLine {
        ServicePriceLine(Service(name: "Glow", durationMinutes: 60, priceAmount: amount, priceDisplay: display))
    }

    @Test("Show price reads the amount, and nothing when none was entered")
    func show() {
        #expect(line(70, .show) == .exact(70))
        #expect(line(nil, .show) == .none)
    }

    @Test("Starting from reads the amount, and falls back to on request without one")
    func startingFrom() {
        #expect(line(70, .startingFrom) == .startingFrom(70))
        #expect(line(nil, .startingFrom) == .onRequest)
    }

    @Test("On request ignores the amount")
    func onRequest() {
        #expect(line(70, .onRequest) == .onRequest)
        #expect(line(nil, .onRequest) == .onRequest)
    }

    @Test("A price she hides says so in her own list, with or without an amount")
    func hidden() {
        #expect(line(70, .hide) == .hidden)
        #expect(line(nil, .hide) == .hidden)
    }

    @Test("It agrees with the booking page's rule everywhere but the hidden case")
    func agreesWithPricing() {
        for display in PriceDisplay.allCases where display != .hide {
            for amount in [nil, Decimal(25)] {
                let page = Pricing.label(amount: amount, display: display)
                switch (page, line(amount, display)) {
                case (.hidden, .none), (.onRequest, .onRequest): break
                case (.exact(let one), .exact(let two)), (.startingFrom(let one), .startingFrom(let two)):
                    #expect(one == two)
                default: Issue.record("\(display) with \(String(describing: amount)) differs from the booking page")
                }
            }
        }
    }
}
