//
//  ClientTimelineBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientTimelineBuilder")
struct ClientTimelineBuilderTests {
    private let client = UUID()

    private func build(_ input: ClientTimelineBuilder.Input) -> ClientTimeline {
        ClientTimelineBuilder.make(input, now: TestClock.now, list: { $0.joined(separator: ", ") })
    }

    @Test("A visit carries only the photos and incidents linked to its record, never ones from the same day")
    func linksOnly() {
        let record = makeRecord(clientID: client, createdAt: TestClock.days(-3))
        let other = makeRecord(clientID: client, createdAt: TestClock.days(-3))
        let mine = makePhoto(clientID: client, recordID: record.id, takenAt: TestClock.days(-3))
        let sameDay = makePhoto(clientID: client, recordID: other.id, takenAt: TestClock.days(-3))
        let loose = makePhoto(clientID: client, recordID: nil, takenAt: TestClock.days(-3))
        var incident = makeIncident(clientID: client, occurredAt: TestClock.days(-3))
        incident.recordID = record.id

        let timeline = build(.init(records: [record, other], photos: [mine, sameDay, loose], incidents: [incident]))
        let visit = timeline.visits.first { $0.id == record.id }

        #expect(visit?.photos.map(\.id) == [mine.id])
        #expect(visit?.incidents.map(\.id) == [incident.id])
        #expect(timeline.unlinkedPhotos.map(\.id) == [loose.id])
    }

    @Test("A photo whose record no longer exists is kept as unlinked, not lost")
    func danglingPhoto() {
        let photo = makePhoto(clientID: client, recordID: UUID())
        #expect(build(.init(photos: [photo])).unlinkedPhotos.map(\.id) == [photo.id])
    }

    @Test("A completed booking with no record is pending; with a record it is the visit itself")
    func pendingRecord() {
        let done = makeAppointment(clientID: client, daysFromNow: -2)
        let recorded = makeAppointment(clientID: client, daysFromNow: -5)
        let record = makeRecord(clientID: client, appointmentID: recorded.id, createdAt: TestClock.days(-4))

        let timeline = build(.init(records: [record], appointments: [done, recorded]))

        #expect(timeline.pendingRecords.map(\.id) == [done.id])
        #expect(timeline.visits.map(\.id) == [record.id])
        #expect(timeline.entries.count == 2)
    }

    @Test("Cancelled bookings and no-shows show as not held, never as visits; future ones are not history")
    func notHeld() {
        let cancelled = makeAppointment(clientID: client, daysFromNow: -6, status: .cancelled)
        let noShow = makeAppointment(clientID: client, daysFromNow: -8, status: .noShow)
        let futureCancel = makeAppointment(clientID: client, daysFromNow: 4, status: .cancelled)
        let booked = makeAppointment(clientID: client, daysFromNow: 2, status: .booked)

        let timeline = build(.init(appointments: [cancelled, noShow, futureCancel, booked]))

        #expect(timeline.visits.isEmpty)
        #expect(timeline.entries.map(\.id) == ["notHeld.\(cancelled.id.uuidString)", "notHeld.\(noShow.id.uuidString)"])
    }

    @Test("Visits sort by the day they happened, not the day they were written, and the newest is the last visit")
    func sortsByVisitDay() {
        let writtenLate = TreatmentRecord(clientID: client, serviceName: "Lashes", createdAt: TestClock.days(-1),
                                          performedAt: TestClock.days(-10))
        let recent = makeRecord(clientID: client, createdAt: TestClock.days(-4))

        let timeline = build(.init(records: [writtenLate, recent]))

        #expect(timeline.visits.map(\.id) == [recent.id, writtenLate.id])
        #expect(timeline.lastVisit?.id == recent.id)
        #expect(timeline.visits.last?.visitDate.source == .recorded)
    }

    @Test("A card reads the corrected text, and a draft says so")
    func correctedAndDraft() {
        let record = makeRecord(clientID: client, technique: "Old technique")
        let correction = RecordCorrection(id: UUID(), recordID: record.id, createdAt: TestClock.now,
                                          fieldKey: "technique", oldValue: "Old technique",
                                          newValue: "Corrected technique", reason: "typo")
        let draft = TreatmentRecord(clientID: client, serviceName: "Brows", createdAt: TestClock.days(-1),
                                    status: .draft)

        let timeline = build(.init(records: [record, draft], corrections: [correction]))
        let corrected = timeline.visits.first { $0.id == record.id }

        #expect(corrected?.record.technique == "Corrected technique")
        #expect(corrected?.summary?.hasPrefix("Corrected technique") == true)
        #expect(timeline.drafts.map(\.id) == [draft.id])
    }

    @Test("An incident with no visit stands on its own line")
    func looseIncident() {
        let incident = makeIncident(clientID: client)
        #expect(build(.init(incidents: [incident])).entries.map(\.id) == ["incident.\(incident.id.uuidString)"])
    }
}
