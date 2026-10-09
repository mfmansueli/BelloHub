//
//  BookingRequestOutcome.swift
//  BelloHub
//

/// What the server answers to `respondBookingRequest` (API.md 6.3).
enum BookingRequestOutcome: String, Codable, Equatable, Sendable {
    case confirmed
    case declined
    /// The free registrations are used and there is no plan (D42): the booking stays pending; show the paywall and
    /// approve again afterwards.
    case needsSubscription
}
