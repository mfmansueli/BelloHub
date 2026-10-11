//
//  AgendaDigest.swift
//  BelloHub
//

import Foundation

/// Everything Home, Alerts, Follow-ups and Win back show about her day and her clients, worked out once from the raw
/// data. Pure: `now` and the days (the business time zone) come in, and every rule has one owner elsewhere
/// (`FollowUpPlanner`, `WeekSummary`, `RemindersReady`); this type only gathers them, so the four screens can never
/// disagree about who is due or what is next.
struct AgendaDigest: Equatable, Sendable {
    /// A visit with the name of the client it belongs to.
    struct Visit: Equatable, Identifiable, Sendable {
        let appointment: Appointment
        let client: Client?

        var id: UUID { appointment.id }
        var clientName: String { client?.name ?? "" }
    }

    struct Input: Sendable {
        var appointments: [Appointment]
        var clients: [Client]
        var services: [Service]
        var blocks: [TimeBlock]
        var availability: AvailabilitySettings
        var prefs: NotificationPrefs
        var now: Date
    }

    /// How far ahead "next up" looks.
    static let nextVisitHorizonDays = 7

    /// The visit that is happening or comes next: today, or within the coming week.
    let nextVisit: Visit?
    /// The next visit has started and has not ended yet.
    let nextIsInProgress: Bool
    let nextIsToday: Bool
    /// Minutes until the next visit starts, rounded up; zero while it is in progress.
    let minutesUntilNext: Int
    /// The other visits of today, in time order (cancelled ones are left out).
    let restOfToday: [Visit]
    let week: WeekSummary
    let remindersReady: [RemindersReady.Item]
    let followUps: [FollowUp]
    let winBack: [WinBackCandidate]
    let birthdays: [UpcomingBirthday]
    private let clientsByID: [UUID: Client]

    /// Today's visits that still wait (the next one included).
    var leftToday: Int { week.leftToday }

    /// Reminders she has not opened yet.
    var remindersToSend: Int { remindersReady.filter { $0.openedAt == nil }.count }

    func client(_ id: UUID) -> Client? { clientsByID[id] }

    /// Nothing to show for today or the coming days: the screen shows its empty state.
    var isDayClear: Bool { nextVisit == nil && restOfToday.isEmpty }

    static func make(_ input: Input, days: CalendarDays) -> AgendaDigest {
        let byID = Dictionary(input.clients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let now = input.now
        let horizon = days.adding(days: nextVisitHorizonDays + 1, to: now)
        let next = input.appointments
            .filter { $0.status.holdsTime && $0.endsAt > now && $0.startsAt < horizon }
            .min { $0.startsAt < $1.startsAt }
        let today = days.interval(of: now)
        let rest = input.appointments
            .filter { CalendarDayLayout.isShown($0) && $0.id != next?.id && today.contains($0.startsAt) }
            .sorted { ($0.startsAt, $0.id.uuidString) < ($1.startsAt, $1.id.uuidString) }
            .map { Visit(appointment: $0, client: byID[$0.clientID]) }
        let shortest = input.services.filter(\.isActive).map(\.durationMinutes).min() ?? 60
        let weekRange = days.weekInterval(containing: now)
        let week = WeekSummary.make(
            WeekSummary.Input(
                now: now, settings: input.availability,
                appointments: input.appointments.filter { $0.interval.intersection(with: weekRange) != nil },
                blocks: input.blocks, shortestServiceMinutes: shortest
            ),
            days: days
        )
        let calendar = days.calendar
        return AgendaDigest(
            nextVisit: next.map { Visit(appointment: $0, client: byID[$0.clientID]) },
            nextIsInProgress: next.map { $0.startsAt <= now } ?? false,
            nextIsToday: next.map { days.isSameDay($0.startsAt, now) } ?? false,
            minutesUntilNext: next.map { max(0, Int(($0.startsAt.timeIntervalSince(now) / 60).rounded(.up))) } ?? 0,
            restOfToday: rest,
            week: week,
            remindersReady: RemindersReady.items(
                appointments: input.appointments, clients: input.clients, prefs: input.prefs, now: now,
                calendar: calendar
            ),
            followUps: FollowUpPlanner.dueFollowUps(
                clients: input.clients, appointments: input.appointments, services: input.services, now: now,
                calendar: calendar
            ),
            winBack: FollowUpPlanner.winBack(
                clients: input.clients, appointments: input.appointments, now: now, calendar: calendar
            ),
            birthdays: FollowUpPlanner.birthdays(clients: input.clients, now: now, calendar: calendar),
            clientsByID: byID
        )
    }
}
