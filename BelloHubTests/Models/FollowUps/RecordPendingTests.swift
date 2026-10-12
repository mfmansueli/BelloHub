//
//  RecordPendingTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecordPending")
struct RecordPendingTests {
    private let calendar = TestClock.calendar()

    private func make(
        appointments: [Appointment], records: [TreatmentRecord], clients: [Client]
    ) -> RecordPending {
        RecordPending.make(
            appointments: appointments, marks: records.map(RecordMark.init), clients: clients, now: TestClock.now,
            calendar: calendar
        )
    }

    @Test("A completed booking with nothing written is listed; one with a record is not")
    func unwrittenBookings() {
        let client = makeClient(name: "Ana Costa")
        let written = makeAppointment(clientID: client.id, daysFromNow: -2)
        let unwritten = makeAppointment(clientID: client.id, daysFromNow: -1)
        let record = TreatmentRecord(clientID: client.id, appointmentID: written.id, serviceName: "Glow",
                                     createdAt: TestClock.days(-2))
        let pending = make(appointments: [written, unwritten], records: [record], clients: [client])
        #expect(pending.items.map(\.appointmentID) == [unwritten.id])
        #expect(pending.items.first?.kind == .unwritten)
    }

    @Test("A draft replaces its booking's line, so one visit is never listed twice")
    func draftReplacesTheBooking() {
        let client = makeClient(name: "Ana Costa")
        let visit = makeAppointment(clientID: client.id, daysFromNow: -1)
        let draft = TreatmentRecord(clientID: client.id, appointmentID: visit.id, serviceName: "Glow",
                                    createdAt: TestClock.days(-1), status: .draft)
        let pending = make(appointments: [visit], records: [draft], clients: [client])
        #expect(pending.items.count == 1)
        #expect(pending.items.first?.kind == .draft)
        #expect(pending.items.first?.recordID == draft.id)
    }

    @Test("Cancelled, missed, future and old bookings are not records owed")
    func onlyRecentCompletedVisits() {
        let client = makeClient(name: "Ana Costa")
        let appointments = [
            makeAppointment(clientID: client.id, daysFromNow: -1, status: .cancelled),
            makeAppointment(clientID: client.id, daysFromNow: -1, status: .noShow),
            makeAppointment(clientID: client.id, daysFromNow: 1, status: .confirmed),
            makeAppointment(clientID: client.id, daysFromNow: -(RecordPending.unwrittenDays + 1))
        ]
        #expect(make(appointments: appointments, records: [], clients: [client]).isEmpty)
    }

    @Test("Archived and deleted clients leave the list; drafts of any age stay, newest first")
    func clientsAndOrder() {
        let ana = makeClient(name: "Ana Costa")
        let archived = makeClient(name: "Bia Lima", isArchived: true)
        let old = TreatmentRecord(clientID: ana.id, serviceName: "Peel", createdAt: TestClock.days(-60), status: .draft)
        let recent = TreatmentRecord(clientID: ana.id, serviceName: "Glow", createdAt: TestClock.days(-1),
                                     status: .draft)
        let hidden = TreatmentRecord(clientID: archived.id, serviceName: "Glow", createdAt: TestClock.days(-1),
                                     status: .draft)
        let orphan = TreatmentRecord(clientID: UUID(), serviceName: "Glow", createdAt: TestClock.days(-1),
                                     status: .draft)
        let pending = make(appointments: [], records: [old, recent, hidden, orphan], clients: [ana, archived])
        #expect(pending.items.map(\.recordID) == [recent.id, old.id])
        #expect(pending.draftCount == 2)
    }
}
