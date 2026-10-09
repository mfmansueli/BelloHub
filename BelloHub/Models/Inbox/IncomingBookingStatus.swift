//
//  IncomingBookingStatus.swift
//  BelloHub
//

/// Where a booking made through the link stands on the server (`BookingDoc.status`,
/// firebase/functions/src/lib/docs.ts).
/// The server is the source of truth for it; the app only reads it and mirrors it into the agenda.
enum IncomingBookingStatus: String, PersistedEnum {
    case confirmed
    case pendingApproval
    case cancelledByClient
    case cancelledByPro
    case declined
    case completed
    case noShow

    /// A status the app does not know yet is treated as "waiting": nothing is put in the calendar by mistake.
    static let fallback = IncomingBookingStatus.pendingApproval

    /// Holds a time in her calendar.
    var holdsTime: Bool { self == .confirmed }

    /// Waits for her answer (2.10).
    var isRequest: Bool { self == .pendingApproval }
}
