//
//  RecordExportSelectorTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecordExportSelector")
struct RecordExportSelectorTests {
    private let calendar = TestClock.calendar()
    private let client: Client
    private let recent: TreatmentRecord
    private let old: TreatmentRecord
    private let notesCorrection: RecordCorrection
    private let aftercareCorrection: RecordCorrection
    private let privatePhoto: Photo
    private let sharedPhoto: Photo
    private let oldSharedPhoto: Photo
    private let source: RecordExportSource

    init() {
        var client = makeClient(name: "Ana Costa")
        client.allergies = ["Latex"]
        client.sensitivities = ["Fragrance"]
        client.importantNote = "Prefers a quiet room"
        self.client = client
        recent = makeRecord(clientID: client.id, createdAt: TestClock.days(-20), notes: "Private observation")
        old = makeRecord(clientID: client.id, createdAt: TestClock.days(-500), notes: "Old private note")
        notesCorrection = makeCorrection(recordID: recent.id, field: .notes, old: "Private observation", new: "Secret")
        aftercareCorrection = makeCorrection(recordID: recent.id, field: .aftercare, new: "Cleanse gently")
        privatePhoto = makePhoto(clientID: client.id, takenAt: TestClock.days(-20), visibility: .professionalOnly)
        sharedPhoto = makePhoto(clientID: client.id, takenAt: TestClock.days(-19), visibility: .shareWithClient)
        oldSharedPhoto = makePhoto(clientID: client.id, takenAt: TestClock.days(-600), visibility: .portfolio)
        source = RecordExportSource(
            client: client, records: [old, recent], corrections: [notesCorrection, aftercareCorrection],
            incidents: [makeIncident(clientID: client.id, occurredAt: TestClock.days(-10)),
                        makeIncident(clientID: client.id, occurredAt: TestClock.days(-700))],
            photos: [privatePhoto, sharedPhoto, oldSharedPhoto],
            consents: [makeConsent(clientID: client.id, kind: .treatment),
                       makeConsent(clientID: client.id, kind: .photos)]
        )
    }

    private func content(_ options: ExportOptions) -> RecordExportContent {
        RecordExportSelector.content(from: source, options: options, now: TestClock.now, calendar: calendar)
    }

    // MARK: - Privacy

    @Test("The client's copy never includes internal notes, even if the switch is on")
    func clientCopyHasNoNotes() {
        var options = ExportOptions()
        options.audience = .client
        options.includeInternalNotes = true
        let result = content(options)
        #expect(result.treatments.allSatisfy { $0.record.notes == nil })
        #expect(result.treatments.flatMap(\.corrections).allSatisfy { $0.fieldKey != "notes" })
        #expect(result.treatments.flatMap(\.corrections).contains { $0.fieldKey == "aftercare" })
    }

    @Test("A health professional's copy includes internal notes only when the switch is on")
    func doctorCopyNotes() {
        var options = ExportOptions()
        options.audience = .healthProfessional
        options.includeInternalNotes = false
        #expect(content(options).treatments.allSatisfy { $0.record.notes == nil })
        options.includeInternalNotes = true
        let with = content(options)
        #expect(with.treatments.contains { $0.record.notes == "Private observation" })
        #expect(with.treatments.flatMap(\.corrections).contains { $0.fieldKey == "notes" })
    }

    @Test("Her important note is only in a health professional's copy")
    func importantNote() {
        var options = ExportOptions()
        options.audience = .client
        #expect(content(options).health?.importantNote == nil)
        #expect(content(options).health?.allergies == ["Latex"])
        options.audience = .healthProfessional
        #expect(content(options).health?.importantNote == "Prefers a quiet room")
    }

    @Test("Consent records carry their kind, label and date but never the photo or file of the paper (D55)")
    func consentsHaveNoSignature() {
        let result = content(ExportOptions())
        #expect(result.consents.count == 2)
        #expect(result.consents.allSatisfy { $0.document == nil })
        #expect(result.consents.allSatisfy { $0.note != nil }, "the note is hers and stays in the export")
    }

    @Test("The client's copy has only photos shared with her; a health professional's copy has every photo")
    func photosByAudience() {
        var options = ExportOptions()
        options.includePhotos = true
        options.period = .allTime
        options.audience = .client
        #expect(Set(content(options).photos.map(\.id)) == [sharedPhoto.id, oldSharedPhoto.id])
        options.audience = .healthProfessional
        #expect(Set(content(options).photos.map(\.id)) == [privatePhoto.id, sharedPhoto.id, oldSharedPhoto.id])
    }

    @Test("Photos are off by default and so is everything private")
    func defaults() {
        let options = ExportOptions()
        #expect(options.includePhotos == false)
        #expect(options.includeInternalNotes == false)
        #expect(options.audience == .client)
        #expect(content(options).photos.isEmpty)
    }

    // MARK: - Switches and period

    @Test("A switch that is off leaves its part out")
    func switches() {
        var options = ExportOptions()
        options.includeHealth = false
        options.includeConsent = false
        options.includeTreatments = false
        let result = content(options)
        #expect(result.health == nil)
        #expect(result.consents.isEmpty)
        #expect(result.treatments.isEmpty)
        #expect(result.incidents.isEmpty)
    }

    @Test("Last 12 months leaves out older records, incidents and photos; all time keeps them")
    func period() {
        var options = ExportOptions()
        options.includePhotos = true
        options.period = .last12Months
        let year = content(options)
        #expect(year.treatments.map(\.record.id) == [recent.id])
        #expect(year.incidents.count == 1)
        #expect(Set(year.photos.map(\.id)) == [sharedPhoto.id])
        options.period = .allTime
        let all = content(options)
        #expect(all.treatments.map(\.record.id) == [recent.id, old.id])
        #expect(all.incidents.count == 2)
    }

    @Test("Treatments come newest first and a client with nothing health related has no health part")
    func orderAndEmptyHealth() {
        var bare = client
        bare.allergies = []
        bare.sensitivities = []
        bare.importantNote = nil
        let emptySource = RecordExportSource(
            client: bare, records: [old, recent], corrections: [], incidents: [], photos: [], consents: []
        )
        let result = RecordExportSelector.content(
            from: emptySource, options: ExportOptions(), now: TestClock.now, calendar: calendar
        )
        #expect(result.health == nil)
        #expect(result.treatments.map(\.record.id) == [recent.id, old.id])
    }
}
