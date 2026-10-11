//
//  PlanPresentationTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PlanPresentation")
struct PlanPresentationTests {
    private func offer(_ period: PlanPeriod, _ price: String) -> PlanOffer {
        PlanOffer(period: period, displayPrice: price, price: Decimal(string: price) ?? 0)
    }

    @Test("The yearly saving comes from the store's prices (D42: about 17 %) and highlights the yearly card")
    func savings() {
        let europe = PlanPresentation(offers: [offer(.monthly, "14.99"), offer(.yearly, "149.99")], state: .none)
        #expect(europe.savingsPercent == 17)
        #expect(europe.highlighted == .yearly)
        #expect(europe.defaultChoice == .yearly)

        let brazil = PlanPresentation(offers: [offer(.monthly, "39.90"), offer(.yearly, "399.90")], state: .none)
        #expect(brazil.savingsPercent == 16, "399.90 against 478.80 is 16.5 %, rounded plainly")
    }

    @Test("Without both prices, or when the yearly plan saves nothing, nothing is highlighted and monthly is default")
    func noSavings() {
        #expect(PlanPresentation(offers: [offer(.monthly, "14.99")], state: .none).highlighted == nil)
        #expect(PlanPresentation(offers: [], state: .none).defaultChoice == .monthly)
        let dearer = PlanPresentation(offers: [offer(.monthly, "10"), offer(.yearly, "130")], state: .none)
        #expect(dearer.savingsPercent == nil)
        #expect(dearer.defaultChoice == .monthly)
    }

    @Test("Active and grace states count as a plan; the feature list is the same five for both periods")
    func activity() {
        let active = SubscriptionState.active(period: .monthly, expiresAt: nil, willRenew: true)
        #expect(PlanPresentation(offers: [], state: active).isActive)
        #expect(PlanPresentation(offers: [], state: .inGracePeriod(period: .yearly, expiresAt: nil)).isActive)
        #expect(!PlanPresentation(offers: [], state: .unknown).isActive)
        #expect(PlanPresentation.features.count == 5)
        #expect(Set(PlanPresentation.features).count == 5)
    }
}
