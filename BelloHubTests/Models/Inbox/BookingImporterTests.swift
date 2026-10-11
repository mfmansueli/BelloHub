//
//  BookingImporterTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// How a server booking becomes a visit (S12: the pure rule had no suite of its own; the sync service tests went
/// through it). Conflict detection is one of the v1 acceptance items (docs/13 section 8).
@Suite("BookingImporter")
struct BookingImporterTests {
    private func makeManualVisit(over booking: IncomingBooking, clientID: UUID = UUID()) -> Appointment {
        Appointment(
            clientID: clientID, serviceName: "Brow lamination", startsAt: booking.startsAt.addingTimeInterval(1_800),
            endsAt: booking.startsAt.addingTimeInterval(5_400), createdAt: TestClock.days(-2)
        )
    }

    @Test("A confirmed booking over a visit she booked by hand is a conflict, and both stay in the calendar")
    func conflictWithManualVisit() throws {
        let booking = makeIncomingBooking(id: "bk-1", status: .confirmed)
        let manual = makeManualVisit(over: booking)

        let plan = BookingImporter.plan(
            bookings: [booking], appointments: [manual], clients: [], services: [], now: TestClock.now
        )

        let visit = try #require(plan.appointments.first)
        #expect(visit.bookingID == "bk-1" && visit.status == .confirmed && visit.origin == .bookingLink)
        #expect(plan.conflicts == [BookingConflict(bookingID: "bk-1", appointmentID: manual.id)])
    }

    @Test("No conflict with a cancelled manual visit or a booking at another time")
    func noConflict() {
        let booking = makeIncomingBooking(id: "bk-1", status: .confirmed)
        var cancelled = makeManualVisit(over: booking)
        cancelled.status = .cancelled
        let later = makeIncomingBooking(id: "bk-2", status: .confirmed, daysAhead: 5)

        let plan = BookingImporter.plan(
            bookings: [booking, later], appointments: [cancelled], clients: [], services: [], now: TestClock.now
        )

        #expect(plan.conflicts.isEmpty)
        #expect(plan.appointments.count == 2)
    }

    @Test("Requests and declined bookings never enter the calendar; an unseen cancellation is not imported")
    func skipped() {
        let bookings = [
            makeIncomingBooking(id: "req", status: .pendingApproval),
            makeIncomingBooking(id: "dec", status: .declined),
            makeIncomingBooking(id: "gone", status: .cancelledByClient)
        ]
        let plan = BookingImporter.plan(
            bookings: bookings, appointments: [], clients: [], services: [], now: TestClock.now
        )
        #expect(plan.isEmpty)
    }

    @Test("A known phone reuses the client; a new phone becomes one link client, once")
    func clientsByPhone() {
        let known = Client(name: "Ana Costa", phoneE164: "+5511981234410", createdAt: TestClock.days(-90))
        let first = makeIncomingBooking(id: "a", status: .confirmed)
        let stranger = makeIncomingBooking(id: "b", status: .confirmed, daysAhead: 3, phone: "+5511900000001")
        let again = makeIncomingBooking(id: "c", status: .confirmed, daysAhead: 4, phone: "+5511900000001")

        let plan = BookingImporter.plan(
            bookings: [first, stranger, again], appointments: [], clients: [known], services: [], now: TestClock.now
        )

        #expect(plan.newClients.count == 1)
        #expect(plan.newClients.first?.source == .bookingLink)
        #expect(plan.appointments.first { $0.bookingID == "a" }?.clientID == known.id)
        let newID = plan.newClients.first?.id
        #expect(plan.appointments.filter { $0.clientID == newID }.count == 2)
    }

    @Test("A mirrored booking follows the server's time and status and keeps her private note")
    func updatesInPlace() throws {
        let booking = makeIncomingBooking(id: "bk-1", status: .confirmed)
        let first = BookingImporter.plan(
            bookings: [booking], appointments: [], clients: [], services: [], now: TestClock.now
        )
        var mirrored = try #require(first.appointments.first)
        mirrored.privateNote = "Prefers the window seat"
        var moved = booking
        moved.status = .cancelledByClient
        moved.isLateCancellation = true

        let plan = BookingImporter.plan(
            bookings: [moved], appointments: [mirrored], clients: first.newClients, services: [], now: TestClock.now
        )

        let visit = try #require(plan.appointments.first)
        #expect(visit.id == mirrored.id)
        #expect(visit.status == .cancelled && visit.cancelledBy == .client && visit.isLateCancellation)
        #expect(visit.privateNote == "Prefers the window seat")
        #expect(plan.conflicts.isEmpty, "a cancelled visit holds no time")
    }
}
