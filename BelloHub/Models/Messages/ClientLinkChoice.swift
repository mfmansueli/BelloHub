//
//  ClientLinkChoice.swift
//  BelloHub
//

import Foundation

/// Which link a message about one visit carries, and why (owner, 2026-10-11: "lead straight to the exact page to change
/// or cancel"). The sheet says it in a quiet line, so she always knows what the client will open.
struct ClientLinkChoice: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        /// The client's own link to change or cancel this visit.
        case manageLink
        /// Her booking page, for this reason.
        case bookingPage(Reason)
    }

    enum Reason: Equatable, Sendable {
        /// She added the visit herself: the server has no booking, so there is no personal link.
        case addedByHand
        /// The visit was cancelled or is over: there is nothing left to change.
        case notActive
        /// The iPhone could not reach the server.
        case offline
        /// The server did not give the link.
        case failed
    }

    let source: Source
    /// The full address the message carries (`ClientLinkText`); nil when she has no booking page yet either.
    let link: String?

    /// The personal link could exist but was not obtained (offline, or the server did not answer): worth asking again
    /// when she presses send.
    var canRetry: Bool {
        source == .bookingPage(.offline) || source == .bookingPage(.failed)
    }
}
