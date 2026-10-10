//
//  ClientServerDeletionPlanTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

/// Which `deleteClientServerData` calls forget a client (D30, API.md 6.7).
@Suite("ClientServerDeletionPlan")
struct ClientServerDeletionPlanTests {
    @Test("Phone and bookings travel in one call; duplicates and blanks are dropped")
    func oneCall() {
        let actions = ClientServerDeletionPlan.actions(phone: " +351912345678 ", bookingIDs: ["a", "b", "a", ""])
        #expect(actions == [.deleteClientServerData(phone: "+351912345678", bookingIds: ["a", "b"])])
    }

    @Test("More than 200 bookings are split; the phone goes with the first call only")
    func chunks() {
        let ids = (0..<450).map { "bk\($0)" }
        let actions = ClientServerDeletionPlan.actions(phone: "+34600000000", bookingIDs: ids)
        #expect(actions.count == 3)
        guard case .deleteClientServerData(let phone, let first) = actions[0],
              case .deleteClientServerData(let laterPhone, let last) = actions[2] else {
            Issue.record("unexpected kinds")
            return
        }
        #expect(phone == "+34600000000" && first.count == 200)
        #expect(laterPhone == nil && last.count == 50)
    }

    @Test("A phone alone, or nothing at all")
    func edges() {
        #expect(ClientServerDeletionPlan.actions(phone: "+5511900000000", bookingIDs: [])
            == [.deleteClientServerData(phone: "+5511900000000", bookingIds: [])])
        #expect(ClientServerDeletionPlan.actions(phone: "  ", bookingIDs: []).isEmpty)
        #expect(ClientServerDeletionPlan.actions(phone: nil, bookingIDs: []).isEmpty)
    }
}
