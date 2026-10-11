//
//  CancellationDecision.swift
//  BelloHub
//

import Foundation

/// What a client can do about a visit right now, by the professional's rules (D11, D12).
struct CancellationDecision: Equatable, Sendable {
    enum Cancel: Equatable, Sendable {
        /// Inside the free window: immediate, at no cost.
        case free
        /// After the window the client may still cancel, with an honest warning (the default).
        case allowedWithWarning
        /// After the window she must message the professional.
        case askByMessage
        /// The visit has already started or no longer holds a time.
        case unavailable
    }

    enum Reschedule: Equatable, Sendable {
        /// She picks a new time and it is moved at once.
        case direct
        /// She sends a request; the current time stays reserved until the professional answers.
        case request
        /// She must message the professional.
        case message
        case unavailable
    }

    let cancel: Cancel
    let reschedule: Reschedule
    let isInsideFreeWindow: Bool
    let hoursUntilStart: Double

    /// If the client cancels herself right now, it is a late cancellation.
    var cancellationWouldBeLate: Bool {
        cancel == .allowedWithWarning
    }
}
