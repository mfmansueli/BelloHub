//
//  FreeSlotsSmartSlotsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// D56 worked out by hand (the timelines are in docs/agent-notes/smart-slots.md): a Thursday morning 09:00 to 13:00,
/// buffer 10, her shortest offer 30 minutes. The same expectations are in the server's `smartSlots.test.ts`; the
/// generated shared fixture checks that the two implementations agree on many more cases.
@Suite("FreeSlotsCalculator smart slots")
struct FreeSlotsSmartSlotsTests {
    private let colour = VisitTiming(processingStartMinutes: 30, processingMinutes: 45)

    private func plan(
        minutes: Int, step: Int = 15, visits: [TimedInterval] = [], timing: VisitTiming = .noExtraTime,
        compact: Bool = true
    ) -> (all: [String], recommended: [String]) {
        let settings = makeAvailability(weekdays: [5], startMinutes: 540, endMinutes: 780, breaks: [],
                                        bufferMinutes: 10, minNoticeHours: 0)
        let result = FreeSlotsCalculator.plan(for: FreeSlotsRequest(
            day: TestClock.date("2026-10-08 12:00"), durationMinutes: minutes, now: TestClock.now,
            settings: settings, appointments: visits, stepMinutes: step, timing: timing, compact: compact,
            shortestOfferMinutes: 30
        ))
        return (clock(result.all), clock(result.recommended))
    }

    private func visit(_ from: String, _ to: String, timing: VisitTiming = .noExtraTime) -> TimedInterval {
        let stretch = DateInterval(start: TestClock.date("2026-10-08 \(from)"), end: TestClock.date("2026-10-08 \(to)"))
        return TimedInterval(stretch, timing: timing)
    }

    private func clock(_ dates: [Date]) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        formatter.dateFormat = "HH:mm"
        return dates.map(formatter.string(from:))
    }

    @Test("An empty morning recommends the times that leave no gap shorter than 40 minutes")
    func emptyMorning() {
        let result = plan(minutes: 75)
        #expect(result.all.count == 12)
        #expect(result.recommended == ["09:00", "09:45", "10:00", "10:15", "10:30", "10:45", "11:00", "11:45"])
    }

    @Test("A 75-minute service is anchored at 10:15 after a visit ending 10:05, even on a 30-minute grid")
    func anchoredAfterAVisit() {
        let result = plan(minutes: 75, step: 30, visits: [visit("09:35", "10:05")])
        #expect(result.all == ["10:15", "10:30", "11:00", "11:30", "11:45"])
        #expect(result.recommended == ["10:15", "11:00", "11:45"])
    }

    @Test("Where every time in a gap leaves a dead fragment, the least dead time is still offered")
    func honestFallback() {
        let result = plan(minutes: 30, visits: [visit("09:30", "10:00"), visit("11:00", "12:15")])
        #expect(result.all == ["10:10", "10:15", "10:20", "12:25", "12:30"])
        #expect(result.recommended == ["10:10", "10:20", "12:25", "12:30"])
    }

    @Test("With the day not kept compact every free start is recommended")
    func compactOff() {
        let result = plan(minutes: 30, visits: [visit("09:30", "10:00"), visit("11:00", "12:15")], compact: false)
        #expect(result.recommended == result.all)
    }

    @Test("A visit fits inside another visit's processing time, without the buffer, and with its own prep")
    func processingTime() {
        let colourVisit = visit("09:00", "10:30", timing: colour)
        #expect(Array(plan(minutes: 30, visits: [colourVisit]).all.prefix(4)) == ["09:30", "09:45", "10:40", "10:45"])
        let withPrep = plan(minutes: 30, visits: [colourVisit], timing: VisitTiming(prepMinutes: 5))
        #expect(Array(withPrep.all.prefix(3)) == ["09:35", "09:45", "10:45"])
    }

    @Test("Prep and clean-up are blocked around the visit; a booked visit's clean-up keeps the next one away")
    func extraTime() {
        let padded = plan(minutes: 30, timing: VisitTiming(prepMinutes: 10, cleanupMinutes: 15), compact: false)
        #expect(padded.all.first == "09:10")
        #expect(padded.all.last == "12:15")
        let after = plan(minutes: 30, visits: [visit("09:00", "09:30", timing: VisitTiming(cleanupMinutes: 15))])
        #expect(after.all.first == "09:55")
    }

    @Test("\"Match the service\" tiles the stretch with whole visits")
    func matchTheService() {
        #expect(plan(minutes: 75, step: FreeSlotsRequest.matchServiceStep).all == ["09:00", "10:25", "11:45"])
        let padded = plan(minutes: 75, step: FreeSlotsRequest.matchServiceStep,
                          timing: VisitTiming(prepMinutes: 5, cleanupMinutes: 5))
        #expect(padded.all == ["09:05", "10:40", "11:40"])
    }

    @Test("Anchors are rounded inwards to the 5-minute clock")
    func anchorRounding() {
        #expect(plan(minutes: 30, step: 60, visits: [visit("09:00", "09:33")], compact: false).all.first == "09:45")
    }

    @Test("The plan lists the hidden starts as `more`")
    func moreTimes() {
        let settings = makeAvailability(weekdays: [5], startMinutes: 540, endMinutes: 780, breaks: [],
                                        bufferMinutes: 10, minNoticeHours: 0)
        let result = FreeSlotsCalculator.plan(for: FreeSlotsRequest(
            day: TestClock.date("2026-10-08 12:00"), durationMinutes: 75, now: TestClock.now, settings: settings,
            compact: true, shortestOfferMinutes: 30
        ))
        #expect(clock(result.more) == ["09:15", "09:30", "11:15", "11:30"])
    }
}
