//
//  WinBackList.swift
//  BelloHub
//

import Foundation

/// What the Win back screen (2.8) lists: the clients who have not been back for two months or more, longest away first.
/// A client that no longer exists is left out. The rule is `FollowUpPlanner.winBack`'s; this only pairs it with the
/// client. Pure.
struct WinBackList: Equatable, Sendable {
    struct Row: Equatable, Identifiable, Sendable {
        let client: Client
        let candidate: WinBackCandidate
        var id: UUID { client.id }
    }

    let rows: [Row]

    var isEmpty: Bool { rows.isEmpty }

    static func make(from digest: AgendaDigest) -> WinBackList {
        WinBackList(rows: digest.winBack.compactMap { candidate in
            digest.client(candidate.clientID).map { Row(client: $0, candidate: candidate) }
        })
    }
}
