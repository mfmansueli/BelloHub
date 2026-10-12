//
//  LinkVisitChange.swift
//  BelloHub
//

import Foundation

/// A change she made in the app to a visit that came from her link. The server holds the booking (API.md section 8),
/// so each of these must reach it too (`cancelBookingByOwner`, `moveBookingByOwner`, `markNoShow`); otherwise the
/// client's manage page and the next sync still say "confirmed" (docs/agent-notes/fix-booking-status.md).
/// Closing a visit has no server call: the server keeps a past booking as confirmed and the importer never lets that
/// undo her close.
enum LinkVisitChange: Equatable, Sendable {
    case cancelled(bookingID: String)
    case moved(bookingID: String, startsAt: Date)
    /// `markID` is the visit's id, so a replay is the same mark (the server's marks are idempotent by id).
    case noShow(bookingID: String, clientID: UUID, markID: UUID, markedAt: Date, forgiven: Bool)
    case noShowForgiven(bookingID: String, clientID: UUID, markID: UUID)

    var bookingID: String {
        switch self {
        case .cancelled(let id), .moved(let id, _), .noShow(let id, _, _, _, _), .noShowForgiven(let id, _, _): id
        }
    }

    /// What the server must hear after a visit changed from `before` to `after`; nil for a visit made by hand or a
    /// change the server does not keep (a close, a note, a reminder).
    static func change(from before: Appointment, to after: Appointment) -> LinkVisitChange? {
        guard let bookingID = after.bookingID else { return nil }
        if after.status == .cancelled, before.status != .cancelled { return .cancelled(bookingID: bookingID) }
        if after.status == .noShow, before.status != .noShow {
            return .noShow(
                bookingID: bookingID, clientID: after.clientID, markID: after.id, markedAt: after.updatedAt,
                forgiven: after.noShowForgiven
            )
        }
        if after.status == .noShow, after.noShowForgiven, !before.noShowForgiven {
            return .noShowForgiven(bookingID: bookingID, clientID: after.clientID, markID: after.id)
        }
        if after.status.holdsTime, after.startsAt != before.startsAt {
            return .moved(bookingID: bookingID, startsAt: after.startsAt)
        }
        return nil
    }
}
