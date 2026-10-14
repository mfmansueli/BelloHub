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
/// - A booking the phone already mirrored (same `bookingID`, wherever the visit's time is) is updated in place: time,
///   status and the client's confirmation follow the server; what is hers alone (private note, session plan, reminder
///   sent, forgiven) stays. `existing` must hold every mirrored visit, not only those near the bookings' times: a
///   booking the client moved is no longer where its visit was (fix-booking-status).
/// - Her own decisions win over an older server state: a booking she changed on this phone and the server has not
///   taken yet (`heldLocally`) is left alone, and a server "confirmed" never reopens a visit she closed, cancelled or
///   marked as a no-show (the server never hears of a close, and hears of the others through the outbound queue).
/// - Two visits mirrored from one booking (an older build added one when the booking moved) become one: the first
///   mirror stays, a later copy with nothing of hers on it leaves the agenda.
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
        /// Duplicate mirrors to delete.
        var removals: [UUID] = []

        var isEmpty: Bool { newClients.isEmpty && appointments.isEmpty && removals.isEmpty }
    }

    static func plan(
        bookings: [IncomingBooking], appointments existing: [Appointment], clients: [Client], services: [Service],
        now: Date, heldLocally: Set<String> = []
    ) -> Plan {
        var plan = Plan()
        var byPhone: [String: UUID] = [:]
        for client in clients {
            if let phone = normalized(client.phoneE164), byPhone[phone] == nil { byPhone[phone] = client.id }
        }
        let mirrors = mirrors(in: existing)
        let serviceIDs = Set(services.map(\.id))
        let manual = existing.filter { $0.origin == .manual && $0.status.holdsTime }

        for booking in bookings.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard !booking.status.isRequest, booking.status != .declined, !heldLocally.contains(booking.id) else {
                continue
            }
            if let copies = mirrors[booking.id], let current = copies.first {
                let updated = apply(booking, to: current, now: now)
                if updated != current { plan.appointments.append(updated) }
                for copy in copies.dropFirst() {
                    if hasHerOwnData(copy) {
                        let follows = apply(booking, to: copy, now: now)
                        if follows != copy { plan.appointments.append(follows) }
                    } else {
                        plan.removals.append(copy.id)
                    }
                }
                continue
            }
            guard booking.status != .cancelledByClient, booking.status != .cancelledByPro else { continue }
            let clientID = clientID(for: booking, byPhone: &byPhone, plan: &plan)
            let visit = newVisit(for: booking, clientID: clientID, serviceIDs: serviceIDs)
            plan.appointments.append(apply(booking, to: visit, now: now))
        }

        plan.conflicts = conflicts(of: plan.appointments, with: manual)
        return plan
    }

    /// The visits mirrored from each booking, the one to keep first: the one with her own data on it, then the oldest.
    private static func mirrors(in existing: [Appointment]) -> [String: [Appointment]] {
        var byBooking: [String: [Appointment]] = [:]
        var seen: Set<UUID> = []
        for visit in existing where seen.insert(visit.id).inserted {
            // Earlier builds left manual visits unlinked; their server booking id is the visit UUID.
            let bookingID = visit.bookingID ?? (visit.origin == .manual ? visit.id.uuidString.lowercased() : nil)
            if let bookingID { byBooking[bookingID, default: []].append(visit) }
        }
        return byBooking.mapValues { copies in
            copies.sorted { lhs, rhs in
                let (left, right) = (hasHerOwnData(lhs), hasHerOwnData(rhs))
                if left != right { return left }
                return (lhs.createdAt, lhs.id.uuidString) < (rhs.createdAt, rhs.id.uuidString)
            }
        }
    }

    /// Something only she wrote on the visit, which a cleanup must never throw away.
    private static func hasHerOwnData(_ visit: Appointment) -> Bool {
        visit.privateNote != nil || visit.sessionPlanID != nil || visit.linkedAppointmentID != nil
            || !visit.status.holdsTime
    }

    /// Link visits that hold a time over a manual visit that holds the same time.
    static func conflicts(of visits: [Appointment], with manual: [Appointment]) -> [BookingConflict] {
        visits.flatMap { visit -> [BookingConflict] in
            guard visit.status.holdsTime, let bookingID = visit.bookingID else { return [] }
            return manual
                .filter { $0.id != visit.id && $0.interval.intersects(visit.interval) }
                .map { BookingConflict(bookingID: bookingID, appointmentID: $0.id) }
        }
    }

    private static func clientID(
        for booking: IncomingBooking, byPhone: inout [String: UUID], plan: inout Plan
    ) -> UUID {
        if let phone = normalized(booking.client.phone), let known = byPhone[phone] { return known }
        let client = Client(
            name: booking.client.name, phoneE164: normalized(booking.client.phone),
            email: booking.client.email, source: .bookingLink, createdAt: booking.createdAt
        )
        plan.newClients.append(client)
        if let phone = normalized(booking.client.phone) { byPhone[phone] = client.id }
        return client.id
    }

    private static func newVisit(for booking: IncomingBooking, clientID: UUID, serviceIDs: Set<UUID>) -> Appointment {
        Appointment(
            clientID: clientID,
            serviceID: booking.serviceUUID.flatMap { serviceIDs.contains($0) ? $0 : nil },
            serviceName: booking.serviceName,
            startsAt: booking.startsAt,
            endsAt: booking.endsAt,
            origin: .bookingLink,
            bookingID: booking.id,
            addOns: booking.addOns.compactMap { addOn in
                UUID(uuidString: addOn.id).map {
                    AppointmentAddOn(addOnID: $0, name: addOn.name, minutes: addOn.minutes)
                }
            },
            createdAt: booking.createdAt
        )
    }

    /// The server's view of the visit, over what the phone has.
    static func apply(_ booking: IncomingBooking, to appointment: Appointment, now: Date) -> Appointment {
        var visit = appointment
        if visit.bookingID == nil && visit.id.uuidString.lowercased() == booking.id {
            visit.bookingID = booking.id
            visit.manualBookingSyncIssue = nil
        }
        visit.startsAt = booking.startsAt
        visit.endsAt = booking.endsAt
        visit.totalMinutes = booking.totalMinutes
        visit.serviceName = booking.serviceName
        visit.clientConfirmedAt = booking.clientConfirmedAt
        visit.lateByMinutes = booking.lateByMinutes
        visit.rescheduleCount = booking.rescheduleCount
        switch booking.status {
        case .confirmed where appointment.status.holdsTime:
            visit.status = .confirmed
            visit.cancelledAt = nil
            visit.cancelledBy = nil
            visit.isLateCancellation = false
        case .confirmed:
            // She closed, cancelled or marked it here; the server's "confirmed" is older than her decision.
            break
        case .cancelledByPro where appointment.status == .cancelled:
            // Her own cancel, as the server took it. What she recorded (who asked, when) is more precise: the owner
            // call always says "professional", even when she wrote down that the client called to cancel.
            break
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
