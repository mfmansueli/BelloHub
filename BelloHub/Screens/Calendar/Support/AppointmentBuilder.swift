//
//  AppointmentBuilder.swift
//  BelloHub
//

import Foundation

/// What the New appointment form collected, turned into the `Appointment` that is stored. The service name and the
/// add-ons are copied (a later edit of the service must not rewrite history), the total is the one `VisitDuration`
/// computes, and the end follows from it.
enum AppointmentBuilder {
    struct Choice: Sendable {
        var clientID: UUID
        var service: Service
        var visitType: VisitType
        var addOns: [AddOn]
        var guestNames: [String]
        var startsAt: Date
        /// The visit a reaction check looks at again.
        var linkedAppointmentID: UUID?
    }

    static func totalMinutes(_ choice: Choice) -> Int {
        VisitDuration.totalMinutes(
            serviceMinutes: choice.service.durationMinutes, addOnMinutes: choice.addOns.map(\.minutes),
            guests: choice.guestNames.count
        )
    }

    static func appointment(from choice: Choice, id: UUID = UUID(), now: Date) -> Appointment {
        let minutes = totalMinutes(choice)
        return Appointment(
            id: id, clientID: choice.clientID, serviceID: choice.service.id, serviceName: choice.service.name,
            startsAt: choice.startsAt, endsAt: choice.startsAt.addingTimeInterval(TimeInterval(minutes * 60)),
            totalMinutes: minutes, status: .booked, origin: .manual, visitType: choice.visitType,
            linkedAppointmentID: choice.visitType == .reactionCheck ? choice.linkedAppointmentID : nil,
            addOns: choice.addOns.map { AppointmentAddOn(addOnID: $0.id, name: $0.name, minutes: $0.minutes) },
            guests: choice.guestNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            createdAt: now
        )
    }

    /// The client's most recent visit that took place (or is booked) before `date`, which a reaction check points
    /// at. Cancelled visits do not count.
    static func visitToCheck(among appointments: [Appointment], before date: Date) -> Appointment? {
        appointments.filter { $0.status != .cancelled && $0.status != .noShow && $0.startsAt < date }
            .max { $0.startsAt < $1.startsAt }
    }
}
