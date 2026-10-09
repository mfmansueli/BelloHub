//
//  VisitDurationTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("VisitDuration")
struct VisitDurationTests {
    @Test("Service, add-ons and each guest in sequence add up (D19)", arguments: [
        (60, [Int](), 0, 60),
        (60, [15], 0, 75),
        (60, [15, 10], 0, 85),
        (60, [Int](), 1, 120),
        (60, [15], 2, 195),
        (90, [20, 20], 1, 220)
    ])
    func total(service: Int, addOns: [Int], guests: Int, expected: Int) {
        #expect(VisitDuration.totalMinutes(serviceMinutes: service, addOnMinutes: addOns, guests: guests) == expected)
    }

    @Test("A guest adds the service's time and not the add-ons', as the server counts it")
    func guestsRepeatOnlyTheService() {
        // The server: service + add-ons + guests * service.
        #expect(VisitDuration.totalMinutes(serviceMinutes: 45, addOnMinutes: [30], guests: 2) == 45 + 30 + 90)
    }

    @Test("Negative numbers never shorten a visit")
    func negatives() {
        #expect(VisitDuration.totalMinutes(serviceMinutes: -10, addOnMinutes: [-5], guests: -1) == 0)
    }

    @Test("Over twelve hours is too long")
    func maximum() {
        #expect(!VisitDuration.exceedsMaximum(720))
        #expect(VisitDuration.exceedsMaximum(721))
    }
}
