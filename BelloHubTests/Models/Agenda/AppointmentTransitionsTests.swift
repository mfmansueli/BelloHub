//
//  AppointmentTransitionsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AppointmentTransitions")
struct AppointmentTransitionsTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeAppointment(startsIn hours: Double = 48, minutes: Int = 60) -> Appointment {
        let start = now.addingTimeInterval(hours * 3600)
        return Appointment(
            clientID: UUID(), serviceName: "Facial", startsAt: start,
            endsAt: start.addingTimeInterval(TimeInterval(minutes * 60)), totalMinutes: minutes, createdAt: now
        )
    }

    @Test("Rescheduling keeps the length, counts the move and forgets the old confirmation")
    func reschedule() {
        var original = makeAppointment()
        original.status = .confirmed
        original.clientConfirmedAt = now
        original.lateByMinutes = 10
        let newStart = now.addingTimeInterval(96 * 3600)
        let moved = AppointmentTransitions.rescheduled(original, to: newStart, now: now)
        #expect(moved.startsAt == newStart)
        #expect(moved.endsAt.timeIntervalSince(moved.startsAt) == 3600)
        #expect(moved.rescheduleCount == 1)
        #expect(moved.status == .booked)
        #expect(moved.clientConfirmedAt == nil)
        #expect(moved.lateByMinutes == nil)
    }

    @Test("A client cancelling inside the free window is late; outside it is not")
    func cancelByClient() {
        let policy = CancellationPolicy.standard
        let inside = AppointmentTransitions.cancelled(
            makeAppointment(startsIn: 2), by: .client, policy: policy, now: now
        )
        let outside = AppointmentTransitions.cancelled(
            makeAppointment(startsIn: 400), by: .client, policy: policy, now: now
        )
        #expect(inside.status == .cancelled && inside.isLateCancellation)
        #expect(outside.status == .cancelled && !outside.isLateCancellation)
        #expect(inside.cancelledBy == .client && inside.cancelledAt == now)
    }

    @Test("A cancellation by the professional is never late (D13)")
    func cancelByProfessional() {
        let result = AppointmentTransitions.cancelled(
            makeAppointment(startsIn: 1), by: .professional, policy: .standard, now: now
        )
        #expect(!result.isLateCancellation)
    }

    @Test("A no-show can be forgiven, completing and lateness change only their own fields")
    func otherTransitions() {
        let original = makeAppointment(startsIn: -3)
        #expect(AppointmentTransitions.noShow(original, forgive: true, now: now).noShowForgiven)
        #expect(AppointmentTransitions.noShow(original, forgive: false, now: now).status == .noShow)
        #expect(AppointmentTransitions.completed(original, now: now).status == .completed)
        #expect(AppointmentTransitions.late(original, byMinutes: -5, now: now).lateByMinutes == 0)
        #expect(AppointmentTransitions.late(original, byMinutes: 15, now: now).startsAt == original.startsAt)
    }
}
