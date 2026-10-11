//
//  Service.swift
//  BelloHub
//

import Foundation

/// Something she offers. Contraindications warn and never block (D16); a patch test is a per-service setting.
struct Service: Identifiable, Hashable, Codable, Sendable, Positioned {
    let id: UUID
    var name: String
    var category: String
    var durationMinutes: Int
    /// Optional information, in the business currency. Only shown if `priceDisplay` says so.
    var priceAmount: Decimal?
    var priceDisplay: PriceDisplay
    /// Clients become due for a follow-up this many weeks after the service. Nil means none.
    var followUpWeeks: Int?
    var remindBeforeAfterPhotos: Bool
    var aftercareTemplate: String?
    var isActive: Bool
    var position: Int
    /// Health-form answers that make this service unsuitable (pregnancy, isotretinoin in the last 6 months, ...).
    var contraindications: [String]
    var requiresPatchTest: Bool
    /// How long before the first visit the patch test is asked for.
    var patchTestHoursBefore: Int
    /// Prep, clean-up and processing time (D56). Nil for a service saved before D56 and for one with none.
    var timing: VisitTiming?

    /// The shape of a visit of this service: no extra time when she set none.
    var visitTiming: VisitTiming { timing ?? .noExtraTime }

    init(
        id: UUID = UUID(),
        name: String,
        category: String = "",
        durationMinutes: Int,
        priceAmount: Decimal? = nil,
        priceDisplay: PriceDisplay = .show,
        followUpWeeks: Int? = nil,
        remindBeforeAfterPhotos: Bool = false,
        aftercareTemplate: String? = nil,
        isActive: Bool = true,
        position: Int = 0,
        contraindications: [String] = [],
        requiresPatchTest: Bool = false,
        patchTestHoursBefore: Int = 48,
        timing: VisitTiming? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.durationMinutes = durationMinutes
        self.priceAmount = priceAmount
        self.priceDisplay = priceDisplay
        self.followUpWeeks = followUpWeeks
        self.remindBeforeAfterPhotos = remindBeforeAfterPhotos
        self.aftercareTemplate = aftercareTemplate
        self.isActive = isActive
        self.position = position
        self.contraindications = contraindications
        self.requiresPatchTest = requiresPatchTest
        self.patchTestHoursBefore = patchTestHoursBefore
        self.timing = timing
    }
}
