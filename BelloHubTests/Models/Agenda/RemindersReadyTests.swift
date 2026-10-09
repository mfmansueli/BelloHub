//
//  RemindersReadyTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RemindersReady")
struct RemindersReadyTests {
    private let calendar = TestClock.calendar()

    private func client(
        id: UUID = UUID(), phone: String? = "+5511955550001", reminders: Bool = true, archived: Bool = false
    ) -> Client {
        Client(
            id: id, name: "Ana Costa", phoneE164: phone, isArchived: archived, remindersEnabled: reminders,
            createdAt: TestClock.days(-100)
        )
    }

    private func items(
        _ visits: [Appointment], _ clients: [Client], now: Date = TestClock.now,
        prefs: NotificationPrefs = .standard
    ) -> [RemindersReady.Item] {
        RemindersReady.items(appointments: visits, clients: clients, prefs: prefs, now: now, calendar: calendar)
    }

    @Test("A visit tomorrow is ready from 18:00 today, not before",
          arguments: [("17:59", false), ("18:00", true), ("23:00", true)])
    func eveningBefore(time: String, ready: Bool) {
        let ana = client()
        let visit = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-02 10:00"))
        let now = TestClock.date("2026-10-01 \(time)")

        #expect(items([visit], [ana], now: now).count == (ready ? 1 : 0))
    }

    @Test("Her own reminder time moves the moment")
    func ownTime() {
        let ana = client()
        let visit = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-02 10:00"))
        var prefs = NotificationPrefs.standard
        prefs.reminderTimeMinutes = 20 * 60

        #expect(items([visit], [ana], now: TestClock.date("2026-10-01 19:00"), prefs: prefs).isEmpty)
        #expect(items([visit], [ana], now: TestClock.date("2026-10-01 20:00"), prefs: prefs).count == 1)
    }

    @Test("A visit later today is ready at once")
    func sameDay() {
        let ana = client()
        let visit = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 16:00"))

        #expect(items([visit], [ana]).count == 1)
    }

    @Test("Visits that are over, not holding time or confirmed by the client are left out")
    func skipped() {
        let ana = client()
        let past = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 09:00"))
        let cancelled = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 16:00"), status: .cancelled)
        var confirmed = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 17:00"))
        confirmed.clientConfirmedAt = TestClock.now

        #expect(items([past, cancelled, confirmed], [ana]).isEmpty)
    }

    @Test("Clients without a phone, who stopped reminders, or are archived are skipped")
    func unreachable() {
        let noPhone = client(phone: nil)
        let empty = client(phone: "")
        let stopped = client(reminders: false)
        let archived = client(archived: true)
        let start = TestClock.date("2026-10-01 16:00")
        let visits = [noPhone, empty, stopped, archived].map { makeVisit(clientID: $0.id, start: start) }

        #expect(items(visits, [noPhone, empty, stopped, archived]).isEmpty)
    }

    @Test("A visit without its client is skipped")
    func missingClient() {
        #expect(items([makeVisit(start: TestClock.date("2026-10-01 16:00"))], []).isEmpty)
    }

    @Test("The switch for client reminders empties the list")
    func switchedOff() {
        let ana = client()
        let visit = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 16:00"))
        var prefs = NotificationPrefs.standard
        prefs.clientRemindersEnabled = false

        #expect(items([visit], [ana], prefs: prefs).isEmpty)
    }

    @Test("Reminders she did not open come first, soonest first; opened ones follow")
    func ordering() {
        let ana = client()
        var opened = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 14:00"))
        opened.reminderSentAt = TestClock.now
        let later = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 17:00"))
        let sooner = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 15:00"))
        let list = items([later, opened, sooner], [ana])

        #expect(list.map(\.id) == [sooner.id, later.id, opened.id])
        #expect(list.map { $0.openedAt != nil } == [false, false, true])
    }

    @Test("The evening-before moment is 18:00 local the day before, across clock changes", arguments: ZoneDay.all)
    func moment(day: ZoneDay) throws {
        let calendar = day.calendar
        let visit = TestClock.date("\(day.date) 10:00", zone: day.zone)
        let moment = try #require(RemindersReady.moment(forVisitAt: visit, prefs: .standard, calendar: calendar))
        let eve = try #require(calendar.date(byAdding: .day, value: -1, to: day.midnight))

        #expect(calendar.dateComponents([.hour, .minute], from: moment) == DateComponents(hour: 18, minute: 0))
        #expect(calendar.isDate(moment, inSameDayAs: eve))
    }

    @Test("A reminder time that does not exist that day moves to the next valid one")
    func missingWallClockTime() throws {
        // Lisbon skips 01:00 to 02:00 on Sunday 2026-03-29, so 01:30 does not exist that night.
        let lisbon = TestClock.calendar("Europe/Lisbon")
        var prefs = NotificationPrefs.standard
        prefs.reminderTimeMinutes = 90
        let visit = TestClock.date("2026-03-30 10:00", zone: "Europe/Lisbon")
        let moment = try #require(RemindersReady.moment(forVisitAt: visit, prefs: prefs, calendar: lisbon))

        #expect(moment == TestClock.date("2026-03-29 02:00", zone: "Europe/Lisbon"))
    }
}
