//
//  FollowUpPlanner.swift
//  BelloHub
//

import Foundation

/// Who is due to hear from the professional: follow-ups by service interval, clients who have not come back, and
/// birthdays. Pure: `now` and the calendar are inputs, so DST and month ends are tested.
enum FollowUpPlanner {
    /// "Haven't returned" starts at this many days since the last visit.
    static let winBackDays = 60

    /// Clients whose last completed visit is at least their service's follow-up interval ago and who have
    /// nothing booked. Most overdue first. Archived clients and clients who asked not to be messaged are left out.
    static func dueFollowUps(
        clients: [Client], appointments: [Appointment], services: [Service], now: Date, calendar: Calendar
    ) -> [FollowUp] {
        let weeksByService = Dictionary(uniqueKeysWithValues: services.compactMap { service in
            service.followUpWeeks.map { (service.id, $0) }
        })
        return reachable(clients).compactMap { client -> FollowUp? in
            let own = appointments.filter { $0.clientID == client.id }
            guard let last = lastCompleted(own), !hasUpcoming(own, now: now),
                  let serviceID = last.serviceID, let weeks = weeksByService[serviceID],
                  let due = calendar.date(byAdding: .day, value: weeks * 7,
                                          to: calendar.startOfDay(for: last.startsAt)),
                  due <= now else { return nil }
            return FollowUp(clientID: client.id, serviceName: last.serviceName, lastVisit: last.startsAt, dueSince: due,
                            daysSinceLastVisit: days(from: last.startsAt, to: now, calendar: calendar))
        }
        .sorted { $0.dueSince < $1.dueSince }
    }

    /// Clients whose last visit was at least `winBackDays` ago and who have nothing booked. Longest away first.
    static func winBack(clients: [Client], appointments: [Appointment], now: Date, calendar: Calendar)
        -> [WinBackCandidate] {
        reachable(clients).compactMap { client -> WinBackCandidate? in
            let own = appointments.filter { $0.clientID == client.id }
            guard let last = lastCompleted(own), !hasUpcoming(own, now: now) else { return nil }
            let elapsed = days(from: last.startsAt, to: now, calendar: calendar)
            guard elapsed >= winBackDays else { return nil }
            return WinBackCandidate(clientID: client.id, lastVisit: last.startsAt, daysSinceLastVisit: elapsed)
        }
        .sorted { $0.daysSinceLastVisit > $1.daysSinceLastVisit }
    }

    /// Birthdays from today through `daysAhead - 1` days later, soonest first. A 29 February birthday falls on the
    /// 28th in a year that is not a leap year.
    static func birthdays(clients: [Client], now: Date, calendar: Calendar, daysAhead: Int = 7) -> [UpcomingBirthday] {
        let today = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: daysAhead, to: today) else { return [] }
        return clients
            .filter { !$0.isArchived }
            .compactMap { client -> UpcomingBirthday? in
                guard let next = client.birthday?.nextOccurrence(onOrAfter: today, calendar: calendar), next < end
                else { return nil }
                return UpcomingBirthday(clientID: client.id, date: next, isToday: next == today)
            }
            .sorted { ($0.date, $0.clientID.uuidString) < ($1.date, $1.clientID.uuidString) }
    }

    // MARK: - Private

    private static func reachable(_ clients: [Client]) -> [Client] {
        clients.filter { !$0.isArchived && $0.remindersEnabled }
    }

    private static func lastCompleted(_ appointments: [Appointment]) -> Appointment? {
        appointments.filter { $0.status == .completed }.max { $0.startsAt < $1.startsAt }
    }

    private static func hasUpcoming(_ appointments: [Appointment], now: Date) -> Bool {
        appointments.contains { $0.status.holdsTime && $0.startsAt >= now }
    }

    private static func days(from: Date, to: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }
}
