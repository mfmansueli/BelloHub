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
    @Test("A web booking brings its guests, extras and timing into the iPhone agenda")
    func importsCompleteOffer() throws {
        var booking = makeIncomingBooking(status: .confirmed, minutes: 130)
        let serviceID = UUID()
        let addOnID = UUID()
        booking.serviceId = serviceID.uuidString.lowercased()
        booking.addOns = [.init(id: addOnID.uuidString.lowercased(), name: "Mask", minutes: 10)]
        booking.guestCount = 1
        booking.prepMinutes = 10
        booking.cleanupMinutes = 5
        booking.processingStartMinutes = 20
        booking.processingMinutes = 15
        let currentCatalog = makeService(id: serviceID, minutes: 90)
        let plan = BookingImporter.plan(
            bookings: [booking], appointments: [], clients: [], services: [currentCatalog], now: TestClock.now
        )
        let visit = try #require(plan.appointments.first)
        #expect(visit.numberOfGuests == 1 && visit.guests.isEmpty)
        #expect(visit.addOns == [AppointmentAddOn(addOnID: addOnID, name: "Mask", minutes: 10)])
        #expect(visit.serviceMinutes == 60)
        #expect(visit.serviceTiming == VisitTiming(prepMinutes: 10, cleanupMinutes: 5,
                                                   processingStartMinutes: 20, processingMinutes: 15))
    }

    @Test("A plain web booking remains plain after a catalog timing change")
    func plainBookingKeepsNoExtraTime() throws {
        let booking = makeIncomingBooking(status: .confirmed, minutes: 60)
        let visit = try mirror(booking)
        #expect(visit.serviceTiming == .noExtraTime)
        #expect(BookingImporter.apply(booking, to: visit, now: TestClock.now).serviceTiming == .noExtraTime)
    }

    @Test("A changed web offer updates one visit without erasing the professional's note")
    func updatesOfferInPlace() throws {
        var booking = makeIncomingBooking(status: .confirmed, minutes: 60)
        let original = try mirror(booking)
        var noted = original
        noted.privateNote = "Allergy discussed"
        booking.endsAt = booking.startsAt.addingTimeInterval(120 * 60)
        booking.durationMinutes = 120
        booking.guestCount = 1
        booking.prepMinutes = 10
        let plan = BookingImporter.plan(
            bookings: [booking], appointments: [noted], clients: [], services: [], now: TestClock.now
        )
        let updated = try #require(plan.appointments.first)
        #expect(updated.id == original.id && updated.privateNote == "Allergy discussed")
        #expect(updated.numberOfGuests == 1 && updated.serviceMinutes == 60)
        #expect(updated.serviceTiming?.prepMinutes == 10)
    }

    @Test("An old manual server document cannot erase locally recorded extras and guest names")
    func legacyManualOfferKeepsLocalDetails() {
        var booking = makeIncomingBooking(status: .confirmed, minutes: 130)
        booking.serviceId = "manual"
        let extra = AppointmentAddOn(addOnID: UUID(), name: "Mask", minutes: 10)
        let visit = Appointment(
            clientID: UUID(), serviceName: booking.serviceName, startsAt: booking.startsAt,
            endsAt: booking.endsAt, origin: .manual, bookingID: booking.id, addOns: [extra], guests: ["Bia"],
            serviceTiming: VisitTiming(prepMinutes: 10), serviceMinutes: 60, createdAt: booking.createdAt
        )
        let imported = BookingImporter.apply(booking, to: visit, now: TestClock.now)
        #expect(imported.addOns == [extra])
        #expect(imported.guests == ["Bia"] && imported.numberOfGuests == 1)
        #expect(imported.serviceMinutes == 60 && imported.serviceTiming?.prepMinutes == 10)
    }

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

    // MARK: - fix-booking-status

    private func mirror(_ booking: IncomingBooking) throws -> Appointment {
        let plan = BookingImporter.plan(
            bookings: [booking], appointments: [], clients: [], services: [], now: TestClock.now
        )
        return try #require(plan.appointments.first)
    }

    @Test("A server 'confirmed' never reopens a visit she closed, cancelled or marked as a no-show", arguments: [
        AppointmentStatus.completed, .cancelled, .noShow
    ])
    func herDecisionWins(local: AppointmentStatus) throws {
        let booking = makeIncomingBooking(id: "bk-1", status: .confirmed)
        var visit = try mirror(booking)
        visit.status = local

        let updated = BookingImporter.apply(booking, to: visit, now: TestClock.now)

        #expect(updated.status == local)
    }

    @Test("A server cancel by her keeps what she recorded; a cancel by the client replaces it")
    func cancelDetails() throws {
        let booking = makeIncomingBooking(id: "bk-1", status: .confirmed)
        var visit = try mirror(booking)
        visit.status = .cancelled
        visit.cancelledBy = .client
        visit.cancelledAt = TestClock.days(-1)
        var byPro = booking
        byPro.status = .cancelledByPro
        byPro.cancelledAt = TestClock.now
        var byClient = booking
        byClient.status = .cancelledByClient
        byClient.cancelledAt = TestClock.now
        byClient.isLateCancellation = true

        let kept = BookingImporter.apply(byPro, to: visit, now: TestClock.now)
        let replaced = BookingImporter.apply(byClient, to: visit, now: TestClock.now)

        #expect(kept.cancelledBy == .client && kept.cancelledAt == TestClock.days(-1))
        #expect(replaced.cancelledBy == .client && replaced.cancelledAt == TestClock.now && replaced.isLateCancellation)
    }

    @Test("A booking she changed here and the server has not taken yet is left alone")
    func heldLocally() throws {
        let booking = makeIncomingBooking(id: "bk-1", status: .confirmed)
        var visit = try mirror(booking)
        visit.startsAt = visit.startsAt.addingTimeInterval(86_400)
        visit.endsAt = visit.endsAt.addingTimeInterval(86_400)
        visit.status = .booked

        let plan = BookingImporter.plan(
            bookings: [booking], appointments: [visit], clients: [], services: [], now: TestClock.now,
            heldLocally: ["bk-1"]
        )

        #expect(plan.isEmpty)
    }

    @Test("A visit mirrored at the old time follows its moved booking, wherever the times are")
    func followsMovedBooking() throws {
        let booking = makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: 20)
        let visit = try mirror(booking)
        var moved = makeIncomingBooking(id: "bk-1", status: .cancelledByClient, daysAhead: 2)
        moved.createdAt = booking.createdAt

        let plan = BookingImporter.plan(
            bookings: [moved], appointments: [visit], clients: [], services: [], now: TestClock.now
        )

        let updated = try #require(plan.appointments.first)
        #expect(plan.appointments.count == 1)
        #expect(updated.id == visit.id && updated.status == .cancelled && updated.startsAt == moved.startsAt)
    }

    @Test("Two mirrors of one booking become one: the oldest stays, an untouched later copy leaves")
    func duplicates() throws {
        let booking = makeIncomingBooking(id: "bk-1", status: .confirmed)
        let first = try mirror(booking)
        let copy = makeCopy(of: first, minutesEarlier: 60, createdLater: 60)

        let plan = BookingImporter.plan(
            bookings: [booking], appointments: [copy, first], clients: [], services: [], now: TestClock.now
        )

        #expect(plan.removals == [copy.id])
        #expect(plan.appointments.isEmpty, "the first mirror already matches the server")
    }

    @Test("A copy with her note on it is never thrown away: it becomes the one that stays")
    func duplicateWithHerNote() throws {
        let booking = makeIncomingBooking(id: "bk-1", status: .confirmed)
        let first = try mirror(booking)
        var noted = makeCopy(of: first, minutesEarlier: 120, createdLater: 120)
        noted.privateNote = "Allergic to latex"

        let plan = BookingImporter.plan(
            bookings: [booking], appointments: [first, noted], clients: [], services: [], now: TestClock.now
        )

        #expect(plan.removals == [first.id])
        #expect(plan.appointments.map(\.id) == [noted.id])
        #expect(plan.appointments.first?.startsAt == booking.startsAt, "and it follows the server")
    }

    private func makeCopy(of visit: Appointment, minutesEarlier: Int, createdLater seconds: Int) -> Appointment {
        Appointment(
            clientID: visit.clientID, serviceName: visit.serviceName,
            startsAt: visit.startsAt.addingTimeInterval(TimeInterval(-minutesEarlier * 60)), endsAt: visit.endsAt,
            status: .confirmed, origin: .bookingLink, bookingID: visit.bookingID,
            createdAt: visit.createdAt.addingTimeInterval(TimeInterval(seconds))
        )
    }
}
