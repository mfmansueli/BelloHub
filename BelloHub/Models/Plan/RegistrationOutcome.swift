//
//  RegistrationOutcome.swift
//  BelloHub
//

import Foundation

/// What the registration gate did with one client (D42). Only `registered` uses one of the free registrations.
enum RegistrationOutcome: Equatable, Sendable {
    /// A new client was saved and counted.
    case registered
    /// The client already existed (an edit): saved, nothing counted.
    case updated
    /// Another client already has this phone number: nothing was saved and nothing counted. The id is the existing one.
    case duplicate(existingID: UUID)
    /// The free registrations are used and there is no plan: nothing was saved. Show the paywall.
    case needsSubscription
}
