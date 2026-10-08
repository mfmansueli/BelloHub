//
//  UnsubscribedStatus.swift
//  BelloHub
//

/// No plan: what every build uses until the subscription service exists (S10).
@MainActor
final class UnsubscribedStatus: SubscriptionStatusProviding {
    var hasActivePlan: Bool { false }
}
