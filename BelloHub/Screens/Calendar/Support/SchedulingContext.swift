//
//  SchedulingContext.swift
//  BelloHub
//

import Foundation

/// What the warnings and the free times of a day are read against: the visits and blocks around the day, and, for a
/// client, her visits, her latest health form and her patch tests.
struct SchedulingContext: Sendable {
    var appointments: [Appointment] = []
    var blocks: [TimeBlock] = []
    var clientAppointments: [Appointment] = []
    var form: HealthForm?
    var patchTests: [PatchTest] = []
    var catalog: HealthFormCatalog?

    static let empty = SchedulingContext()

    /// The form to check against: the highest version, and among those the most recently signed.
    static func latest(_ forms: [HealthForm]) -> HealthForm? {
        forms.max { ($0.formVersion, $0.signedAt ?? .distantPast) < ($1.formVersion, $1.signedAt ?? .distantPast) }
    }
}
