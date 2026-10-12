//
//  LinkVisitChangeTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Which of her changes to a link visit the server must hear about (fix-booking-status).
@Suite("LinkVisitChange")
struct LinkVisitChangeTests {
    private func makeVisit(bookingID: String? = "bk-1") -> Appointment {
        Appointment(
            clientID: UUID(), serviceName: "Glow", startsAt: TestClock.now,
            endsAt: TestClock.now.addingTimeInterval(3_600),
            status: .confirmed, origin: bookingID == nil ? .manual : .bookingLink, bookingID: bookingID,
            createdAt: TestClock.days(-2)
        )
    }

    @Test("Cancel, move, no-show and forgive are sent; a close, a note or a manual visit are not")
    func changes() {
        let visit = makeVisit()
        let later = TestClock.now.addingTimeInterval(86_400)
        let cancelled = AppointmentTransitions.cancelled(
            visit, by: .professional, policy: .standard, now: TestClock.now
        )
        let moved = AppointmentTransitions.rescheduled(visit, to: later, now: TestClock.now)
        let missed = AppointmentTransitions.noShow(visit, forgive: false, now: TestClock.now)
        let forgiven = AppointmentTransitions.noShow(missed, forgive: true, now: TestClock.now)
        let closed = AppointmentTransitions.completed(visit, now: TestClock.now)
        var noted = visit
        noted.privateNote = "Bring the patch test"
        let manual = makeVisit(bookingID: nil)

        #expect(LinkVisitChange.change(from: visit, to: cancelled) == .cancelled(bookingID: "bk-1"))
        #expect(LinkVisitChange.change(from: visit, to: moved) == .moved(bookingID: "bk-1", startsAt: later))
        #expect(LinkVisitChange.change(from: visit, to: missed) == .noShow(
            bookingID: "bk-1", clientID: visit.clientID, markID: visit.id, markedAt: TestClock.now, forgiven: false
        ))
        #expect(LinkVisitChange.change(from: missed, to: forgiven) == .noShowForgiven(
            bookingID: "bk-1", clientID: visit.clientID, markID: visit.id
        ))
        #expect(LinkVisitChange.change(from: visit, to: closed) == nil)
        #expect(LinkVisitChange.change(from: visit, to: noted) == nil)
        #expect(LinkVisitChange.change(
            from: manual,
            to: AppointmentTransitions.cancelled(manual, by: .client, policy: .standard, now: TestClock.now)
        ) == nil)
    }
}
