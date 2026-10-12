//
//  VisitReuseTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("VisitReuse")
struct VisitReuseTests {
    private func makeSource() -> TreatmentRecord {
        TreatmentRecord(
            clientID: UUID(), appointmentID: UUID(), serviceName: "Lash lift", createdAt: TestClock.days(-20),
            performedAt: TestClock.days(-21), result: .reaction, notes: "Private note", technique: "Curl C",
            productsUsed: ["Glue A", "Primer"], resultDetail: "Lifted well", reaction: "Itchy eyes",
            aftercare: "No water 24 h", nextSessionSuggestion: "6 wk", nextVisitReminder: "Try curl D",
            fieldEntries: [RecordFieldEntry(key: "curl", name: "Curl", kind: .text, value: "C")]
        )
    }

    @Test("Only parts the record has are offered; how it was done is ticked, what was written that day is not")
    func offeredAndDefault() {
        let source = makeSource()

        #expect(VisitReuse.offeredParts(of: source)
                == [.technique, .products, .entry(key: "curl"), .aftercare, .notes, .nextVisitReminder])
        #expect(VisitReuse.defaultParts(of: source) == [.technique, .products, .entry(key: "curl")])
        #expect(VisitReuse.offeredParts(of: TreatmentRecord(clientID: UUID(), serviceName: "x",
                                                            createdAt: TestClock.now)).isEmpty)
    }

    @Test("Copying never brings the result, reaction, visit day, ids, status or next-session text")
    func neverCopied() {
        let source = makeSource()
        let fresh = TreatmentRecord(clientID: source.clientID, serviceName: "Lash lift", createdAt: TestClock.now,
                                    status: .draft)
        let all = Set(VisitReuse.offeredParts(of: source))
        let copy = VisitReuse.apply(all, from: source, to: fresh)

        #expect(copy.id == fresh.id)
        #expect(copy.appointmentID == nil)
        #expect(copy.performedAt == nil)
        #expect(copy.result == fresh.result)
        #expect(copy.resultDetail == nil)
        #expect(copy.reaction == nil)
        #expect(copy.nextSessionSuggestion == nil)
        #expect(copy.status == .draft)
        #expect(copy.technique == "Curl C")
        #expect(copy.productsUsed == ["Glue A", "Primer"])
        #expect(copy.fieldEntries?.map(\.value) == ["C"])
    }

    @Test("Unticked parts stay as the new visit had them")
    func untickedStay() {
        let source = makeSource()
        var fresh = TreatmentRecord(clientID: source.clientID, serviceName: "Lash lift", createdAt: TestClock.now)
        fresh.notes = "Today's own note"
        let copy = VisitReuse.apply([.technique], from: source, to: fresh)

        #expect(copy.notes == "Today's own note")
        #expect(copy.productsUsed.isEmpty)
        #expect(copy.technique == "Curl C")
    }
}
