//
//  PublishInputs.swift
//  BelloHub
//

import Foundation

/// Everything the page and the availability are made from, read from the vault in one go. `PublishPayloads` turns it
/// into
/// the two requests; keeping it a plain value makes that step pure and the publisher testable without a vault.
struct PublishInputs: Equatable, Sendable {
    var profile: ProfessionalProfile
    var services: [Service]
    var addOns: [AddOn]
    var credentials: [Credential]
    var setup: BookingSetup
    var availability: AvailabilitySettings
    /// Her agenda from a little before now to the end of the booking window; the builder keeps only what the server
    /// needs.
    var appointments: [Appointment]
    var blocks: [TimeBlock]
    var inboxKey: InboxPublicKey
    /// Her health form and its wording in the booking languages; nil publishes the page without a form.
    var healthForm: HealthFormPublication?
}
