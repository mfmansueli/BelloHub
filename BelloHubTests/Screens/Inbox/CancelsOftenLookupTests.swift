//
//  CancelsOftenLookupTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The "Cancels often" chip on the waitlist and booking request (docs/05: ≥ 30 % cancellations by the client and
/// no-shows among the last ten past appointments, only from four completed visits), matched by phone.
@Suite("CancelsOftenLookup")
struct CancelsOftenLookupTests {
    private func client(_ name: String, phone: String?) -> Client {
        var client = makeClient(name: name)
        client.phoneE164 = phone
        return client
    }

    /// `completed` visits plus `cancelled` cancellations by the client, all in the past.
    private func visits(for id: UUID, completed: Int, cancelled: Int) -> [Appointment] {
        (0..<completed).map { makeAppointment(clientID: id, daysFromNow: -10 - $0 * 14) }
            + (0..<cancelled).map {
                makeAppointment(clientID: id, daysFromNow: -5 - $0 * 14, status: .cancelled, cancelledBy: .client)
            }
    }

    @Test("Four visits and two cancellations by the client (33 %) cancel often; one (20 %) does not")
    func threshold() {
        let often = client("Ana Costa", phone: "+5511981234410")
        let rarely = client("Bea Lima", phone: "+5511900000001")
        let appointments = visits(for: often.id, completed: 4, cancelled: 2)
            + visits(for: rarely.id, completed: 4, cancelled: 1)

        let phones = CancelsOftenLookup.phones(
            clients: [often, rarely], appointments: appointments, now: TestClock.now, calendar: TestClock.calendar()
        )

        #expect(phones == ["+5511981234410"])
        #expect(CancelsOftenLookup.cancelsOften(phone: " +55 11 98123 4410", in: phones))
        #expect(!CancelsOftenLookup.cancelsOften(phone: "+5511900000001", in: phones))
        #expect(!CancelsOftenLookup.cancelsOften(phone: nil, in: phones))
    }

    @Test("Under four completed visits the rate is not shown, so no chip; a cancellation by her does not count")
    func notEnoughVisits() {
        let new = client("Carla Souza", phone: "+5511900000002")
        let professionalCancels = client("Dani Alves", phone: "+5511900000003")
        let appointments = visits(for: new.id, completed: 3, cancelled: 3)
            + visits(for: professionalCancels.id, completed: 4, cancelled: 0)
            + (0..<3).map {
                makeAppointment(
                    clientID: professionalCancels.id, daysFromNow: -3 - $0, status: .cancelled,
                    cancelledBy: .professional
                )
            }

        let phones = CancelsOftenLookup.phones(
            clients: [new, professionalCancels], appointments: appointments, now: TestClock.now,
            calendar: TestClock.calendar()
        )

        #expect(phones.isEmpty)
    }

    @Test("Archived clients and clients without a phone are left out")
    func leftOut() {
        var archived = client("Eva Rocha", phone: "+5511900000004")
        archived.isArchived = true
        let noPhone = client("Fê Nunes", phone: nil)
        let appointments = visits(for: archived.id, completed: 4, cancelled: 4)
            + visits(for: noPhone.id, completed: 4, cancelled: 4)

        #expect(CancelsOftenLookup.phones(
            clients: [archived, noPhone], appointments: appointments, now: TestClock.now, calendar: TestClock.calendar()
        ).isEmpty)
    }
}
