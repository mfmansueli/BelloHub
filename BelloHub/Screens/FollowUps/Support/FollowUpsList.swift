//
//  FollowUpsList.swift
//  BelloHub
//

import Foundation

/// What the Follow-ups screen (2.7) lists: the clients whose return date has arrived, most overdue first, and the
/// birthdays of the week, soonest first. A client that no longer exists (merged, deleted) is left out rather than shown
/// with an empty name. The rules themselves are `FollowUpPlanner`'s; this only pairs them with the clients. Pure.
struct FollowUpsList: Equatable, Sendable {
    struct DueRow: Equatable, Identifiable, Sendable {
        let client: Client
        let followUp: FollowUp
        var id: UUID { client.id }
    }

    struct BirthdayRow: Equatable, Identifiable, Sendable {
        let client: Client
        let birthday: UpcomingBirthday
        var id: UUID { client.id }
    }

    let due: [DueRow]
    let birthdays: [BirthdayRow]

    var isEmpty: Bool { due.isEmpty && birthdays.isEmpty }

    static func make(from digest: AgendaDigest) -> FollowUpsList {
        FollowUpsList(
            due: digest.followUps.compactMap { followUp in
                digest.client(followUp.clientID).map { DueRow(client: $0, followUp: followUp) }
            },
            birthdays: digest.birthdays.compactMap { birthday in
                digest.client(birthday.clientID).map { BirthdayRow(client: $0, birthday: birthday) }
            }
        )
    }
}
