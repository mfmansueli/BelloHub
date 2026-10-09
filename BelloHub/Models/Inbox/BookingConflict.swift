//
//  BookingConflict.swift
//  BelloHub
//

import Foundation

/// A booking confirmed through the link whose time overlaps a visit she booked by hand (the page published the busy
/// times, but a manual visit can be added between two syncs). Both stay in the calendar; the inbox points it out so
/// she can move one.
struct BookingConflict: Identifiable, Hashable, Codable, Sendable {
    let bookingID: String
    let appointmentID: UUID

    var id: String { "\(bookingID)/\(appointmentID.uuidString)" }
}
