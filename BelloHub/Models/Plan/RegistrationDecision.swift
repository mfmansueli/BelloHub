//
//  RegistrationDecision.swift
//  BelloHub
//

/// The answer to "may these clients be added?" (D42).
enum RegistrationDecision: Equatable, Sendable {
    case allowed
    /// An import larger than what is left: only this many may be added; the paywall is offered for the rest.
    case allowedPartially(count: Int)
    /// The free registrations are used and there is no plan: show the paywall.
    case needsSubscription
}
