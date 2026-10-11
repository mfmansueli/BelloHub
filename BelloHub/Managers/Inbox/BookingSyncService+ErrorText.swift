//
//  BookingSyncService+ErrorText.swift
//  BelloHub
//

import Foundation

/// What the inbox screens say when the server could not be read or written.
extension BookingSyncService {
    /// One sentence per failure, for the inbox's error state.
    static func text(for error: any Error) -> String {
        switch error as? BookingRepositoryError {
        case .unreachable:
            String(interface: LocalizedStringResource(
                "inbox.error.offline", defaultValue: "No connection. What you see is from the last sync."
            ))
        case .busy:
            String(interface: LocalizedStringResource(
                "inbox.error.busy", defaultValue: "The server is busy. Try again in a moment."
            ))
        case .unauthenticated:
            String(interface: LocalizedStringResource(
                "inbox.error.signIn", defaultValue: "Sign in again to see your bookings."
            ))
        default:
            String(interface: LocalizedStringResource(
                "inbox.error.generic", defaultValue: "Your bookings could not be read. Try again."
            ))
        }
    }
}
