//
//  ExportOptions.swift
//  BelloHub
//

import Foundation

/// What 4.10 includes. The defaults are the prototype's: health history, consent and treatments on; photos and internal
/// notes off, because both are private by default.
struct ExportOptions: Equatable, Sendable {
    var audience: ExportAudience = .client
    var includeHealth = true
    var includeConsent = true
    var includeTreatments = true
    var includePhotos = false
    var includeInternalNotes = false
    var period: ExportPeriod = .allTime

    /// The client's copy can never carry internal notes, whatever the switch says. One owner for that rule: the
    /// selector uses this value, and the screen shows the switch off and disabled for the client's copy.
    var allowsInternalNotes: Bool { audience == .healthProfessional }

    var effectiveIncludesInternalNotes: Bool { allowsInternalNotes && includeInternalNotes }
}
