//
//  AvailabilitySlotSettingsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The slot interval and "Keep my day compact" (D56), and what they default to for availability saved before them.
@Suite("AvailabilitySettings slots")
struct AvailabilitySlotSettingsTests {
    @Test("Saved before D56: a 15-minute grid and a compact day")
    func defaults() throws {
        let settings = makeAvailability()
        #expect(settings.effectiveSlotStep == 15 && settings.keepsDayCompact)
        let decoded = try JSONDecoder().decode(AvailabilitySettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.slotStepMinutes == nil && decoded.compactDay == nil)
    }

    @Test("Her choices are kept: every 30 minutes, the day not compacted")
    func chosen() {
        var settings = makeAvailability()
        settings.slotStepMinutes = 30
        settings.compactDay = false
        #expect(settings.effectiveSlotStep == 30 && !settings.keepsDayCompact)
    }

    @Test("The menu lists the intervals with \"match the service\" last, and keeps an unusual value")
    func choices() {
        #expect(AvailabilitySettings.slotStepChoices(including: 15) == [10, 15, 20, 30, 60, 0])
        #expect(AvailabilitySettings.slotStepChoices(including: 0) == [10, 15, 20, 30, 60, 0])
        #expect(AvailabilitySettings.slotStepChoices(including: 45) == [10, 15, 20, 30, 45, 60, 0])
    }

    @Test("Her shortest offer is the shortest active service with its extra time")
    func shortestOffer() {
        let quick = Service(name: "Brows", durationMinutes: 20, timing: VisitTiming(prepMinutes: 5, cleanupMinutes: 10))
        let long = Service(name: "Colour", durationMinutes: 90)
        let off = Service(name: "Old", durationMinutes: 10, isActive: false)
        #expect(AvailabilitySettings.shortestOfferMinutes(of: [quick, long, off]) == 35)
        #expect(AvailabilitySettings.shortestOfferMinutes(of: []) == 0)
    }
}
