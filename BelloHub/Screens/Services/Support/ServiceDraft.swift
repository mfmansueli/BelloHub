//
//  ServiceDraft.swift
//  BelloHub
//

import Foundation

/// The service form while she edits it: text fields hold text (the price is parsed the way her language writes
/// numbers), switches hold booleans, and nothing is a `Service` until `ServiceRules` accepts it.
struct ServiceDraft: Equatable, Sendable {
    var name = ""
    var category = ""
    var priceText = ""
    var minutes = 60
    var priceDisplay = PriceDisplay.show
    var followUpWeeks: Int? = 4
    var remindsPhotos = true
    var sharesAftercare = true
    var aftercareText = ""
    var requiresPatchTest = false
    var patchTestHoursBefore = 48
    var contraindications: [String] = []
    var isActive = true
    /// D56: blocked before and after the visit, never shown to the client.
    var prepMinutes = 0
    var cleanupMinutes = 0
    /// D56: a stretch inside the visit while she is free (colour developing, a mask setting).
    var hasProcessing = false
    var processingMinutes = 20
    var processingStartMinutes = 20

    /// A new service with the defaults the setup uses.
    init() {}

    /// The form for a service that exists, with the price written the way `locale` writes numbers and without a
    /// thousands separator, so reading it back gives the same amount.
    init(_ service: Service, locale: Locale) {
        name = service.name
        category = service.category
        priceText = service.priceAmount.map { $0.formatted(.number.locale(locale).grouping(.never)) } ?? ""
        minutes = service.durationMinutes
        priceDisplay = service.priceDisplay
        followUpWeeks = service.followUpWeeks
        remindsPhotos = service.remindBeforeAfterPhotos
        // An empty template is "on, words to be written later" (the setup stores it that way).
        sharesAftercare = service.aftercareTemplate != nil
        aftercareText = service.aftercareTemplate ?? ""
        requiresPatchTest = service.requiresPatchTest
        patchTestHoursBefore = service.patchTestHoursBefore
        contraindications = service.contraindications
        isActive = service.isActive
        let timing = service.visitTiming
        prepMinutes = timing.prepMinutes
        cleanupMinutes = timing.cleanupMinutes
        hasProcessing = timing.processingMinutes > 0
        if hasProcessing {
            processingMinutes = timing.processingMinutes
            processingStartMinutes = timing.processingStartMinutes
        }
    }
}
