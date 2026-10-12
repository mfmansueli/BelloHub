//
//  HomeBlockIDs.swift
//  BelloHub
//

import Foundation

/// The identities of what Home shows, in order: the visit on the hero card, each line of "Today", the records to follow
/// up, each visit of the rest of today and the people to reach out to. `motionRows` watches them so only a block or a
/// row that really came or went moves (docs/09-MOTION.md section 3.10). Pure.
enum HomeBlockIDs {
    /// How many records to follow up Home lists before "See all".
    static let recordsShown = 3

    static func make(
        digest: AgendaDigest, pending: HomePending, records: RecordPending = .empty, reachOut: HomeReachOut
    ) -> [String] {
        var ids: [String] = []
        if digest.isDayClear { ids.append("empty") }
        if let next = digest.nextVisit { ids.append("next.\(next.id.uuidString)") }
        ids += pending.items.map { "today.\($0.id)" }
        ids += records.items.prefix(HomeBlockIDs.recordsShown).map { "records.\($0.id)" }
        ids += digest.restOfToday.map { "rest.\($0.id.uuidString)" }
        ids += reachOut.preview.map { "reachOut.\($0.client.id.uuidString)" }
        return ids
    }
}
