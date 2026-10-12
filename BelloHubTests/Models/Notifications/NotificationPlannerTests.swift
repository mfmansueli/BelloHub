//
//  NotificationPlannerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("NotificationPlanner")
struct NotificationPlannerTests {
    private let calendar = TestClock.calendar()
    private let texts = NotificationTexts.localized(in: Locale(identifier: "en"))
    /// 22:00 to 07:00, across midnight.
    private let night = QuietHoursWindow(fromMinutes: 22 * 60, untilMinutes: 7 * 60)

    private func prefs(
        birthdays: Bool = false, dailySummary: Bool = false, reminders: Bool = false, quiet: QuietHoursWindow? = nil
    ) -> NotificationPrefs {
        var value = NotificationPrefs.standard
        value.birthdays = birthdays
        value.dailySummary = dailySummary
        value.clientRemindersEnabled = reminders
        value.quietHours = quiet
        return value
    }

    private func plan(
        visits: [Appointment] = [], clients: [Client] = [], prefs: NotificationPrefs, now: Date = TestClock.now,
        calendar: Calendar? = nil
    ) -> [PlannedNotification] {
        NotificationPlanner.plan(
            NotificationPlanner.Input(
                now: now, calendar: calendar ?? self.calendar, appointments: visits, clients: clients, prefs: prefs
            ),
            texts: texts
        )
    }

    private func reachable(id: UUID = UUID(), name: String = "Camila Rocha") -> Client {
        Client(id: id, name: name, phoneE164: "+5511955550001", createdAt: TestClock.days(-100))
    }

    // MARK: - Next visit

    @Test("A visit that holds time is announced 15 minutes before it starts")
    func nextVisitLead() throws {
        let visit = makeVisit(start: TestClock.date("2026-10-01 15:00"))
        let planned = plan(visits: [visit], prefs: prefs())
        let notification = try #require(planned.first)

        #expect(planned.count == 1)
        #expect(notification.kind == .nextVisit)
        #expect(notification.fireDate == TestClock.date("2026-10-01 14:45"))
        #expect(notification.id == "bello.nextVisit.\(visit.id.uuidString)")
    }

    @Test("Visits that do not hold time, are over, or start inside the lead are not announced",
          arguments: [AppointmentStatus.cancelled, .completed, .noShow])
    func nextVisitSkips(status: AppointmentStatus) {
        let inactive = makeVisit(start: TestClock.date("2026-10-01 15:00"), status: status)
        let past = makeVisit(start: TestClock.date("2026-10-01 11:00"))
        let tooSoon = makeVisit(start: TestClock.date("2026-10-01 12:10"))

        #expect(plan(visits: [inactive, past, tooSoon], prefs: prefs()).isEmpty)
    }

    @Test("Quiet hours hold the reminder until the window ends, and drop it when that would be too late",
          arguments: [("07:10", "07:00"), ("07:05", "07:00"), ("06:58", nil), ("23:30", nil), ("08:00", "07:45")])
    func nextVisitQuietHours(start: String, delivered: String?) {
        let day = TestClock.date("2026-10-02 \(start)")
        let planned = plan(visits: [makeVisit(start: day)], prefs: prefs(quiet: night))

        if let delivered {
            #expect(planned.map(\.fireDate) == [TestClock.date("2026-10-02 \(delivered)")])
        } else {
            #expect(planned.isEmpty)
        }
    }

    // MARK: - Birthdays

    @Test("Birthdays arrive at 09:00 the day before, one notification per day however many clients")
    func birthdays() {
        let birthday = Birthday(month: 10, day: 3)
        let clients = [
            Client(name: "Julia Mendes", birthday: birthday, createdAt: TestClock.now),
            Client(name: "Larissa Souza", birthday: birthday, createdAt: TestClock.now),
            Client(name: "Helena Duarte", birthday: Birthday(month: 10, day: 20), createdAt: TestClock.now)
        ]
        let planned = plan(clients: clients, prefs: prefs(birthdays: true))

        #expect(planned.map(\.kind) == [.birthday])
        #expect(planned.map(\.fireDate) == [TestClock.date("2026-10-02 09:00")])
    }

    @Test("The birthday switch turns them off, and a birthday today is too late to announce")
    func birthdaysOff() {
        let today = Client(name: "Julia Mendes", birthday: Birthday(month: 10, day: 1), createdAt: TestClock.now)
        let later = Client(name: "Larissa Souza", birthday: Birthday(month: 10, day: 3), createdAt: TestClock.now)

        #expect(plan(clients: [later], prefs: prefs(birthdays: false)).isEmpty)
        #expect(plan(clients: [today], prefs: prefs(birthdays: true)).isEmpty)
    }

    @Test("Archived clients are not announced")
    func birthdaysArchived() {
        let archived = Client(
            name: "Julia Mendes", birthday: Birthday(month: 10, day: 3), isArchived: true, createdAt: TestClock.now
        )

        #expect(plan(clients: [archived], prefs: prefs(birthdays: true)).isEmpty)
    }

    // MARK: - Daily summary

    @Test("The daily summary counts the visits of each day at 08:00 and skips empty days")
    func dailySummary() {
        let visits = [
            makeVisit(start: TestClock.date("2026-10-01 15:00")),
            makeVisit(start: TestClock.date("2026-10-02 09:00")),
            makeVisit(start: TestClock.date("2026-10-02 10:30")),
            makeVisit(start: TestClock.date("2026-10-02 16:00"), status: .cancelled)
        ]
        let summaries = plan(visits: visits, prefs: prefs(dailySummary: true)).filter { $0.kind == .dailySummary }

        // 08:00 today has passed at the fixed `now` (12:00); the next day has two visits.
        #expect(summaries.map(\.fireDate) == [TestClock.date("2026-10-02 08:00")])
        #expect(summaries.first?.body == "You have 2 visits today.")
    }

    @Test("The summary switch turns it off")
    func dailySummaryOff() {
        let visit = makeVisit(start: TestClock.date("2026-10-02 09:00"))

        #expect(plan(visits: [visit], prefs: prefs(dailySummary: false)).filter { $0.kind == .dailySummary }.isEmpty)
    }

    // MARK: - Reminders ready

    @Test("Reminders ready arrives the evening before at her chosen time, with the number of reminders")
    func remindersReady() throws {
        let ana = reachable(name: "Ana Costa")
        let bea = reachable(name: "Beatriz Lima")
        let visits = [
            makeVisit(clientID: ana.id, start: TestClock.date("2026-10-02 10:00")),
            makeVisit(clientID: bea.id, start: TestClock.date("2026-10-02 11:30"))
        ]
        let planned = plan(visits: visits, clients: [ana, bea], prefs: prefs(reminders: true))
        let notification = try #require(planned.first { $0.kind == .remindersReady })

        #expect(notification.fireDate == TestClock.date("2026-10-01 18:00"))
        #expect(notification.body == "2 reminders are ready to send.")
    }

    @Test("Visits that cannot be reminded are not counted")
    func remindersReadySkips() {
        let reachableClient = reachable()
        let noPhone = Client(name: "No Phone", createdAt: TestClock.now)
        let stopped = Client(name: "Stopped", phoneE164: "+5511955550002", remindersEnabled: false, createdAt: .now)
        let start = TestClock.date("2026-10-02 10:00")
        var sent = makeVisit(clientID: reachableClient.id, start: start)
        sent.reminderSentAt = TestClock.now
        var confirmed = makeVisit(clientID: reachableClient.id, start: start.addingTimeInterval(7_200))
        confirmed.clientConfirmedAt = TestClock.now
        let visits = [
            sent, confirmed, makeVisit(clientID: noPhone.id, start: start),
            makeVisit(clientID: stopped.id, start: start)
        ]
        let planned = plan(visits: visits, clients: [reachableClient, noPhone, stopped], prefs: prefs(reminders: true))

        #expect(planned.filter { $0.kind == .remindersReady }.isEmpty)
    }

    @Test("The reminders switch turns the notification off")
    func remindersOff() {
        let client = reachable()
        let visit = makeVisit(clientID: client.id, start: TestClock.date("2026-10-02 10:00"))

        let planned = plan(visits: [visit], clients: [client], prefs: prefs(reminders: false))

        #expect(planned.filter { $0.kind == .remindersReady }.isEmpty)
    }

    // MARK: - The plan as a whole

    @Test("At most 60 notifications are scheduled, the soonest ones")
    func limit() {
        let visits = (0..<100).map { index in
            makeVisit(start: TestClock.date("2026-10-02 06:00").addingTimeInterval(TimeInterval(index * 600)))
        }
        let planned = plan(visits: visits, prefs: prefs())

        #expect(planned.count == NotificationPlanner.maximumCount)
        #expect(planned.map(\.fireDate) == planned.map(\.fireDate).sorted())
    }

    @Test("A visit moved out of the plan leaves no notification behind")
    func replacing() {
        let visit = makeVisit(start: TestClock.date("2026-10-02 10:00"))
        let before = plan(visits: [visit], prefs: prefs())
        var moved = visit
        moved.startsAt = TestClock.date("2026-10-03 10:00")
        moved.endsAt = TestClock.date("2026-10-03 11:00")
        let after = plan(visits: [moved], prefs: prefs())

        #expect(before.map(\.id) == after.map(\.id))
        #expect(before.map(\.fireDate) != after.map(\.fireDate))
    }

    // MARK: - Records to write

    @Test("Visits waiting for their record bring one nudge this evening, or tomorrow evening once it has passed")
    func recordsToWrite() throws {
        func planned(now: Date, count: Int, on: Bool = true) -> [PlannedNotification] {
            var value = prefs()
            value.recordsToWrite = on
            return NotificationPlanner.plan(
                NotificationPlanner.Input(now: now, calendar: calendar, appointments: [], clients: [], prefs: value,
                                          recordsToWrite: count),
                texts: texts
            )
        }
        let today = try #require(planned(now: TestClock.now, count: 2).first)
        #expect(today.kind == .recordsToWrite)
        #expect(today.fireDate == TestClock.date("2026-10-01 19:00"))
        #expect(today.body.contains("2"))
        let late = try #require(planned(now: TestClock.date("2026-10-01 20:00"), count: 1).first)
        #expect(late.fireDate == TestClock.date("2026-10-02 19:00"))
        #expect(planned(now: TestClock.now, count: 0).isEmpty, "nothing owed, nothing said")
        #expect(planned(now: TestClock.now, count: 2, on: false).isEmpty, "switched off in the settings")
    }

    @Test("Prefs saved before the records switch existed keep her choices and turn it on")
    func oldPrefsDecode() throws {
        let json = """
        {"newBookings":false,"cancellations":true,"clientCheckIns":true,"followUpsDue":true,"birthdays":false,
         "dailySummary":true,"clientRemindersEnabled":true,"reminderTimeMinutes":1080}
        """
        let prefs = try JSONDecoder().decode(NotificationPrefs.self, from: Data(json.utf8))
        #expect(!prefs.newBookings && !prefs.birthdays && prefs.dailySummary)
        #expect(prefs.recordsToWrite)
    }

    // MARK: - Privacy

    @Test("No title or body carries a client's name or a service name, in any localization",
          arguments: AppLocalization.allCases)
    func noNames(localization: AppLocalization) {
        let camila = reachable(name: "Camila Rocha")
        let julia = Client(
            name: "Julia Mendes", phoneE164: "+5511955550009", birthday: Birthday(month: 10, day: 3),
            createdAt: TestClock.now
        )
        let visits = [
            makeVisit(clientID: camila.id, start: TestClock.date("2026-10-02 10:00"), serviceName: "Glow Facial"),
            makeVisit(clientID: julia.id, start: TestClock.date("2026-10-02 11:30"), serviceName: "Deep Cleansing")
        ]
        let planned = NotificationPlanner.plan(
            NotificationPlanner.Input(
                now: TestClock.now, calendar: calendar, appointments: visits, clients: [camila, julia],
                prefs: prefs(birthdays: true, dailySummary: true, reminders: true), recordsToWrite: 2
            ),
            texts: NotificationTexts.localized(in: localization.locale)
        )
        let kinds = Set(planned.map(\.kind))
        let forbidden = ["Camila", "Rocha", "Julia", "Mendes", "Glow", "Facial", "Deep", "Cleansing"]

        #expect(kinds == Set(LocalNotificationKind.allCases))
        for notification in planned {
            #expect(!notification.title.isEmpty && !notification.body.isEmpty)
            for word in forbidden {
                #expect(!notification.title.contains(word), "\(notification.title) names \(word)")
                #expect(!notification.body.contains(word), "\(notification.body) names \(word)")
            }
        }
    }
}

// MARK: - Quiet hours and urgent exceptions

extension NotificationPlannerTests {
    @Test("Urgent events ignore quiet hours; the others wait for the window to end",
          arguments: [(AlertKind.clientRunningLate, true), (.cancellation, true), (.newBooking, false),
                      (.formReceived, false), (.birthday, false), (.remindersReady, false)])
    func delivery(kind: AlertKind, immediate: Bool) {
        let fire = TestClock.date("2026-10-01 23:00")
        let sameDay = TestClock.date("2026-10-01 15:00")
        let delivered = NotificationPlanner.deliveryDate(
            kind: kind, fireAt: fire, visitStartsAt: sameDay, window: night, calendar: calendar
        )

        #expect(delivered == (immediate ? fire : TestClock.date("2026-10-02 07:00")))
    }

    @Test("Without quiet hours everything is delivered at its time")
    func noQuietHours() {
        let fire = TestClock.date("2026-10-01 23:00")

        #expect(NotificationPlanner.deliveryDate(
            kind: .newBooking, fireAt: fire, visitStartsAt: nil, window: nil, calendar: calendar
        ) == fire)
    }

    // MARK: - Daylight saving

    /// Brazil has had no clock change since 2019: a control day where nothing moves.
    private static let saoPaulo = ZoneDay(zone: "America/Sao_Paulo", date: "2026-11-01", dayHours: 24, windowHours: 6)

    @Test("Reminders, summaries and birthdays land on the right wall-clock time around a clock change",
          arguments: ZoneDay.all + [saoPaulo])
    func daylightSaving(day: ZoneDay) throws {
        let calendar = day.calendar
        let now = calendar.date(byAdding: .day, value: -3, to: day.midnight) ?? day.midnight
        let client = Client(
            name: "Camila Rocha", phoneE164: "+5511955550001", birthday: nil, createdAt: now
        )
        let visit = makeVisit(
            clientID: client.id, start: TestClock.date("\(day.date) 10:00", zone: day.zone)
        )
        let planned = plan(
            visits: [visit], clients: [client], prefs: prefs(dailySummary: true, reminders: true), now: now,
            calendar: calendar
        )
        let summary = try #require(planned.first { $0.kind == .dailySummary })
        let reminder = try #require(planned.first { $0.kind == .remindersReady })
        let lead = try #require(planned.first { $0.kind == .nextVisit })

        #expect(calendar.dateComponents([.hour, .minute], from: summary.fireDate) == DateComponents(hour: 8, minute: 0))
        #expect(calendar.isDate(summary.fireDate, inSameDayAs: day.midnight))
        let time = calendar.dateComponents([.hour, .minute], from: reminder.fireDate)
        #expect(time == DateComponents(hour: 18, minute: 0))
        let eve = calendar.date(byAdding: .day, value: -1, to: day.midnight)!
        #expect(calendar.isDate(reminder.fireDate, inSameDayAs: eve))
        #expect(lead.fireDate == visit.startsAt.addingTimeInterval(-900))
    }
}
