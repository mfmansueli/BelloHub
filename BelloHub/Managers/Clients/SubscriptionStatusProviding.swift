//
//  SubscriptionStatusProviding.swift
//  BelloHub
//

/// Whether she has a paid plan. The StoreKit implementation arrives in S10 (docs/03-BUILD-PLAN.md); until then the app
/// uses `UnsubscribedStatus`. The server re-verifies purchases before it unlocks anything (CLAUDE.md section 2).
@MainActor
protocol SubscriptionStatusProviding: AnyObject {
    var hasActivePlan: Bool { get }
}
