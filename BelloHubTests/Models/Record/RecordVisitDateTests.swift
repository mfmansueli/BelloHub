//
//  RecordVisitDateTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecordVisitDate")
struct RecordVisitDateTests {
    private let created = TestClock.date("2026-09-30 17:42")
    private let visit = TestClock.date("2026-09-27 10:00")

    @Test("The visit day she set wins, even when the record was written days later")
    func recordedWins() {
        let appointmentID = UUID()
        let record = TreatmentRecord(clientID: UUID(), appointmentID: appointmentID, serviceName: "Glow",
                                     createdAt: created, performedAt: visit)
        let resolved = RecordVisitDate.resolve(record, appointmentStart: created)

        #expect(resolved == RecordVisitDate(date: visit, source: .recorded))
        #expect(resolved.isVisitDay)
    }

    @Test("An old record made for an appointment takes the appointment's start")
    func appointmentFallback() {
        let client = UUID()
        let appointment = makeAppointment(clientID: client, daysFromNow: -3)
        let record = TreatmentRecord(clientID: client, appointmentID: appointment.id, serviceName: "Glow",
                                     createdAt: created)
        let resolved = RecordVisitDate.resolve(record, appointments: [appointment.id: appointment])

        #expect(resolved == RecordVisitDate(date: appointment.startsAt, source: .appointment))
    }

    @Test("An old record with no appointment says only when it was written, never an invented day")
    func writtenOnly() {
        let record = TreatmentRecord(clientID: UUID(), serviceName: "Glow", createdAt: created)
        let resolved = RecordVisitDate.resolve(record, appointments: [:])

        #expect(resolved == RecordVisitDate(date: created, source: .writtenOnly))
        #expect(!resolved.isVisitDay)
    }

    @Test("A record whose appointment was deleted falls back to when it was written")
    func missingAppointment() {
        let record = TreatmentRecord(clientID: UUID(), appointmentID: UUID(), serviceName: "Glow",
                                     createdAt: created)

        #expect(RecordVisitDate.resolve(record, appointments: [:]).source == .writtenOnly)
    }
}
