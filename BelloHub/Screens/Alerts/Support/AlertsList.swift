//
//  AlertsList.swift
//  BelloHub
//

import Foundation

/// What the local part of the Alerts tab (2.4) shows from the day's digest: the visit that starts soon. Reminders,
/// follow-ups, returns, clients not back and birthdays are one summary card that opens the follow-up queue
/// (routine-a item 5), so Alerts no longer repeats them. Booking requests, reschedules, the waitlist and the mailbox
/// come from the server (S8). Pure.
struct AlertsList: Equatable, Sendable {
    /// A visit that starts within this many minutes is worth an alert ("Review what matters before you start").
    static let upcomingVisitMinutes = 120

    let upcomingVisit: AgendaDigest.Visit?

    var isEmpty: Bool { upcomingVisit == nil }

    static func make(from digest: AgendaDigest) -> AlertsList {
        let soon = digest.nextVisit.flatMap { visit -> AgendaDigest.Visit? in
            guard !digest.nextIsInProgress, digest.nextIsToday, visit.client != nil,
                  digest.minutesUntilNext <= upcomingVisitMinutes else { return nil }
            return visit
        }
        return AlertsList(upcomingVisit: soon)
    }
}
