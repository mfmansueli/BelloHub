//
//  ConsentRecordRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ConsentRecordRules")
struct ConsentRecordRulesTests {
    private let clientID = UUID()

    @Test("A draft saves with no label (the kind names it) or with a label of two characters or more")
    func canSave() {
        var draft = ConsentRecordDraft(signedAt: TestClock.now)
        #expect(ConsentRecordRules.canSave(draft))
        draft.label = " A "
        #expect(!ConsentRecordRules.canSave(draft))
        draft.label = "Facial"
        #expect(ConsentRecordRules.canSave(draft))
    }

    @Test("A signed draft keeps its date; an unsigned one stores none, and empty text is stored as nothing")
    func record() {
        var draft = ConsentRecordDraft(signedAt: TestClock.days(-3))
        draft.kind = .photos
        draft.label = "  Photos for the portfolio "
        draft.note = "   "
        let id = UUID()

        let signed = ConsentRecordRules.record(
            from: draft, clientID: clientID, id: id, createdAt: TestClock.days(-10), now: TestClock.now
        )
        #expect(signed.id == id && signed.clientID == clientID && signed.kind == .photos && signed.isSigned)
        #expect(signed.signedAt == TestClock.days(-3) && signed.createdAt == TestClock.days(-10))
        #expect(signed.label == "Photos for the portfolio" && signed.note == nil && signed.document == nil)

        draft.isSigned = false
        let unsigned = ConsentRecordRules.record(
            from: draft, clientID: clientID, id: id, createdAt: TestClock.now, now: TestClock.now
        )
        #expect(!unsigned.isSigned && unsigned.signedAt == nil && unsigned.effectiveDate == TestClock.now)
    }

    @Test("Editing starts from the record; an unsigned record proposes today as the date")
    func draftFromRecord() {
        let document = ConsentDocument(
            kind: .photo, fileName: nil, contentType: "public.jpeg", data: Data([1]), thumbnail: Data([2])
        )
        let signed = makeConsentRecord(kind: .guardian, daysAgo: 7, label: "Rita", note: "Paper", document: document)
        let draft = ConsentRecordRules.draft(from: signed, now: TestClock.now)
        #expect(draft.kind == .guardian && draft.label == "Rita" && draft.note == "Paper" && draft.isSigned)
        #expect(draft.signedAt == TestClock.days(-7) && draft.document == document)

        let unsigned = makeConsentRecord(isSigned: false, daysAgo: 7)
        #expect(ConsentRecordRules.draft(from: unsigned, now: TestClock.now).signedAt == TestClock.now)
        #expect(ConsentRecordRules.draft(from: unsigned, now: TestClock.now).label == "")
    }

    @Test("A document is accepted up to the cap and never when empty")
    func documentSize() {
        #expect(ConsentRecordRules.acceptsDocument(bytes: 1))
        #expect(ConsentRecordRules.acceptsDocument(bytes: ConsentDocument.maximumBytes))
        #expect(!ConsentRecordRules.acceptsDocument(bytes: ConsentDocument.maximumBytes + 1))
        #expect(!ConsentRecordRules.acceptsDocument(bytes: 0))
    }

    @Test("Only a record she marked signed counts, and the latest signed date wins")
    func status() {
        let records = [
            makeConsentRecord(kind: .photos, isSigned: false, daysAgo: 0),
            makeConsentRecord(kind: .treatment, daysAgo: 20),
            makeConsentRecord(kind: .treatment, daysAgo: 5)
        ]
        #expect(!ConsentRecordRules.hasSigned(.photos, in: records))
        #expect(ConsentRecordRules.hasSigned(.treatment, in: records))
        #expect(ConsentRecordRules.latestSignedDate(in: records) == TestClock.days(-5))
        #expect(ConsentRecordRules.latestSignedDate(in: [records[0]]) == nil)
    }
}
