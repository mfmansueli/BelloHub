//
//  ConsentRecordTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ConsentRecord")
struct ConsentRecordTests {
    private func decode(_ json: String) throws -> ConsentRecord {
        try JSONDecoder().decode(ConsentRecord.self, from: Data(json.utf8))
    }

    @Test("A record written before D55 reads as signed on its date, with the fields that no longer exist ignored")
    func readsTheOldShape() throws {
        let json = #"{"id":"6E1F0000-0000-4000-8000-000000000001","clientID":"6E1F0000-0000-4000-8000-000000000002","# +
            #""kind":"photos","signedAt":1000,"textVersion":"2026-10","localeID":"pt-BR","typedSignature":"Ana"}"#

        let record = try decode(json)

        #expect(record.kind == .photos && record.isSigned)
        #expect(record.signedAt == Date(timeIntervalSinceReferenceDate: 1000))
        #expect(record.createdAt == Date(timeIntervalSinceReferenceDate: 1000), "the signing day is its day")
        #expect(record.label == nil && record.note == nil && record.document == nil)
    }

    @Test("The D55 shape round-trips with the document, and an unsigned record keeps no date")
    func roundTrip() throws {
        let document = ConsentDocument(
            kind: .file, fileName: "scan.pdf", contentType: "com.adobe.pdf", data: Data([1, 2, 3]), thumbnail: nil
        )
        let record = ConsentRecord(
            id: UUID(), clientID: UUID(), kind: .other, isSigned: false, signedAt: nil, createdAt: TestClock.now,
            label: "Microblading", note: "Paper in the drawer", document: document
        )

        let data = try JSONEncoder().encode(record)
        let back = try JSONDecoder().decode(ConsentRecord.self, from: data)

        #expect(back == record)
        #expect(back.effectiveDate == TestClock.now, "an unsigned record stands for the day the note was made")
    }

    @Test("An unknown kind or document kind reads as the fallback instead of failing")
    func unknownRaws() throws {
        let json = #"{"id":"6E1F0000-0000-4000-8000-000000000001","clientID":"6E1F0000-0000-4000-8000-000000000002","# +
            #""kind":"somethingNew","isSigned":true,"signedAt":5,"createdAt":5,"# +
            #""document":{"kind":"hologram","contentType":"public.data","data":"AQID"}}"#

        let record = try decode(json)

        #expect(record.kind == .treatment)
        #expect(record.document?.kind == .file && record.document?.data == Data([1, 2, 3]))
    }

    @Test("Lists are ordered by the most recent date, ties by id, so two phones agree")
    func order() {
        let early = makeConsentRecord(daysAgo: 30)
        let late = makeConsentRecord(daysAgo: 1)
        let unsignedToday = makeConsentRecord(isSigned: false, daysAgo: 0)

        let ordered = ConsentRecord.newestFirst([early, late, unsignedToday])

        #expect(ordered == [unsignedToday, late, early])
        let twins = [makeConsentRecord(daysAgo: 3), makeConsentRecord(daysAgo: 3)]
        #expect(ConsentRecord.newestFirst(twins) == ConsentRecord.newestFirst(twins.reversed()))
    }

    @Test("The label shown is hers when she wrote one, else the kind's title")
    func displayLabel() {
        #expect(makeConsentRecord(label: "  Facial, paper form ").displayLabel(kindTitle: "Treatment")
                == "Facial, paper form")
        #expect(makeConsentRecord(label: "   ").displayLabel(kindTitle: "Treatment") == "Treatment")
        #expect(makeConsentRecord().displayLabel(kindTitle: "Treatment") == "Treatment")
    }

    @Test("Every kind has a title, and the raw values that are stored never change")
    func kinds() {
        #expect(ConsentKind.allCases.map(\.rawValue) == ["treatment", "photos", "guardian", "other"])
        #expect(ConsentKind.fallback == .treatment)
        for kind in ConsentKind.allCases {
            #expect(!String(localized: kind.title).isEmpty)
        }
        #expect(ConsentDocumentKind.allCases.map(\.rawValue) == ["photo", "file"])
    }
}
