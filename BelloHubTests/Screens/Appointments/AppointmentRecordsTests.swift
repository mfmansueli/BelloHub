//
//  AppointmentRecordsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AppointmentRecords")
struct AppointmentRecordsTests {
    private func make(_ appointment: Appointment, _ records: [TreatmentRecord]) -> AppointmentRecords {
        AppointmentRecords.make(
            appointmentID: appointment.id, startsAt: appointment.startsAt, records: records, now: TestClock.now,
            list: { $0.joined(separator: ", ") }
        )
    }

    @Test("The previous visit happened before the appointment; a later visit is never shown as the last one")
    func previousVisitIsEarlier() {
        let client = makeClient()
        let old = makeAppointment(clientID: client.id, daysFromNow: -20)
        let before = TreatmentRecord(clientID: client.id, serviceName: "Peel", createdAt: TestClock.days(-40),
                                     performedAt: TestClock.days(-40))
        let after = TreatmentRecord(clientID: client.id, serviceName: "Glow", createdAt: TestClock.days(-5),
                                    performedAt: TestClock.days(-5))
        #expect(make(old, [before, after]).previousVisit?.id == before.id)
    }

    @Test("The appointment's own record is its record, never its previous visit; drafts are not previous visits")
    func ownRecordAndDrafts() {
        let client = makeClient()
        let visit = makeAppointment(clientID: client.id, daysFromNow: -1)
        let own = TreatmentRecord(clientID: client.id, appointmentID: visit.id, serviceName: "Glow",
                                  createdAt: TestClock.days(-1))
        let draft = TreatmentRecord(clientID: client.id, serviceName: "Peel", createdAt: TestClock.days(-3),
                                    performedAt: TestClock.days(-3), status: .draft)
        let found = make(visit, [own, draft])
        #expect(found.record?.id == own.id)
        #expect(found.previousVisit == nil)
    }

    @Test("Remember today is the previous visit's note, trimmed, and nothing when it is blank")
    func rememberToday() {
        let client = makeClient()
        let visit = makeAppointment(clientID: client.id, daysFromNow: 0, status: .confirmed)
        var earlier = TreatmentRecord(clientID: client.id, serviceName: "Glow", createdAt: TestClock.days(-30),
                                      performedAt: TestClock.days(-30))
        earlier.nextVisitReminder = "  Lighter pressure near the eyes \n"
        #expect(make(visit, [earlier]).rememberToday == "Lighter pressure near the eyes")
        earlier.nextVisitReminder = "   "
        #expect(make(visit, [earlier]).rememberToday == nil)
    }
}
