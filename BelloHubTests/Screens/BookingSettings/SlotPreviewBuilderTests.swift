//
//  SlotPreviewBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// "What clients see" (routine item 10). `TestClock.now` is Thursday 2026-10-01 12:00 in São Paulo; Maria's week
/// (`makeAvailability`) is Tuesday to Saturday, 09:00 to 19:00, lunch 12:30 to 13:30, 15 minutes between clients.
@Suite("SlotPreviewBuilder")
struct SlotPreviewBuilderTests {
    private func at(_ text: String) -> Date { TestClock.date(text) }

    private func makePreview(_ settings: AvailabilitySettings) -> SlotPreview? {
        SlotPreviewBuilder.preview(settings: settings, services: [], now: TestClock.now)
    }

    private func makeTimedService(
        _ name: String, minutes: Int, position: Int = 0, timing: VisitTiming? = nil
    ) -> Service {
        Service(name: name, durationMinutes: minutes, position: position, timing: timing)
    }

    @Test("The sample day is her next working day after today, at its start")
    func nextWorkingDay() throws {
        let preview = try #require(makePreview(makeAvailability()))
        #expect(preview.day == at("2026-10-02 00:00"), "Friday, the day after Thursday")

        let mondays = makeAvailability(weekdays: [2])
        let monday = try #require(makePreview(mondays))
        #expect(monday.day == at("2026-10-05 00:00"))
    }

    @Test("No working hours: no preview")
    func noHours() {
        #expect(makePreview(makeAvailability(weekdays: [])) == nil)
    }

    @Test("With no services a plain 60-minute visit stands in, with no sample booking, and lunch is never offered")
    func fallbackVisit() throws {
        let preview = try #require(makePreview(makeAvailability()))

        #expect(preview.serviceName == nil && preview.durationMinutes == 60 && preview.sampleVisit == nil)
        #expect(preview.shownFirst.first == at("2026-10-02 09:00"))
        #expect(preview.shownFirst.contains(at("2026-10-02 13:30")), "right after lunch")
        let everything = preview.shownFirst + preview.alsoBookable
        #expect(Set(everything).count == everything.count, "a time is either shown first or also bookable")
        #expect(!everything.contains { $0 > at("2026-10-02 11:30") && $0 < at("2026-10-02 13:30") },
                "nothing that would run into lunch")
        #expect(everything.allSatisfy { $0 <= at("2026-10-02 18:00") }, "the last visit ends at closing")
    }

    @Test("Minimum notice, the booking window and days off do not empty the sample")
    func notApplied() throws {
        let friday = DayOff(
            id: UUID(), startDate: at("2026-10-02 00:00"), endDate: at("2026-10-02 00:00"), kind: .dayOff
        )
        let strict = makeAvailability(daysOff: [friday], minNoticeHours: 48, maxDaysAhead: 0)

        let preview = try #require(makePreview(strict))

        #expect(preview.day == at("2026-10-02 00:00") && !preview.isEmpty)
    }

    @Test("Her longest service is previewed, her shortest is the sample booking an hour after she opens")
    func servicesUsed() throws {
        let haircut = makeTimedService("Haircut", minutes: 30)
        let color = makeTimedService("Color", minutes: 120, position: 1)
        let preview = try #require(SlotPreviewBuilder.preview(
            settings: makeAvailability(), services: [haircut, color], now: TestClock.now
        ))

        #expect(preview.serviceName == "Color" && preview.durationMinutes == 120)
        #expect(preview.sampleVisit == SlotPreview.SampleVisit(
            serviceName: "Haircut", start: at("2026-10-02 10:00"), minutes: 30
        ))
        let everything = Set(preview.shownFirst + preview.alsoBookable)
        #expect(!everything.contains(at("2026-10-02 09:00")), "a solid colour from 09:00 would run over the haircut")
        #expect(!everything.contains(at("2026-10-02 10:45")), "after the haircut a colour would run into lunch")
        #expect(everything.contains(at("2026-10-02 13:30")), "right after lunch")
    }

    @Test("A chosen service is previewed, and an inactive one is never used")
    func chosenService() throws {
        let haircut = makeTimedService("Haircut", minutes: 30)
        let color = makeTimedService("Color", minutes: 120, position: 1)
        var hidden = makeTimedService("Old", minutes: 200)
        hidden.isActive = false

        let preview = try #require(SlotPreviewBuilder.preview(
            settings: makeAvailability(), services: [haircut, color, hidden], previewing: haircut.id,
            now: TestClock.now
        ))
        #expect(preview.serviceName == "Haircut")

        let fallback = try #require(SlotPreviewBuilder.preview(
            settings: makeAvailability(), services: [haircut, color, hidden], previewing: hidden.id,
            now: TestClock.now
        ))
        #expect(fallback.serviceName == "Color", "an inactive service falls back to the longest active one")
    }

    @Test("Processing time lets a colour wrap the booked haircut (D56 logic kept)")
    func processingWraps() throws {
        let haircut = makeTimedService("Haircut", minutes: 30)
        // Colour: 120 minutes, free from minute 30 to minute 60 while it develops.
        let color = makeTimedService(
            "Color", minutes: 120, position: 1, timing: VisitTiming(processingStartMinutes: 30, processingMinutes: 30)
        )
        let preview = try #require(SlotPreviewBuilder.preview(
            settings: makeAvailability(), services: [haircut, color], now: TestClock.now
        ))

        let everything = Set(preview.shownFirst + preview.alsoBookable)
        #expect(everything.contains(at("2026-10-02 09:30")), "the haircut at 10:00 sits inside the colour's processing")
    }

    @Test("The rules above change the preview: the start-time grid and the compact day")
    func followsTheSettings() throws {
        var every15 = makeAvailability()
        every15.slotStepMinutes = 15
        var every60 = makeAvailability()
        every60.slotStepMinutes = 60
        let fine = try #require(makePreview(every15))
        let coarse = try #require(makePreview(every60))
        #expect((coarse.shownFirst + coarse.alsoBookable).count < (fine.shownFirst + fine.alsoBookable).count)

        var loose = makeAvailability()
        loose.compactDay = false
        let all = try #require(makePreview(loose))
        #expect(all.alsoBookable.isEmpty, "with the compact day off every time is shown first")
    }

    @Test("Every time it shows is one the calculator offers for the same day")
    func agreesWithTheCalculator() throws {
        let settings = makeAvailability()
        let preview = try #require(makePreview(settings))
        var sample = settings
        sample.minNoticeHours = 0
        let plan = FreeSlotsCalculator.plan(for: FreeSlotsRequest(
            day: preview.day, durationMinutes: 60, now: preview.day, settings: sample,
            stepMinutes: settings.effectiveSlotStep, compact: settings.keepsDayCompact, shortestOfferMinutes: 60
        ))

        #expect(preview.shownFirst == plan.recommended && preview.alsoBookable == plan.more)
    }
}
