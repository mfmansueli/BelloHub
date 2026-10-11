//
//  RemoteInboxRepositoryTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// How the app reads her bookings from the server and tells it about her own changes (fix-booking-status): every
/// booking reaches the phone however many there are, one unreadable document hides nothing, and the owner calls match
/// the server's own schema (a strict schema refuses an extra or a null field).
@Suite("RemoteInboxRepository")
struct RemoteInboxRepositoryTests {
    private func makeRow(
        id: String, startsAt: Date, status: String = "confirmed", extra: [String: Any] = [:]
    ) -> FakeFirestoreClient.Row {
        let endsAt = startsAt.addingTimeInterval(3_600)
        var object: [String: Any] = [
            "id": id, "status": status, "serviceId": "svc", "serviceName": "Brow lamination", "durationMinutes": 60,
            "startsAt": CallableJSON.instant(startsAt), "endsAt": CallableJSON.instant(endsAt),
            "timeZoneID": "America/Sao_Paulo", "client": ["name": "Ana Costa", "phone": "+5511981234410"],
            "rescheduleCount": 0, "createdAt": CallableJSON.instant(TestClock.days(-5)),
            "updatedAt": CallableJSON.instant(TestClock.now)
        ]
        object.merge(extra) { _, new in new }
        let json = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
        return FakeFirestoreClient.Row(id: id, startsAt: startsAt, json: json)
    }

    private struct Rig {
        let client = FakeCallableClient()
        let firestore = FakeFirestoreClient()
        var repository: RemoteInboxRepository { RemoteInboxRepository(client: client, firestore: firestore) }
    }

    @Test("More bookings than one page all arrive, each once, even when several share a start")
    func pages() async throws {
        let rig = Rig()
        let (repository, firestore) = (rig.repository, rig.firestore)
        let count = RemoteInboxRepository.pageLimit + 120
        let rows = (0..<count).map { index in
            // Pairs share a start (1-2, 3-4, ... 499-500), so the first page ends inside a pair.
            let start = TestClock.now.addingTimeInterval(Double((index + 1) / 2) * 1_800)
            return makeRow(id: String(format: "bk-%04d", index), startsAt: start)
        }
        firestore.set("bookings", rows: rows)

        let bookings = try await repository.bookings(uid: "u1", since: TestClock.days(-14))

        #expect(bookings.count == count)
        #expect(Set(bookings.map(\.id)).count == count)
        #expect(firestore.queries.count == 2)
    }

    @Test("One booking the app cannot read never hides the others, and a new server field or status is no failure")
    func toleratesUnknownShapes() async throws {
        let rig = Rig()
        let (repository, firestore) = (rig.repository, rig.firestore)
        firestore.set("bookings", rows: [
            makeRow(id: "broken", startsAt: TestClock.now, extra: ["startsAt": "not a date"]),
            makeRow(id: "cancelled", startsAt: TestClock.now, status: "cancelledByClient", extra: [
                "verification": "whatsapp", "reference": "K7Q2M", "lastClientAction": ["kind": "cancelled"],
                "somethingNew": ["nested": true]
            ]),
            makeRow(id: "future", startsAt: TestClock.now, status: "someStatusFromLater")
        ])

        let bookings = try await repository.bookings(uid: "u1", since: TestClock.days(-14))

        #expect(bookings.map(\.id) == ["cancelled", "future"])
        #expect(bookings.first?.status == .cancelledByClient)
        #expect(bookings.last?.status == .pendingApproval, "an unknown status never puts anything in the calendar")
    }

    @Test("One booking is read by id; a missing one is nil")
    func bookingByID() async throws {
        let rig = Rig()
        let (repository, firestore) = (rig.repository, rig.firestore)
        firestore.set("bookings", rows: [makeRow(id: "bk-1", startsAt: TestClock.now, status: "cancelledByPro")])

        let found = try await repository.booking(uid: "u1", id: "bk-1")
        let missing = try await repository.booking(uid: "u1", id: "bk-2")

        #expect(found?.status == .cancelledByPro)
        #expect(missing == nil)
    }

    @Test("Her cancel, move, no-show and forgive match the server's schemas")
    func ownerCallsMatchContract() async throws {
        let rig = Rig()
        let (repository, client) = (rig.repository, rig.client)
        client.answer("cancelBookingByOwner", with: #"{"status":"cancelled"}"#)
        client.answer(
            "moveBookingByOwner", with: #"{"startsAt":"2026-10-03T13:00:00.000Z","endsAt":"2026-10-03T14:00:00.000Z"}"#
        )
        client.answer("markNoShow", with: #"{"counted":1}"#)
        let mark = UUID()

        try await repository.cancelBookingByOwner(id: "bk-1")
        try await repository.moveBookingByOwner(id: "bk-1", startsAt: TestClock.now)
        try await repository.markNoShow(
            phone: "+5511981234410", markId: mark, markedAt: TestClock.now, bookingId: "bk-1"
        )
        try await repository.forgiveNoShow(phone: "+5511981234410", markId: mark)

        let calls = client.calls
        #expect(calls.map(\.function) == ["cancelBookingByOwner", "moveBookingByOwner", "markNoShow", "markNoShow"])
        for call in calls {
            #expect(try ServerContract.violations(of: call.body, for: call.function).isEmpty, "\(call.function)")
        }
        #expect(calls[2].object["action"] as? String == "mark")
        #expect(calls[2].object["bookingId"] as? String == "bk-1")
        #expect(calls[2].object["markId"] as? String == mark.uuidString.lowercased())
        #expect(calls[3].object["action"] as? String == "forgive")
        #expect(calls[3].object["bookingId"] == nil, "a missing field is left out, never sent as null")
    }

    @Test("A booking that no longer holds time is refused for good, so the queue drops the change")
    func refusedCancel() async {
        let rig = Rig()
        let (repository, client) = (rig.repository, rig.client)
        client.fail("cancelBookingByOwner", with: .unexpected(code: "BOOKING_NOT_ACTIVE"))

        await #expect(throws: BookingRepositoryError.rejected) {
            try await repository.cancelBookingByOwner(id: "bk-1")
        }
    }
}
