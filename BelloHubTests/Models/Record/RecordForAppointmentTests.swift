//
//  RecordForAppointmentTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecordForAppointment")
struct RecordForAppointmentTests {
    private let client = UUID()
    private let appointment = UUID()

    private func makeRecord(appointmentID: UUID?, status: RecordStatus = .finalized,
                            minutesAgo: Double = 0) -> TreatmentRecord {
        TreatmentRecord(clientID: client, appointmentID: appointmentID, serviceName: "Glow",
                        createdAt: TestClock.now.addingTimeInterval(-minutesAgo * 60), status: status)
    }

    @Test("Reopening an appointment finds its record instead of starting another")
    func findsExisting() {
        let record = makeRecord(appointmentID: appointment)
        let other = makeRecord(appointmentID: UUID())

        #expect(RecordForAppointment.existing(in: [other, record], appointmentID: appointment) == record)
    }

    @Test("A finalized record wins over a stray draft for the same appointment")
    func prefersFinalized() {
        let finalized = makeRecord(appointmentID: appointment, minutesAgo: 60)
        let draft = makeRecord(appointmentID: appointment, status: .draft)

        #expect(RecordForAppointment.existing(in: [draft, finalized], appointmentID: appointment) == finalized)
    }

    @Test("No appointment, or none recorded, finds nothing; same-day records are never matched by date")
    func nothing() {
        let walkIn = makeRecord(appointmentID: nil)

        #expect(RecordForAppointment.existing(in: [walkIn], appointmentID: nil) == nil)
        #expect(RecordForAppointment.existing(in: [walkIn], appointmentID: appointment) == nil)
        #expect(RecordForAppointment.recordedAppointmentIDs([walkIn, makeRecord(appointmentID: appointment)])
                == [appointment])
    }
}
