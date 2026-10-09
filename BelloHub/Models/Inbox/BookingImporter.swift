//
//  BookingImporter.swift
//  BelloHub
//

import Foundation

/// The one owner of how a server booking becomes a visit in her agenda. Pure: it takes what the server says and what
/// the vault holds, and returns the writes to make. `BookingSyncService` applies them.
///
/// Rules:
/// - A request still waiting for her answer (`pendingApproval`) and a declined request never enter the calendar.
/// - A booking the phone already mirrored (same `bookingID`) is updated in place: time, status and the client's
///   confirmation follow the server; what is hers alone (private note, session plan, reminder sent, forgiven) stays.
/// - A booking never seen before enters the calendar when it holds a time or already happened; a cancellation the phone
///   never saw is not worth a cancelled visit.
/// - The client is matched by phone. A new phone becomes a new client with `source: .bookingLink`; the server already
///   counted her for the free registrations (D42), so saving her here only mirrors that count.
/// - A confirmed booking overlapping a visit she booked by hand is a `BookingConflict`; both stay.
enum BookingImporter {
    struct Plan: Equatable, Sendable {
        var newClients: [Client] = []
        var appointments: [Appointment] = []
        var conflicts: [BookingConflict] = []

        var isEmpty: Bool { newClients.isEmpty && appointments.isEmpty }
    }

    static func plan(
        bookings: [IncomingBooking], appointments existing: [Appointment], clients: [Client], services: [Service],
        now: Date
    ) -> Plan {
        var plan = Plan()
        var byPhone: [String: UUID] = [:]
        for client in clients {
            if let phone = normalized(client.phoneE164), byPhone[phone] == nil { byPhone[phone] = client.id }
        }
        let mirrored = Dictionary(existing.compactMap { visit in visit.bookingID.map { ($0, visit) } }) { first, _ in first }
        let serviceIDs = Set(services.map(\.id))
        let manual = existing.filter { $0.origin == .manual && $0.status.holdsTime }

        for booking in bookings.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard !booking.status.isRequest, booking.status != .declined else { continue }
            if let current = mirrored[booking.id] {
                let updated = apply(booking, to: current, now: now)
                if updated != current { plan.appointments.append(updated) }
                continue
            }
            guard booking.status != .cancelledByClient, booking.status != .cancelledByPro else { continue }
            let clientID: UUID
            if let phone = normalized(booking.client.phone), let known = byPhone[phone] {
                clientID = known
            } else {
                let client = Client(
                    name: booking.client.name, phoneE164: normalized(booking.client.phone),
                    email: booking.client.email, source: .bookingLink, createdAt: booking.createdAt
                )
                plan.newClients.append(client)
                if let phone = normalized(booking.client.phone) { byPhone[phone] = client.id }
                clientID = client.id
            }
            let visit = Appointment(
                clientID: clientID,
                serviceID: booking.serviceUUID.flatMap { serviceIDs.contains($0) ? $0 : nil },
                serviceName: booking.serviceName,
                startsAt: booking.startsAt,
                endsAt: booking.endsAt,
                origin: .bookingLink,
                bookingID: booking.id,
                addOns: booking.addOns.compactMap { addOn in
                    UUID(uuidString: addOn.id).map { AppointmentAddOn(addOnID: $0, name: addOn.name, minutes: addOn.minutes) }
                },
                createdAt: booking.createdAt
            )
            plan.appointments.append(apply(booking, to: visit, now: now))
        }

        for visit in plan.appointments where visit.status.holdsTime {
            for other in manual where other.interval.intersects(visit.interval) && other.id != visit.id {
                if let bookingID = visit.bookingID {
                    plan.conflicts.append(BookingConflict(bookingID: bookingID, appointmentID: other.id))
                }
            }
        }
        return plan
    }

    /// The server's view of the visit, over what the phone has.
    static func apply(_ booking: IncomingBooking, to appointment: Appointment, now: Date) -> Appointment {
        var visit = appointment
        visit.startsAt = booking.startsAt
        visit.endsAt = booking.endsAt
        visit.totalMinutes = booking.totalMinutes
        visit.serviceName = booking.serviceName
        visit.clientConfirmedAt = booking.clientConfirmedAt
        visit.lateByMinutes = booking.lateByMinutes
        visit.rescheduleCount = booking.rescheduleCount
        switch booking.status {
        case .confirmed:
            visit.status = .confirmed
            visit.cancelledAt = nil
            visit.cancelledBy = nil
            visit.isLateCancellation = false
        case .cancelledByClient, .cancelledByPro:
            visit.status = .cancelled
            visit.cancelledAt = booking.cancelledAt ?? now
            visit.cancelledBy = booking.status == .cancelledByClient ? .client : .professional
            visit.isLateCancellation = booking.status == .cancelledByClient && (booking.isLateCancellation ?? false)
        case .completed:
            visit.status = .completed
        case .noShow:
            visit.status = .noShow
        case .pendingApproval, .declined:
            break
        }
        if visit != appointment { visit.updatedAt = now }
        return visit
    }

    private static func normalized(_ phone: String?) -> String? {
        guard let phone = phone?.trimmingCharacters(in: .whitespaces), !phone.isEmpty else { return nil }
        return phone
    }
}
