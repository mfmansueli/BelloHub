//
//  AlertsList.swift
//  BelloHub
//

import Foundation

/// What the local part of the Alerts tab (2.4) lists, worked out from the day's digest: the reminders ready to send
/// (D31), the visit that starts soon, the birthdays of the week and how many clients wait in Follow-ups and Win back.
/// Booking requests, cancellations, check-ins and forms come from the server (S8) and join this list then. Pure.
struct AlertsList: Equatable, Sendable {
    struct Birthday: Equatable, Identifiable, Sendable {
        let client: Client
        let upcoming: UpcomingBirthday
        var id: UUID { client.id }
    }

    /// A visit that starts within this many minutes is worth an alert ("Review what matters before you start").
    static let upcomingVisitMinutes = 120

    let remindersReady: [RemindersReady.Item]
    let upcomingVisit: AgendaDigest.Visit?
    let birthdays: [Birthday]
    let followUpCount: Int
    let winBackCount: Int

    var isEmpty: Bool {
        remindersReady.isEmpty && upcomingVisit == nil && birthdays.isEmpty && followUpCount == 0 && winBackCount == 0
    }

    static func make(from digest: AgendaDigest) -> AlertsList {
        let soon = digest.nextVisit.flatMap { visit -> AgendaDigest.Visit? in
            guard !digest.nextIsInProgress, digest.nextIsToday, visit.client != nil,
                  digest.minutesUntilNext <= upcomingVisitMinutes else { return nil }
            return visit
        }
        return AlertsList(
            remindersReady: digest.remindersReady,
            upcomingVisit: soon,
            birthdays: digest.birthdays.compactMap { birthday in
                digest.client(birthday.clientID).map { Birthday(client: $0, upcoming: birthday) }
            },
            followUpCount: digest.followUps.count,
            winBackCount: digest.winBack.count
        )
    }
}
