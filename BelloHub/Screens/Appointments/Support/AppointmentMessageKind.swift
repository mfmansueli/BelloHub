//
//  AppointmentMessageKind.swift
//  BelloHub
//

import Foundation

/// The message a screen of the agenda is about to open in a chat. The three first ones have their own wording (there
/// is no built-in quick reply for them); `quickReply` is one of hers, as she wrote it.
enum AppointmentMessageKind: Equatable, Sendable {
    /// She cancelled the visit: apologise and offer a new time.
    case cancelled
    /// The client did not come: a friendly note, never a reproach.
    case noShow
    /// She is running late by this many minutes.
    case runningLate(minutes: Int)
    case quickReply(QuickReply)

    /// What the message log keeps: the kind, never the text.
    var logTemplate: String {
        switch self {
        case .cancelled: "appointmentCancelled"
        case .noShow: "noShowNote"
        case .runningLate: "runningLate"
        case .quickReply(let reply): reply.builtInKey ?? "quickReply"
        }
    }
}
