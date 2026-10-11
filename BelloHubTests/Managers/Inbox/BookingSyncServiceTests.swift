//
//  BookingSyncServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The round trip of a link booking's state between the server, the client's manage page and her agenda
/// (docs/agent-notes/fix-booking-status.md). Direction A: the client changes the booking on the web and the next sync
/// must show it, whatever the visit's old time. Direction B: she changes the visit in the app and the server must
/// follow, without a stale server read undoing her change in between.
@MainActor
@Suite("BookingSyncService")
struct BookingSyncServiceTests {
    private static let farAhead = 20
    private static let soon = 2

    private func moved(_ booking: IncomingBooking, toDaysAhead days: Int) -> IncomingBooking {
        var moved = booking
        let target = makeIncomingBooking(id: booking.id, status: booking.status, daysAhead: days)
        moved.startsAt = target.startsAt
        moved.endsAt = target.endsAt
        moved.rescheduleCount += 1
        moved.updatedAt = TestClock.now
        return moved
    }

    private func cancelledByClient(_ booking: IncomingBooking) -> IncomingBooking {
        var cancelled = booking
        cancelled.status = .cancelledByClient
        cancelled.cancelledAt = TestClock.now
        cancelled.cancelledBy = "client"
        cancelled.isLateCancellation = false
        cancelled.updatedAt = TestClock.now
        return cancelled
    }

    private func start(with bookings: [IncomingBooking]) async -> InboxRig {
        let rig = InboxRig(repository: FakeInboxRepository(bookings: bookings))
        await rig.start()
        return rig
    }

    // MARK: - Direction A: the client changes the booking on the web

    @Test("A booking moved on the web and then cancelled cancels the visit mirrored at the old time", arguments: [
        (farAhead, soon), (soon, farAhead)
    ])
    func movedThenCancelled(from: Int, to: Int) async throws {
        let original = makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: from)
        let rig = await start(with: [original])
        defer { rig.cleanUp() }
        #expect(await rig.visits(bookingID: "bk-1").map(\.status) == [.confirmed])

        await rig.repository.replace(cancelledByClient(moved(original, toDaysAhead: to)))
        await rig.sync.syncAsync()

        let visits = await rig.visits(bookingID: "bk-1")
        #expect(visits.count == 1, "one visit per booking")
        #expect(visits.allSatisfy { $0.status == .cancelled }, "nothing of a cancelled booking still holds time")
        #expect(visits.first?.cancelledBy == .client)
    }

    @Test("A booking moved on the web moves its visit, never adds a second one", arguments: [
        (farAhead, soon), (soon, farAhead)
    ])
    func movedOnTheWeb(from: Int, to: Int) async throws {
        let original = makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: from)
        let rig = await start(with: [original])
        defer { rig.cleanUp() }
        let target = moved(original, toDaysAhead: to)

        await rig.repository.replace(target)
        await rig.sync.syncAsync()

        let visits = await rig.visits(bookingID: "bk-1")
        #expect(visits.count == 1)
        #expect(visits.first?.startsAt == target.startsAt)
        #expect(visits.first?.status == .confirmed)
    }

    @Test("A stale visit at the old time and a duplicate from an older build are repaired by the next sync")
    func repairsStaleVisits() async throws {
        let original = makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: Self.farAhead)
        let server = cancelledByClient(moved(original, toDaysAhead: Self.soon))
        let rig = InboxRig(repository: FakeInboxRepository(bookings: [server]))
        defer { rig.cleanUp() }
        let clientID = UUID()
        let stale = Appointment(
            clientID: clientID, serviceName: original.serviceName, startsAt: original.startsAt,
            endsAt: original.endsAt, status: .confirmed, origin: .bookingLink, bookingID: "bk-1",
            createdAt: TestClock.days(-3)
        )
        let duplicate = Appointment(
            clientID: clientID, serviceName: original.serviceName, startsAt: server.startsAt, endsAt: server.endsAt,
            status: .confirmed, origin: .bookingLink, bookingID: "bk-1", createdAt: TestClock.days(-1)
        )
        try await rig.vault.repository?.save(stale)
        try await rig.vault.repository?.save(duplicate)

        await rig.start()

        let visits = await rig.visits(bookingID: "bk-1")
        #expect(visits.count == 1, "the untouched duplicate leaves the agenda")
        #expect(visits.first?.id == stale.id, "the first mirror keeps her history")
        #expect(visits.first?.status == .cancelled)
    }

    @Test("Presence confirmed and lateness reported on the web reach the visit")
    func clientSignals() async throws {
        let original = makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: Self.soon)
        let rig = await start(with: [original])
        defer { rig.cleanUp() }
        var changed = original
        changed.clientConfirmedAt = TestClock.now
        changed.lateByMinutes = 10
        changed.updatedAt = TestClock.now

        await rig.repository.replace(changed)
        await rig.sync.syncAsync()

        let visit = try #require(await rig.visits(bookingID: "bk-1").first)
        #expect(visit.clientConfirmedAt == TestClock.now)
        #expect(visit.lateByMinutes == 10)
    }

    // MARK: - Direction B: she changes the visit in the app

    @Test("Cancelling a link visit in the app cancels the booking on the server, and a sync keeps it cancelled")
    func ownerCancelReachesServer() async throws {
        let rig = await start(with: [makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: Self.soon)])
        defer { rig.cleanUp() }
        let visit = try #require(await rig.visits(bookingID: "bk-1").first)

        try await rig.appointments.cancel(id: visit.id, by: .professional, policy: .standard, now: TestClock.now)
        let sent = await Wait.until(timeout: .seconds(5)) {
            await rig.repository.writes.contains("cancelBookingByOwner:bk-1")
        }
        await rig.sync.syncAsync()

        #expect(sent, "the server is told")
        #expect(await rig.repository.bookings.first?.status == .cancelledByPro)
        let after = try #require(await rig.visits(bookingID: "bk-1").first)
        #expect(after.status == .cancelled)
        #expect(after.cancelledBy == .professional)
    }

    @Test("A cancel still waiting for the network is not undone by a stale server read")
    func pendingCancelSurvivesStaleRead() async throws {
        let rig = await start(with: [makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: Self.soon)])
        defer { rig.cleanUp() }
        let visit = try #require(await rig.visits(bookingID: "bk-1").first)
        await rig.repository.setWriteFailure(.unreachable)

        try await rig.appointments.cancel(id: visit.id, by: .client, policy: .standard, now: TestClock.now)
        let queued = await Wait.untilMain(timeout: .seconds(5)) { rig.queue.pending.count == 1 }
        await rig.sync.syncAsync()

        #expect(queued, "the cancel waits in the queue")
        let after = try #require(await rig.visits(bookingID: "bk-1").first)
        #expect(after.status == .cancelled, "the server still says confirmed, but her cancel is newer")
        #expect(after.cancelledBy == .client)

        await rig.repository.setWriteFailure(nil)
        await rig.queue.flushAsync()
        await rig.sync.syncAsync()

        #expect(await rig.repository.bookings.first?.status == .cancelledByPro)
        let settled = try #require(await rig.visits(bookingID: "bk-1").first)
        #expect(settled.status == .cancelled)
        #expect(settled.cancelledBy == .client, "what she recorded (the client called) stays")
    }

    @Test("Moving a link visit in the app moves the booking on the server, and a sync keeps the new time")
    func ownerMoveReachesServer() async throws {
        let rig = await start(with: [makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: Self.soon)])
        defer { rig.cleanUp() }
        let visit = try #require(await rig.visits(bookingID: "bk-1").first)
        let newStart = visit.startsAt.addingTimeInterval(3 * 86_400)
        await rig.repository.setWriteFailure(.unreachable)

        try await rig.appointments.reschedule(id: visit.id, to: newStart, now: TestClock.now)
        await Wait.untilMain(timeout: .seconds(5)) { rig.queue.pending.count == 1 }
        await rig.sync.syncAsync()
        #expect(await rig.visits(bookingID: "bk-1").map(\.startsAt) == [newStart], "a stale read keeps her time")

        await rig.repository.setWriteFailure(nil)
        await rig.queue.flushAsync()
        await rig.sync.syncAsync()

        #expect(await rig.repository.writes.contains("moveBookingByOwner:bk-1:\(CallableJSON.instant(newStart))"))
        #expect(await rig.repository.bookings.first?.startsAt == newStart)
        #expect(await rig.visits(bookingID: "bk-1").map(\.startsAt) == [newStart])
    }

    @Test("A no-show on a link visit is marked on the server with the booking")
    func ownerNoShowReachesServer() async throws {
        let rig = await start(with: [makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: -1)])
        defer { rig.cleanUp() }
        let visit = try #require(await rig.visits(bookingID: "bk-1").first)

        try await rig.appointments.markNoShow(id: visit.id, forgive: false, now: TestClock.now)
        let sent = await Wait.until(timeout: .seconds(5)) {
            await rig.repository.writes.contains("markNoShow:mark:+5511981234410:bk-1")
        }
        await rig.sync.syncAsync()

        #expect(sent)
        #expect(await rig.repository.bookings.first?.status == .noShow)
        #expect(await rig.visits(bookingID: "bk-1").map(\.status) == [.noShow])
    }

    @Test("A link visit she closed stays completed after a sync (the server keeps it confirmed)")
    func completedStaysCompleted() async throws {
        let rig = await start(with: [makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: -1)])
        defer { rig.cleanUp() }
        let visit = try #require(await rig.visits(bookingID: "bk-1").first)

        try await rig.appointments.complete(id: visit.id, now: TestClock.now)
        await rig.sync.syncAsync()

        #expect(await rig.visits(bookingID: "bk-1").map(\.status) == [.completed])
    }
}
