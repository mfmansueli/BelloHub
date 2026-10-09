//
//  RecordExportDocumentBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecordExportDocumentBuilder")
struct RecordExportDocumentBuilderTests {
    private let english = Locale(identifier: "en")
    private let calendar = TestClock.calendar()

    private func builder() -> RecordExportDocumentBuilder {
        RecordExportDocumentBuilder(
            resolve: { $0.resolved(in: Locale(identifier: "en")) },
            formatters: Formatters(locale: english, timeZone: TestClock.saoPaulo, currencyCode: "BRL"),
            professionalName: "Maria Silva", now: TestClock.now
        )
    }

    private func texts(_ document: RecordExportDocument) -> [String] {
        document.sections.flatMap { section in
            [section.heading] + section.items.map { item in
                switch item {
                case .line(let label, let value): "\(label): \(value)"
                case .text(let text): text
                case .photo(_, let caption): caption
                }
            }
        }
    }

    private func document(audience: ExportAudience, notes: Bool, photos: Bool = false)
        -> (RecordExportDocument, [String]) {
        var client = makeClient(name: "Ana Costa")
        client.allergies = ["Latex"]
        let record = makeRecord(clientID: client.id, notes: "PRIVATE-OBSERVATION", aftercare: "Cleanse gently")
        let photo = makePhoto(clientID: client.id, kind: .before, visibility: .shareWithClient)
        let source = RecordExportSource(
            client: client, records: [record],
            corrections: [makeCorrection(recordID: record.id, field: .notes, new: "PRIVATE-CORRECTION"),
                          makeCorrection(recordID: record.id, field: .aftercare, new: "Cleanse for 48 hours")],
            incidents: [makeIncident(clientID: client.id)], photos: [photo],
            consents: [makeConsent(clientID: client.id)]
        )
        var options = ExportOptions()
        options.audience = audience
        options.includeInternalNotes = notes
        options.includePhotos = photos
        let content = RecordExportSelector.content(
            from: source, options: options, now: TestClock.now, calendar: calendar
        )
        let built = builder().document(for: content, photoData: [photo.id: Data([1, 2, 3])])
        return (built, texts(built))
    }

    @Test("The client's copy says nothing of the internal notes, not even in a correction")
    func clientCopyIsClean() {
        let (_, lines) = document(audience: .client, notes: true)
        let all = lines.joined(separator: "\n")
        #expect(!all.contains("PRIVATE-OBSERVATION"))
        #expect(!all.contains("PRIVATE-CORRECTION"))
        #expect(all.contains("Cleanse for 48 hours"))
    }

    @Test("A health professional's copy with the switch on includes the notes")
    func doctorCopyHasNotes() {
        let (_, lines) = document(audience: .healthProfessional, notes: true)
        #expect(lines.joined(separator: "\n").contains("PRIVATE-OBSERVATION"))
    }

    @Test("The document has a title, the professional, the footer and a PDF file name")
    func frame() {
        let (document, _) = document(audience: .client, notes: false)
        #expect(document.title.contains("Ana Costa"))
        #expect(document.subtitle.contains("Maria Silva"))
        #expect(document.fileName == "Ana-Costa-record.pdf")
        #expect(!document.footer.isEmpty)
    }

    @Test("Sections follow health, consent, each treatment, reactions and photos")
    func sectionOrder() {
        let (document, _) = document(audience: .client, notes: false, photos: true)
        #expect(document.sections.count == 5)
        #expect(document.sections.first?.items.first == .line(label: "Allergies", value: "Latex"))
        #expect(document.sections.last?.items.count == 1)
    }

    @Test("A photo without image data is left out instead of leaving an empty slot")
    func photoWithoutData() {
        let photo = makePhoto(kind: .after, visibility: .shareWithClient)
        let source = RecordExportSource(
            client: makeClient(), records: [], corrections: [], incidents: [], photos: [photo], consents: []
        )
        var options = ExportOptions()
        options.includePhotos = true
        let content = RecordExportSelector.content(
            from: source, options: options, now: TestClock.now, calendar: calendar
        )
        #expect(builder().document(for: content, photoData: [:]).sections.isEmpty)
    }
}
