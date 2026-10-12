//
//  NotificationPlanner.swift
//  BelloHub
//

import Foundation

/// Decides which local notifications the iPhone schedules: the next-visit reminder to the professional, birthdays (the
/// day before), the daily summary and "reminders ready" (the evening before, D31). Pure: `now` and the calendar (the
/// business time zone) come in, and the texts come from `NotificationTexts`, which cannot carry a name.
///
/// Quiet hours hold a notification until the window ends, or drop it when that would be too late to matter. The urgent
/// exceptions (a client running late, a cancellation of a visit today) are server events (S8) and go through
/// `deliveryDate` the same way.
enum NotificationPlanner {
    struct Input: Sendable {
        var now: Date
        var calendar: Calendar
        var appointments: [Appointment]
        var clients: [Client]
        var prefs: NotificationPrefs
        /// Visits waiting for their record right now (`RecordPending`): only the count reaches the planner.
        var recordsToWrite = 0
    }

    /// Minutes before a visit that the professional is told.
    static let nextVisitLeadMinutes = 15
    /// Birthday notifications arrive at this time of the day before (minutes from midnight).
    static let birthdayMinutes = 9 * 60
    /// The daily summary arrives at this time (minutes from midnight).
    static let dailySummaryMinutes = 8 * 60
    /// "Records to complete" arrives at this time, at the end of a working day (minutes from midnight).
    static let recordsToWriteMinutes = 19 * 60
    /// How many days ahead the planner looks. The phone keeps only 64 pending notifications, so the plan is rebuilt
    /// after every calendar change and every time the app opens.
    static let horizonDays = 14
    /// Headroom under the system's limit of 64 pending notifications.
    static let maximumCount = 60

    static func plan(_ input: Input, texts: NotificationTexts) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []
        planned += nextVisits(input, texts: texts)
        if input.prefs.birthdays { planned += birthdays(input, texts: texts) }
        if input.prefs.dailySummary { planned += dailySummaries(input, texts: texts) }
        if input.prefs.clientRemindersEnabled { planned += remindersReady(input, texts: texts) }
        if input.prefs.recordsToWrite { planned += recordsToWrite(input, texts: texts) }
        return Array(planned.sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }.prefix(maximumCount))
    }

    /// When a notification of `kind` that wanted to arrive at `fireAt` is delivered: at once when it is urgent or the
    /// phone is not in quiet hours, otherwise when the quiet window ends. Nil when there is no release moment, so the
    /// caller drops it.
    static func deliveryDate(
        kind: AlertKind, fireAt: Date, visitStartsAt: Date?, window: QuietHoursWindow?, calendar: Calendar
    ) -> Date? {
        if QuietHours.shouldDeliverNow(
            kind: kind, visitStartsAt: visitStartsAt, at: fireAt, window: window, calendar: calendar
        ) { return fireAt }
        return QuietHours.nextRelease(after: fireAt, window: window, calendar: calendar)
    }

    // MARK: - Kinds

    private static func nextVisits(_ input: Input, texts: NotificationTexts) -> [PlannedNotification] {
        upcoming(input).compactMap { visit in
            let fire = visit.startsAt.addingTimeInterval(-TimeInterval(nextVisitLeadMinutes * 60))
            guard fire > input.now,
                  let delivery = deliveryDate(
                    kind: .nextVisit, fireAt: fire, visitStartsAt: visit.startsAt, window: input.prefs.quietHours,
                    calendar: input.calendar
                  ),
                  delivery < visit.startsAt else { return nil }
            return PlannedNotification(
                id: "\(PlannedNotification.identifierPrefix)nextVisit.\(visit.id.uuidString)", kind: .nextVisit,
                fireDate: delivery, title: texts.nextVisitTitle, body: texts.nextVisitBody
            )
        }
    }

    private static func birthdays(_ input: Input, texts: NotificationTexts) -> [PlannedNotification] {
        let upcoming = FollowUpPlanner.birthdays(
            clients: input.clients, now: input.now, calendar: input.calendar, daysAhead: horizonDays
        )
        let days = Set(upcoming.map(\.date))
        return days.compactMap { day -> PlannedNotification? in
            guard let eve = input.calendar.date(byAdding: .day, value: -1, to: day),
                  let fire = time(birthdayMinutes, on: eve, calendar: input.calendar), fire > input.now,
                  let delivery = deliveryDate(
                    kind: .birthday, fireAt: fire, visitStartsAt: nil, window: input.prefs.quietHours,
                    calendar: input.calendar
                  ) else { return nil }
            return PlannedNotification(
                id: "\(PlannedNotification.identifierPrefix)birthday.\(key(of: day, calendar: input.calendar))",
                kind: .birthday, fireDate: delivery, title: texts.birthdayTitle, body: texts.birthdayBody
            )
        }
    }

    private static func dailySummaries(_ input: Input, texts: NotificationTexts) -> [PlannedNotification] {
        let visits = upcoming(input)
        let today = input.calendar.startOfDay(for: input.now)
        return (0..<horizonDays).compactMap { offset -> PlannedNotification? in
            guard let day = input.calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = time(dailySummaryMinutes, on: day, calendar: input.calendar), fire > input.now,
                  let delivery = deliveryDate(
                    kind: .dailySummary, fireAt: fire, visitStartsAt: nil, window: input.prefs.quietHours,
                    calendar: input.calendar
                  ) else { return nil }
            let count = visits.filter { input.calendar.isDate($0.startsAt, inSameDayAs: day) }.count
            guard count > 0 else { return nil }
            return PlannedNotification(
                id: "\(PlannedNotification.identifierPrefix)dailySummary.\(key(of: day, calendar: input.calendar))",
                kind: .dailySummary, fireDate: delivery, title: texts.dailySummaryTitle,
                body: texts.dailySummaryBody(count)
            )
        }
    }

    private static func remindersReady(_ input: Input, texts: NotificationTexts) -> [PlannedNotification] {
        let byID = Dictionary(input.clients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remindable = upcoming(input).filter {
            $0.reminderSentAt == nil && RemindersReady.isRemindable($0, client: byID[$0.clientID])
        }
        let byDay = Dictionary(grouping: remindable) { input.calendar.startOfDay(for: $0.startsAt) }
        return byDay.compactMap { day, visits -> PlannedNotification? in
            guard let first = visits.first,
                  let moment = RemindersReady.moment(
                    forVisitAt: first.startsAt, prefs: input.prefs, calendar: input.calendar
                  ), moment > input.now,
                  let delivery = deliveryDate(
                    kind: .remindersReady, fireAt: moment, visitStartsAt: nil, window: input.prefs.quietHours,
                    calendar: input.calendar
                  ) else { return nil }
            return PlannedNotification(
                id: "\(PlannedNotification.identifierPrefix)remindersReady.\(key(of: day, calendar: input.calendar))",
                kind: .remindersReady, fireDate: delivery, title: texts.remindersReadyTitle,
                body: texts.remindersReadyBody(visits.count)
            )
        }
    }

    /// One nudge, this evening (or tomorrow evening when it has passed), while visits wait for their record. The plan
    /// is rebuilt after every change in the vault, so a record written meanwhile takes it away.
    private static func recordsToWrite(_ input: Input, texts: NotificationTexts) -> [PlannedNotification] {
        guard input.recordsToWrite > 0 else { return [] }
        let today = input.calendar.startOfDay(for: input.now)
        let tomorrow = input.calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let evening = [today, tomorrow].lazy
            .compactMap { time(recordsToWriteMinutes, on: $0, calendar: input.calendar) }
            .first { $0 > input.now }
        guard let evening,
              let delivery = deliveryDate(
                kind: LocalNotificationKind.recordsToWrite.alertKind, fireAt: evening, visitStartsAt: nil,
                window: input.prefs.quietHours, calendar: input.calendar
              ) else { return [] }
        return [PlannedNotification(
            id: "\(PlannedNotification.identifierPrefix)recordsToWrite", kind: .recordsToWrite, fireDate: delivery,
            title: texts.recordsToWriteTitle, body: texts.recordsToWriteBody(input.recordsToWrite)
        )]
    }

    // MARK: - Helpers

    private static func upcoming(_ input: Input) -> [Appointment] {
        let end = input.calendar.date(byAdding: .day, value: horizonDays, to: input.now)
            ?? input.now.addingTimeInterval(TimeInterval(horizonDays * 86_400))
        return input.appointments
            .filter { $0.status.holdsTime && $0.startsAt > input.now && $0.startsAt < end }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private static func time(_ minutes: Int, on day: Date, calendar: Calendar) -> Date? {
        calendar.date(
            bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day, matchingPolicy: .nextTime
        )
    }

    /// `2026-10-01`, the day in the business time zone: part of an identifier, so a day has one notification per kind.
    private static func key(of day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
