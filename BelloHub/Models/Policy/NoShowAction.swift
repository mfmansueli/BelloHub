//
//  NoShowAction.swift
//  BelloHub
//

/// What happens when a client reaches the limit (D13).
enum NoShowAction: String, PersistedEnum {
    /// Only tell the professional.
    case tell
    /// New bookings from this client wait for her approval.
    case approveNewBookings
    /// Online booking is paused for this client.
    case pauseOnline

    static let fallback = NoShowAction.tell
}
