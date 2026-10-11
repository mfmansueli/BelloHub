//
//  InboxAlerts.swift
//  BelloHub
//

import Foundation

/// The server part of the Alerts tab (2.4): booking requests and reschedule requests waiting for her answer, oldest
/// first, and the waitlist when somebody is on it. A request she already answered leaves the list at once, before
/// the server confirms. Pure; it takes `now`.
struct InboxAlerts: Equatable, Sendable {
    let bookingRequests: [IncomingBooking]
    let reschedules: [RescheduleRequest]
    /// People still waiting or offered a time.
    let waitingCount: Int
    /// A cancelled time is free again: the waitlist card says so.
    let hasOpenTime: Bool

    var isEmpty: Bool { bookingRequests.isEmpty && reschedules.isEmpty && waitingCount == 0 }

    static let empty = InboxAlerts(bookingRequests: [], reschedules: [], waitingCount: 0, hasOpenTime: false)

    static func make(snapshot: InboxSnapshot, answering: Set<String>, timeZone: TimeZone, now: Date) -> InboxAlerts {
        let board = WaitlistBoard.make(snapshot: snapshot, timeZone: timeZone, now: now)
        return InboxAlerts(
            bookingRequests: snapshot.pendingRequests.filter { !answering.contains($0.id) },
            reschedules: snapshot.pendingReschedules.filter { !answering.contains($0.id) },
            waitingCount: board.forThatDay.count + board.others.count,
            hasOpenTime: board.openTime != nil && !board.offerable.isEmpty
        )
    }
}
