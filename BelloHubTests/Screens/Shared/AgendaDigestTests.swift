//
//  AgendaDigestTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AgendaDigest")
struct AgendaDigestTests {
    private let days = CalendarDays(timeZone: TestClock.saoPaulo, firstWeekday: 2)

    private func digest(
        _ visits: [Appointment], clients: [Client] = [], services: [Service] = [], now: Date = TestClock.now,
        days: CalendarDays? = nil, prefs: NotificationPrefs = .standard
    ) -> AgendaDigest {
        AgendaDigest.make(
            AgendaDigest.Input(
                appointments: visits, clients: clients, services: services, blocks: [],
                availability: makeAvailability(), prefs: prefs, now: now
            ),
            days: days ?? self.days
        )
    }

    private func today(_ time: String, status: AppointmentStatus = .booked, client: UUID = UUID()) -> Appointment {
        makeVisit(clientID: client, start: TestClock.date("2026-10-01 \(time)"), status: status)
    }

    // MARK: - Next visit and the rest of today

    @Test("The next visit is the first one that has not ended; the others of today follow in time order")
    func nextAndRest() throws {
        let done = today("09:00", status: .completed)
        let next = today("12:30", status: .confirmed)
        let later = today("15:00")
        let cancelled = today("16:30", status: .cancelled)
        let result = digest([later, cancelled, next, done])

        #expect(result.nextVisit?.id == next.id)
        #expect(result.nextIsToday && !result.nextIsInProgress)
        #expect(result.minutesUntilNext == 30)
        #expect(result.restOfToday.map(\.id) == [done.id, later.id])
        #expect(result.leftToday == 2)
        #expect(!result.isDayClear)
    }

    @Test("A visit that has started and not ended is the next one, in progress")
    func inProgress() {
        let running = today("11:30")
        let result = digest([running, today("14:00")])

        #expect(result.nextVisit?.id == running.id)
        #expect(result.nextIsInProgress)
        #expect(result.minutesUntilNext == 0)
    }

    @Test("A visit on another day is next when today has none, and says it is not today")
    func nextTomorrow() {
        let tomorrow = makeVisit(start: TestClock.date("2026-10-02 10:00"))
        let result = digest([tomorrow])

        #expect(result.nextVisit?.id == tomorrow.id)
        #expect(!result.nextIsToday)
        #expect(result.restOfToday.isEmpty)
    }

    @Test("Nothing within the coming week, or only cancelled visits, is a clear day")
    func clearDay() {
        let far = makeVisit(start: TestClock.date("2026-10-20 10:00"))
        let cancelled = today("15:00", status: .cancelled)

        #expect(digest([far, cancelled]).isDayClear)
        #expect(digest([]).isDayClear)
    }

    @Test("Today's visits come from the business time zone, not the phone's")
    func businessZone() {
        // 2026-10-01 23:30 in São Paulo is 02:30 UTC on the 2nd: still today for her.
        let lateToday = makeVisit(start: TestClock.date("2026-10-01 23:30"))
        let early = makeVisit(start: TestClock.date("2026-10-02 00:30"))
        let result = digest([lateToday, early])

        #expect(result.nextVisit?.id == lateToday.id)
        #expect(result.restOfToday.isEmpty)
        #expect(result.leftToday == 1)
    }

    @Test("The day is 23, 24 or 25 hours long on a clock-change day", arguments: ZoneDay.all)
    func clockChangeDay(zone: ZoneDay) {
        let local = CalendarDays(timeZone: TimeZone(identifier: zone.zone) ?? .gmt, firstWeekday: 1)
        let now = TestClock.date("\(zone.date) 06:30", zone: zone.zone)
        let morning = makeVisit(start: TestClock.date("\(zone.date) 10:00", zone: zone.zone))
        let night = makeVisit(start: TestClock.date("\(zone.date) 23:30", zone: zone.zone))
        let nextDay = makeVisit(start: local.adding(days: 1, to: zone.midnight).addingTimeInterval(1_800))
        let result = digest([morning, night, nextDay], now: now, days: local)

        #expect(result.nextVisit?.id == morning.id)
        #expect(result.nextIsToday)
        #expect(result.restOfToday.map(\.id) == [night.id])
        #expect(result.leftToday == 2)
    }

    // MARK: - Reminders, follow-ups and the rest

    @Test("The reminders ready, the follow-ups, the win-back list and the birthdays come from their own rules")
    func gathersTheRules() {
        let glow = makeService(name: "Glow Facial", followUpWeeks: 4)
        let ana = Client(name: "Ana Costa", phoneE164: "+5511955550001", createdAt: TestClock.days(-200))
        let bea = Client(name: "Beatriz Lima", createdAt: TestClock.days(-200))
        let larissa = Client(
            name: "Larissa Souza", birthday: Birthday(month: 10, day: 3), createdAt: TestClock.days(-200)
        )
        var oldVisit = makeVisit(clientID: bea.id, start: TestClock.days(-90), status: .completed)
        oldVisit.serviceID = glow.id
        let tomorrow = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 18:00"))
        let result = digest([oldVisit, tomorrow], clients: [ana, bea, larissa], services: [glow])

        #expect(result.remindersReady.map(\.id) == [tomorrow.id])
        #expect(result.remindersToSend == 1)
        #expect(result.followUps.map(\.clientID) == [bea.id])
        #expect(result.winBack.map(\.clientID) == [bea.id])
        #expect(result.birthdays.map(\.clientID) == [larissa.id])
        #expect(result.client(bea.id)?.name == "Beatriz Lima")
        #expect(result.client(UUID()) == nil)
    }

    @Test("The week summary counts the open slots from her hours")
    func weekSummary() {
        let result = digest([today("15:00")])

        #expect(result.week.openSlotCount > 0)
        #expect(result.week.leftToday == 1)
    }
}
