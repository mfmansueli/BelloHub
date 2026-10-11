//
//  BlockPlannerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BlockPlanner")
struct BlockPlannerTests {
    private let settings = makeAvailability()

    private func day(_ text: String) -> Date { TestClock.date("\(text) 00:00") }

    @Test("A whole day closes from midnight to midnight, one block per day, in order")
    func wholeDays() {
        let blocks = BlockPlanner.blocks(
            days: [day("2026-10-03"), day("2026-10-02")], scope: .wholeDay, reason: " Family ", settings: settings
        )
        #expect(blocks.count == 2)
        #expect(blocks[0].startsAt == day("2026-10-02") && blocks[0].endsAt == day("2026-10-03"))
        #expect(blocks[1].startsAt == day("2026-10-03") && blocks[1].endsAt == day("2026-10-04"))
        #expect(blocks.allSatisfy { $0.reason == "Family" })
    }

    @Test("Some hours close that stretch on each chosen day; an empty reason is stored as none")
    func someHours() {
        let blocks = BlockPlanner.blocks(
            days: [day("2026-10-02")], scope: .hours(startMinutes: 14 * 60, endMinutes: 16 * 60 + 30), reason: "  ",
            settings: settings
        )
        #expect(blocks.first?.startsAt == friday("14:00") && blocks.first?.endsAt == friday("16:30"))
        #expect(blocks.first?.reason == nil)
    }

    @Test("The choice is invalid with no day, or with hours that end before they start")
    func issues() {
        #expect(BlockPlanner.issue(days: [], scope: .wholeDay) == .noDays)
        let one = [day("2026-10-02")]
        #expect(BlockPlanner.issue(days: one, scope: .hours(startMinutes: 600, endMinutes: 600)) == .emptyHours)
        #expect(BlockPlanner.issue(days: one, scope: .hours(startMinutes: 700, endMinutes: 600)) == .emptyHours)
        #expect(BlockPlanner.issue(days: one, scope: .hours(startMinutes: 600, endMinutes: 601)) == nil)
        #expect(BlockPlanner.issue(days: one, scope: .wholeDay) == nil)
    }

    @Test("Visits still holding time inside the closed time are found; cancelled and finished ones are not")
    func affected() {
        let inside = makeVisit(start: friday("10:00"))
        let confirmed = makeVisit(start: friday("15:00"), status: .confirmed)
        let outside = makeVisit(start: TestClock.date("2026-10-03 10:00"))
        let cancelled = makeVisit(start: friday("11:00"), status: .cancelled)
        let done = makeVisit(start: friday("09:00"), status: .completed)
        let blocks = BlockPlanner.blocks(days: [day("2026-10-02")], scope: .wholeDay, reason: nil, settings: settings)
        let found = BlockPlanner.affected(by: blocks, appointments: [confirmed, outside, cancelled, done, inside])
        #expect(found.map(\.id) == [inside.id, confirmed.id])
    }

    @Test("A visit that only touches the closed time is not affected")
    func touching() {
        let before = makeVisit(start: friday("13:00"), minutes: 60)
        let blocks = BlockPlanner.blocks(
            days: [day("2026-10-02")], scope: .hours(startMinutes: 14 * 60, endMinutes: 16 * 60), reason: nil,
            settings: settings
        )
        #expect(BlockPlanner.affected(by: blocks, appointments: [before]).isEmpty)
    }

    @Test("The booked count of each day follows the chosen hours")
    func counts() {
        let morning = makeVisit(start: friday("10:00"))
        let afternoon = makeVisit(start: friday("15:00"))
        let saturday = makeVisit(start: TestClock.date("2026-10-03 10:00"))
        let days = [day("2026-10-02"), day("2026-10-03")]
        let whole = BlockPlanner.bookedCounts(
            days: days, scope: .wholeDay, appointments: [morning, afternoon, saturday], settings: settings
        )
        #expect(whole[days[0]] == 2 && whole[days[1]] == 1)
        let afternoons = BlockPlanner.bookedCounts(
            days: days, scope: .hours(startMinutes: 14 * 60, endMinutes: 18 * 60),
            appointments: [morning, afternoon, saturday], settings: settings
        )
        #expect(afternoons[days[0]] == 1 && afternoons[days[1]] == 0)
    }

    @Test("Ids come from the caller so a test is deterministic")
    func ids() {
        let fixed = UUID()
        let blocks = BlockPlanner.blocks(
            days: [day("2026-10-02")], scope: .wholeDay, reason: nil, settings: settings, makeID: { fixed }
        )
        #expect(blocks.first?.id == fixed)
    }

    @Test("A whole day is the real day (23 or 25 hours on a change day); hours are wall-clock",
          arguments: ZoneDay.all)
    func changeDay(day: ZoneDay) {
        let whole = BlockPlanner.interval(on: day.midnight, scope: .wholeDay, settings: day.overnightSettings)
        #expect(whole?.duration == TimeInterval(day.dayHours * 3_600))
        let early = BlockPlanner.interval(
            on: day.midnight, scope: .hours(startMinutes: 0, endMinutes: 360), settings: day.overnightSettings
        )
        #expect(early?.duration == TimeInterval(day.windowHours * 3_600))
    }
}
