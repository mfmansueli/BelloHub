//
//  OpenTimesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("OpenTimes")
struct OpenTimesTests {
    private let days = CalendarDays(timeZone: TestClock.saoPaulo)

    private func request(
        minutes: Int = 60, settings: AvailabilitySettings = makeAvailability(), appointments: [Appointment] = [],
        blocks: [TimeBlock] = [], ignoring: UUID? = nil, step: Int = 60
    ) -> OpenTimes.Request {
        OpenTimes.Request(
            durationMinutes: minutes, settings: settings, appointments: appointments, blocks: blocks,
            now: TestClock.now, ignoring: ignoring, stepMinutes: step
        )
    }

    private var friday: Date { TestClock.date("2026-10-02 00:00") }

    @Test("A free day offers every start the duration fits in, around the lunch break")
    func freeDay() {
        // 09:00 to 19:00, lunch 12:30 to 13:30, one-hour visits on the hour, plus the starts anchored against lunch
        // (D56): one that ends as lunch begins and one that starts as it ends.
        let slots = OpenTimes.slots(on: friday, request(settings: makeAvailability(bufferMinutes: 0)))
        let labels = slots.map {
            TestClock.calendar().component(.hour, from: $0) * 60 + TestClock.calendar().component(.minute, from: $0)
        }
        #expect(labels == [540, 600, 660, 690, 810, 840, 900, 960, 1_020, 1_080])
    }

    @Test("A booked visit and its buffer take the time away; her own visit does not when she moves it")
    func bookedAndMoved() {
        let visit = makeVisit(start: TestClock.date("2026-10-02 10:00"))
        let withBuffer = OpenTimes.slots(on: friday, request(appointments: [visit], step: 15))
        #expect(!withBuffer.contains(TestClock.date("2026-10-02 10:00")))
        // Nothing earlier than 08:45 + 15 min buffer, nothing at 11:00 + 15 min buffer.
        #expect(withBuffer.contains(TestClock.date("2026-10-02 11:15")))
        #expect(!withBuffer.contains(TestClock.date("2026-10-02 11:00")))
        let moving = OpenTimes.slots(on: friday, request(appointments: [visit], ignoring: visit.id, step: 15))
        #expect(moving.contains(TestClock.date("2026-10-02 10:00")))
    }

    @Test("A cancelled visit and a no-show leave the time free")
    func freed() {
        let cancelled = makeVisit(start: TestClock.date("2026-10-02 10:00"), status: .cancelled)
        let missed = makeVisit(start: TestClock.date("2026-10-02 15:00"), status: .noShow)
        let slots = OpenTimes.slots(on: friday, request(appointments: [cancelled, missed]))
        #expect(slots.contains(TestClock.date("2026-10-02 10:00")))
        #expect(slots.contains(TestClock.date("2026-10-02 15:00")))
    }

    @Test("A block takes its time away")
    func blocked() {
        let block = makeBlock(start: TestClock.date("2026-10-02 14:00"), minutes: 120)
        let slots = OpenTimes.slots(on: friday, request(blocks: [block]))
        #expect(!slots.contains(TestClock.date("2026-10-02 14:00")))
        #expect(!slots.contains(TestClock.date("2026-10-02 15:00")))
        #expect(slots.contains(TestClock.date("2026-10-02 16:00")))
    }

    @Test("She can offer herself a time sooner than clients may book, but never one in the past")
    func noticeDoesNotApply() {
        var settings = makeAvailability()
        settings.minNoticeHours = 24
        // Thursday is not a working day in the sample week; use Friday morning with `now` an hour before.
        var near = request(settings: settings)
        near.now = TestClock.date("2026-10-02 08:00")
        let slots = OpenTimes.slots(on: friday, near)
        #expect(slots.first == TestClock.date("2026-10-02 09:00"))
        var late = near
        late.now = TestClock.date("2026-10-02 10:30")
        #expect(OpenTimes.slots(on: friday, late).first == TestClock.date("2026-10-02 11:00"))
    }

    @Test("Closed days offer nothing, and the next days with room are listed in order")
    func nextDays() {
        let found = OpenTimes.nextDays(from: TestClock.date("2026-10-03 00:00"), count: 3, days: days, request())
        // Sat Oct 3, then Sunday and Monday are closed, so Tue Oct 6 and Wed Oct 7.
        let weekdays = found.map { TestClock.calendar().component(.weekday, from: $0.day) }
        #expect(weekdays == [7, 3, 4])
        #expect(found.allSatisfy { !$0.slots.isEmpty })
    }

    @Test("The number of visits that fit is counted one after another with the buffer between them")
    func fitCount() {
        let count = OpenTimes.fitCount(on: friday, request(minutes: 60, step: 15))
        // Morning: 09:00, 10:15, 11:30 ends 12:30. Afternoon: 13:30, 14:45, 16:00, 17:15, (18:30 ends 19:30: no).
        #expect(count == 7)
    }

    @Test("One-hour starts on a daylight-saving change day match the real hours of the window",
          arguments: ZoneDay.all)
    func changeDay(day: ZoneDay) {
        var request = OpenTimes.Request(
            durationMinutes: 60, settings: day.overnightSettings, appointments: [], blocks: [],
            now: day.midnight.addingTimeInterval(-86_400 * 2), stepMinutes: 60
        )
        let slots = OpenTimes.slots(on: day.midnight, request)
        #expect(slots.count == day.windowHours)
        #expect(slots.first == day.midnight)
        #expect(slots.last == day.midnight.addingTimeInterval(TimeInterval((day.windowHours - 1) * 3_600)))
        // A visit in the middle takes exactly its hour away on that day too.
        let visit = makeVisit(start: day.midnight.addingTimeInterval(2 * 3_600))
        request.appointments = [visit]
        #expect(OpenTimes.slots(on: day.midnight, request).count == day.windowHours - 1)
    }
}
