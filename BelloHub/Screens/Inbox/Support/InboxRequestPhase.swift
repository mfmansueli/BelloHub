//
//  InboxRequestPhase.swift
//  BelloHub
//

import Foundation

/// Where a request she answers stands on screen (2.10 BookingRequest, 2.11 RescheduleRequest). Pure and the one owner
/// of the order of the checks: an answer on its way wins over the server's status, and a known outcome wins over
/// "still open".
enum InboxRequestPhase: Equatable, Sendable {
    /// The first sync has not finished and the request is not known yet.
    case loading
    /// The server no longer has it (answered elsewhere, or purged).
    case missing
    /// Waiting for her answer.
    case open
    /// She answered; the server has not confirmed yet (it may be waiting for the network).
    case sending
    /// Approving needs a plan first (D42).
    case needsPlan
    /// The time the client asked for was taken before she accepted (2.11).
    case slotTaken
    case accepted
    case declined
    /// The client cancelled the request.
    case withdrawn

    /// Whether the answer buttons show.
    var canAnswer: Bool { self == .open || self == .needsPlan || self == .slotTaken }

    static func booking(
        _ booking: IncomingBooking?, isLoading: Bool, isSending: Bool, needsPlan: Bool
    ) -> InboxRequestPhase {
        guard let booking else { return isLoading ? .loading : .missing }
        if isSending { return .sending }
        switch booking.status {
        case .pendingApproval: return needsPlan ? .needsPlan : .open
        case .confirmed, .completed, .noShow: return .accepted
        case .declined: return .declined
        case .cancelledByClient, .cancelledByPro: return .withdrawn
        }
    }

    static func reschedule(
        _ request: RescheduleRequest?, isLoading: Bool, isSending: Bool, slotTaken: Bool
    ) -> InboxRequestPhase {
        guard let request else { return isLoading ? .loading : .missing }
        if isSending { return .sending }
        switch request.status {
        case .pending: return slotTaken ? .slotTaken : .open
        case .accepted: return .accepted
        case .declined: return .declined
        case .cancelled: return .withdrawn
        }
    }
}
