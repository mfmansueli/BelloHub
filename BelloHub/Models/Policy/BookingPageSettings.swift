//
//  BookingPageSettings.swift
//  BelloHub
//

import Foundation

/// Switches of the public booking page.
struct BookingPageSettings: Hashable, Codable, Sendable {
    var acceptingBookings: Bool
    /// When paused, the day the page opens again.
    var pausedUntil: Date?
    /// A new client's first booking waits for her approval.
    var confirmNewClients: Bool
    /// Guests a client can bring per booking: 0 to 2.
    var maxGuests: Int

    static let guestRange = 0...2

    static let standard = BookingPageSettings(
        acceptingBookings: true, pausedUntil: nil, confirmNewClients: false, maxGuests: 0
    )
}
