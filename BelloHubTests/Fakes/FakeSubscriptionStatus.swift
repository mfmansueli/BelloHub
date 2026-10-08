//
//  FakeSubscriptionStatus.swift
//  BelloHubTests
//

@testable import BelloHub

/// A subscription state a test flips by hand: no plan by default, a plan when `hasActivePlan` is set.
@MainActor
final class FakeSubscriptionStatus: SubscriptionStatusProviding {
    var hasActivePlan: Bool

    init(hasActivePlan: Bool = false) {
        self.hasActivePlan = hasActivePlan
    }
}
