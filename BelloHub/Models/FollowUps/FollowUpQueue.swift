//
//  FollowUpQueue.swift
//  BelloHub
//

import Foundation

/// The one follow-up queue (routine-a item 5): visit reminders, unfinished visits, check-ins after a visit, returns
/// due, clients who did not come back and birthdays, in one list grouped by client. Every reason of a client stays on
/// her row (nothing is lost by grouping); the row's main action is its most urgent reason. Suggestions she snoozed,
/// dismissed or marked as sent leave the active list and wait in `setAside`. Booking requests are not here: they need
/// a decision about the agenda and stay in Alerts. Pure: `now`, the calendar and every input are parameters.
struct FollowUpQueue: Equatable, Sendable {
    struct Row: Identifiable, Equatable, Sendable {
        let client: Client
        /// Most urgent first.
        let items: [FollowUpItem]

        var id: UUID { client.id }
        var primary: FollowUpItem { items[0] }
        /// The earliest due date among her reasons.
        var due: Date { items.map(\.due).min() ?? primary.due }
    }

    struct Input: Sendable {
        var digest: AgendaDigest
        var appointments: [Appointment]
        var clients: [Client]
        var messageLogs: [MessageLog]
        var decisions: [String: FollowUpDecision]
        var closings: [VisitClosing]
        var now: Date
        var calendar: Calendar
    }

    /// How far back a completed visit still suggests a check-in: today and yesterday.
    static let postVisitDays = 1

    let rows: [Row]
    let setAside: [Row]

    var isEmpty: Bool { rows.isEmpty && setAside.isEmpty }

    /// The active rows that have at least one reason of the filter, each keeping only those reasons.
    func rows(_ filter: FollowUpFilter) -> [Row] {
        Self.filtered(rows, filter)
    }

    func setAside(_ filter: FollowUpFilter) -> [Row] {
        Self.filtered(setAside, filter)
    }

    /// Clients with at least one active reason of the filter.
    func count(_ filter: FollowUpFilter) -> Int {
        rows(filter).count
    }

    static func make(_ input: Input) -> FollowUpQueue {
        let byID = Dictionary(input.clients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let items = reminders(input) + unfinished(input) + postVisits(input, clients: byID) + returns(input)
            + notBack(input) + birthdays(input)
        let delivered = items.map { withDelivery($0, input: input) }
        var active: [FollowUpItem] = []
        var aside: [FollowUpItem] = []
        for item in delivered {
            let decision = input.decisions[item.occurrence]
            if item.kind.canBeSetAside, decision?.setsAside(at: input.now) == true {
                aside.append(item)
            } else if item.kind == .reminder, item.delivery.isMarkedSent {
                aside.append(item)
            } else {
                active.append(item)
            }
        }
        return FollowUpQueue(rows: grouped(active, clients: byID), setAside: grouped(aside, clients: byID))
    }

    // MARK: - Reasons

    private static func reminders(_ input: Input) -> [FollowUpItem] {
        input.digest.remindersReady.map { ready in
            var item = FollowUpItem(
                kind: .reminder, clientID: ready.client.id, occurrence: "reminder:\(ready.appointment.id)",
                due: ready.appointment.startsAt,
                reason: .reminder(visitStart: ready.appointment.startsAt, serviceName: ready.appointment.serviceName)
            )
            item.appointmentID = ready.appointment.id
            item.serviceName = ready.appointment.serviceName
            return item
        }
    }

    private static func unfinished(_ input: Input) -> [FollowUpItem] {
        input.closings.filter { $0.isDeferred && !$0.isComplete }.map { closing in
            var item = FollowUpItem(
                kind: .unfinishedVisit, clientID: closing.clientID, occurrence: "visit:\(closing.id)",
                due: closing.recordCreatedAt,
                reason: .unfinishedVisit(serviceName: closing.serviceName, openSteps: closing.openSteps)
            )
            item.recordID = closing.id
            item.appointmentID = closing.appointmentID
            item.serviceName = closing.serviceName
            return item
        }
    }

    /// Completed visits of today and yesterday whose client can be reached.
    private static func postVisits(_ input: Input, clients: [UUID: Client]) -> [FollowUpItem] {
        let today = input.calendar.startOfDay(for: input.now)
        guard let start = input.calendar.date(byAdding: .day, value: -postVisitDays, to: today) else { return [] }
        return input.appointments
            .filter { $0.status == .completed && $0.startsAt >= start && $0.startsAt <= input.now }
            .compactMap { visit -> FollowUpItem? in
                guard let client = clients[visit.clientID], !client.isArchived, client.remindersEnabled,
                      client.phoneE164?.isEmpty == false else { return nil }
                var item = FollowUpItem(
                    kind: .postVisit, clientID: client.id, occurrence: "postVisit:\(visit.id)", due: visit.startsAt,
                    reason: .postVisit(visitStart: visit.startsAt, serviceName: visit.serviceName)
                )
                item.appointmentID = visit.id
                item.serviceName = visit.serviceName
                return item
            }
    }

    private static func returns(_ input: Input) -> [FollowUpItem] {
        input.digest.followUps.map { followUp in
            var item = FollowUpItem(
                kind: .returnDue, clientID: followUp.clientID,
                occurrence: "returnDue:\(followUp.clientID):\(Int(followUp.lastVisit.timeIntervalSince1970))",
                due: followUp.dueSince,
                reason: .returnDue(
                    serviceName: followUp.serviceName, intervalWeeks: followUp.intervalWeeks,
                    lastVisit: followUp.lastVisit
                )
            )
            item.serviceName = followUp.serviceName
            return item
        }
    }

    private static func notBack(_ input: Input) -> [FollowUpItem] {
        input.digest.winBack.map { candidate in
            let lastDay = input.calendar.startOfDay(for: candidate.lastVisit)
            let due = input.calendar.date(byAdding: .day, value: FollowUpPlanner.winBackDays, to: lastDay)
                ?? candidate.lastVisit
            return FollowUpItem(
                kind: .notBack, clientID: candidate.clientID,
                occurrence: "notBack:\(candidate.clientID):\(Int(candidate.lastVisit.timeIntervalSince1970))",
                due: due, reason: .notBack(daysSinceLastVisit: candidate.daysSinceLastVisit)
            )
        }
    }

    private static func birthdays(_ input: Input) -> [FollowUpItem] {
        input.digest.birthdays.map { birthday in
            let year = input.calendar.component(.year, from: birthday.date)
            return FollowUpItem(
                kind: .birthday, clientID: birthday.clientID, occurrence: "birthday:\(birthday.clientID):\(year)",
                due: birthday.date, reason: .birthday(date: birthday.date, isToday: birthday.isToday)
            )
        }
    }

    // MARK: - Messages

    /// Where the item's message stands: the visit's own reminder fields for a reminder; otherwise her mark, then the
    /// newest chat of the matching kind opened for the client since the item became due (a week earlier for a
    /// birthday, which is listed ahead).
    private static func withDelivery(_ item: FollowUpItem, input: Input) -> FollowUpItem {
        var updated = item
        if item.kind == .reminder {
            let visit = input.appointments.first { $0.id == item.appointmentID }
            updated.delivery = visit.map(MessageDeliveryState.reminder(of:)) ?? .readyToSend
            return updated
        }
        let since = item.kind == .birthday
            ? input.calendar.date(byAdding: .day, value: -7, to: item.due) ?? item.due
            : item.due
        let opened = input.messageLogs
            .filter { $0.clientID == item.clientID && item.kind.messageTemplates.contains($0.template) }
            .filter { $0.openedAt >= since }
            .map(\.openedAt).max()
        updated.delivery = MessageDeliveryState.make(
            openedAt: opened, markedSentAt: input.decisions[item.occurrence]?.markedSentAt
        )
        return updated
    }

    // MARK: - Grouping

    /// One row per client, her reasons most urgent first; rows by their main reason's urgency, then by the earliest
    /// due date. A client who no longer exists (merged, deleted) is left out rather than shown without a name.
    private static func grouped(_ items: [FollowUpItem], clients: [UUID: Client]) -> [Row] {
        let byClient = Dictionary(grouping: items, by: \.clientID)
        let rows = byClient.compactMap { clientID, items -> Row? in
            guard let client = clients[clientID] else { return nil }
            let sorted = items.sorted {
                ($0.kind.priority, $0.due, $0.occurrence) < ($1.kind.priority, $1.due, $1.occurrence)
            }
            return Row(client: client, items: sorted)
        }
        return rows.sorted {
            ($0.primary.kind.priority, $0.due, $0.client.id.uuidString)
                < ($1.primary.kind.priority, $1.due, $1.client.id.uuidString)
        }
    }

    private static func filtered(_ rows: [Row], _ filter: FollowUpFilter) -> [Row] {
        guard filter != .all else { return rows }
        return rows.compactMap { row in
            let kept = row.items.filter { filter.includes($0.kind) }
            return kept.isEmpty ? nil : Row(client: row.client, items: kept)
        }
    }
}
