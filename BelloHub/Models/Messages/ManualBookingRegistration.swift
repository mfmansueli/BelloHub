//
//  ManualBookingRegistration.swift
//  BelloHub
//

import Foundation

/// Data sent to the server to register an appointment added by hand (`registerManualBooking`).
struct ManualBookingRegistration: Equatable, Sendable, Encodable {
    struct ClientPayload: Equatable, Sendable, Encodable {
        let name: String
        let phone: String
        var email: String?
        var locale: String?
    }

    let appointmentId: String
    let serviceName: String
    let startsAt: Date
    let endsAt: Date
    let timeZoneID: String
    let client: ClientPayload
}
