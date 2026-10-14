//
//  ManualBookingRegistration.swift
//  BelloHub
//

import Foundation

/// Data sent to the server to register an appointment added by hand (`registerManualBooking`).
struct ManualBookingRegistration: Equatable, Sendable, Encodable {
    struct AddOnPayload: Equatable, Sendable, Encodable {
        let id: String
        let name: String
        let minutes: Int
    }

    struct ClientPayload: Equatable, Sendable, Encodable {
        let name: String
        let phone: String
        var email: String?
        var locale: String?
    }

    let appointmentId: String
    let serviceName: String
    let serviceId: String?
    let serviceMinutes: Int?
    let addOns: [AddOnPayload]?
    let guestCount: Int?
    let timing: VisitTiming?
    let startsAt: Date
    let endsAt: Date
    let timeZoneID: String
    let client: ClientPayload

    init(appointment: Appointment, timeZoneID: String, client: ClientPayload) {
        appointmentId = appointment.id.uuidString.lowercased()
        serviceName = appointment.serviceName
        let guestTotal = appointment.numberOfGuests
        let remaining = appointment.totalMinutes - appointment.addOns.reduce(0) { $0 + $1.minutes }
        let inferredMinutes = remaining % (guestTotal + 1) == 0 ? remaining / (guestTotal + 1) : 0
        let minutes = appointment.serviceMinutes ?? inferredMinutes
        serviceMinutes = minutes >= 5 ? minutes : nil
        serviceId = serviceMinutes == nil ? nil : appointment.serviceID?.uuidString.lowercased()
        addOns = serviceMinutes == nil ? nil : appointment.addOns.map {
            AddOnPayload(id: $0.addOnID.uuidString.lowercased(), name: $0.name, minutes: $0.minutes)
        }
        guestCount = serviceMinutes == nil ? nil : guestTotal
        timing = serviceMinutes == nil ? nil : appointment.serviceTiming
        startsAt = appointment.startsAt
        endsAt = appointment.endsAt
        self.timeZoneID = timeZoneID
        self.client = client
    }
}
