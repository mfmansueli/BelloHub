//
//  HomeReachOut.swift
//  BelloHub
//

import Foundation

/// The one secondary card of Home (routine-a item 4): how many clients the queue suggests reaching out to (check-ins
/// after a visit, returns, clients not back lately, birthdays) and the first few, each with the reason of its row.
/// Reminders and unfinished visits are not counted here: Home lists them under "Today". Pure.
struct HomeReachOut: Equatable, Sendable {
    static let previewCount = 2
    static let kinds: Set<FollowUpKind> = [.postVisit, .returnDue, .notBack, .birthday]

    /// Clients with at least one of those reasons.
    let count: Int
    /// The first rows, each reduced to those reasons.
    let preview: [FollowUpQueue.Row]

    var isEmpty: Bool { preview.isEmpty }

    static func make(queue: FollowUpQueue) -> HomeReachOut {
        let rows = queue.rows.compactMap { row -> FollowUpQueue.Row? in
            let kept = row.items.filter { kinds.contains($0.kind) }
            return kept.isEmpty ? nil : FollowUpQueue.Row(client: row.client, items: kept)
        }
        return HomeReachOut(count: rows.count, preview: Array(rows.prefix(previewCount)))
    }
}
