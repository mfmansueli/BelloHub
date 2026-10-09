//
//  RescheduleOutcome.swift
//  BelloHub
//

/// What the server answers to `respondRescheduleRequest` (API.md 6.3).
enum RescheduleOutcome: String, Codable, Equatable, Sendable {
    case accepted
    case declined
    /// Somebody booked the requested time first; the current time stays booked.
    case slotTaken
}
