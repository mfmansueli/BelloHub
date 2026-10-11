//
//  ClientLinkPlan.swift
//  BelloHub
//

import Foundation

/// Decides, before any call, whether a message about a visit can carry the client's own manage link: only a visit
/// that came from the booking page (it has the server's `bookingID`), still holds its time and has not ended.
/// Everything else carries her booking page. Pure: `now` is a parameter. `ClientLinkService` asks the server only
/// when this says so.
enum ClientLinkPlan {
    enum Request: Equatable, Sendable {
        case manageLink(bookingID: String)
        case bookingPage(ClientLinkChoice.Reason)
    }

    /// A minted link is reused for this long (the server returns the same one for 30 minutes anyway).
    static let reuseInterval: TimeInterval = 25 * 60

    static func request(for appointment: Appointment, now: Date) -> Request {
        guard let bookingID = appointment.bookingID, !bookingID.isEmpty else { return .bookingPage(.addedByHand) }
        guard appointment.status.holdsTime, appointment.endsAt > now else { return .bookingPage(.notActive) }
        return .manageLink(bookingID: bookingID)
    }

    /// Whether a link fetched at `fetchedAt` can still go into a message now.
    static func canReuse(_ link: ClientManageLink, fetchedAt: Date, now: Date) -> Bool {
        now >= fetchedAt && now.timeIntervalSince(fetchedAt) < reuseInterval && link.expiresAt > now
    }
}
