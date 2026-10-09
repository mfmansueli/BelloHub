//
//  NoShowHistoryEntry.swift
//  BelloHub
//

import Foundation

/// One line of a client's no-show history (4.11): a visit she missed, or cancelled inside the free window.
struct NoShowHistoryEntry: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case noShow
        case lateCancellation
    }

    /// Why the line does or does not count toward her limit.
    enum Standing: Equatable, Sendable {
        /// Counts toward the limit now.
        case counts
        /// She forgave it (D13).
        case forgiven
        /// Too old (outside the counting period) or before the day her count started from zero.
        case expired
        /// A late cancellation that the no-show rule does not count.
        case notCounted
    }

    /// The appointment's id.
    let id: UUID
    let startsAt: Date
    let serviceName: String
    let kind: Kind
    let standing: Standing

    /// A no-show she has not forgiven can be forgiven; nothing else has a forgive action.
    var canForgive: Bool {
        kind == .noShow && standing != .forgiven
    }
}
