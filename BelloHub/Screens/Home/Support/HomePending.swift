//
//  HomePending.swift
//  BelloHub
//

import Foundation

/// What Home lists under "Today" (routine-a item 4): the things that need her today, each with one action. Booking
/// requests are their own line, never mixed with follow-ups: they need a decision about the agenda. Pure.
struct HomePending: Equatable, Sendable {
    enum Item: Hashable, Identifiable, Sendable {
        /// Visit reminders she can send (D31).
        case reminders(count: Int)
        /// Visits she left with "Finish later" (item 7).
        case unfinishedVisits(count: Int)
        /// Booking and reschedule requests waiting for her answer (they live in Alerts).
        case bookingRequests(count: Int)
        /// Notifications were never asked and a visit is coming: the moment their use is clear.
        case notifications

        var id: String {
            switch self {
            case .reminders: "reminders"
            case .unfinishedVisits: "unfinishedVisits"
            case .bookingRequests: "bookingRequests"
            case .notifications: "notifications"
            }
        }
    }

    let items: [Item]

    var isEmpty: Bool { items.isEmpty }

    static func make(
        queue: FollowUpQueue, requestCount: Int, notificationsUndecided: Bool, hasUpcomingVisit: Bool
    ) -> HomePending {
        let active = queue.rows.flatMap(\.items)
        let reminders = active.filter { $0.kind == .reminder }.count
        let unfinished = active.filter { $0.kind == .unfinishedVisit }.count
        var items: [Item] = []
        if requestCount > 0 { items.append(.bookingRequests(count: requestCount)) }
        if reminders > 0 { items.append(.reminders(count: reminders)) }
        if unfinished > 0 { items.append(.unfinishedVisits(count: unfinished)) }
        if notificationsUndecided, hasUpcomingVisit { items.append(.notifications) }
        return HomePending(items: items)
    }
}
