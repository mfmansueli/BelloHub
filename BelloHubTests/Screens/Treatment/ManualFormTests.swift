//
//  ManualFormTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The faster manual record (routine-a item 8): few questions at once, the rest folded, and "Same as last visit".
@Suite("Manual record form")
struct ManualFormTests {
    private func field(_ key: String, _ role: TreatmentFormField.Role, input: TreatmentFormField.Input = .text)
        -> TreatmentFormField {
        TreatmentFormField(key: key, name: key, input: input, role: role)
    }

    private var fields: [TreatmentFormField] {
        [
            field(TreatmentFormField.notesKey, .notes), field("est.technique", .technique),
            field("est.products", .products, input: .products), field("est.skin", .generic),
            field("est.zone", .generic), field("est.spf", .generic), field("est.hydration", .generic)
        ]
    }

    @Test("The record's own fields and the first two of hers show; the rest are folded until answered")
    func layout() {
        var draft = TreatmentDraft()
        var split = TreatmentFormLayout.split(fields, draft: draft)
        #expect(split.main.map(\.key) == [TreatmentFormField.notesKey, "est.technique", "est.products", "est.skin",
                                          "est.zone"])
        #expect(split.more.map(\.key) == ["est.spf", "est.hydration"])

        draft.set("50", for: "est.hydration")
        split = TreatmentFormLayout.split(fields, draft: draft)
        #expect(split.main.map(\.key).contains("est.hydration"))
        #expect(split.more.map(\.key) == ["est.spf"])
    }

    @Test("The last visit of the same service is found, never the record being written")
    func source() {
        let client = UUID()
        let glow = UUID()
        let older = TreatmentRecord(
            clientID: client, serviceID: glow, serviceName: "Glow", createdAt: TestClock.days(-60)
        )
        let newer = TreatmentRecord(
            clientID: client, serviceID: glow, serviceName: "Glow", createdAt: TestClock.days(-20)
        )
        let otherService = TreatmentRecord(
            clientID: client, serviceID: UUID(), serviceName: "Peel", createdAt: TestClock.days(-5)
        )
        let current = TreatmentRecord(clientID: client, serviceID: glow, serviceName: "Glow", createdAt: TestClock.now)

        let found = LastVisitPrefill.source(
            records: [older, newer, otherService, current], serviceID: glow, serviceName: "Glow", excluding: current.id
        )
        #expect(found?.id == newer.id)
    }

    @Test("Only technique, products and her own fields are offered, and only where the form is empty")
    func values() {
        var record = TreatmentRecord(clientID: UUID(), serviceName: "Glow", createdAt: TestClock.days(-20))
        record.notes = "Visit-specific note"
        record.technique = "Reduced intensity"
        record.productsUsed = ["Serum", "SPF 50"]
        record.aftercare = "Avoid sun"
        record.fieldEntries = [RecordFieldEntry(key: "est.skin", name: "Skin", kind: .text, value: "Dry")]
        var draft = TreatmentDraft()
        draft.set("Already typed", for: "est.technique")

        let offered = LastVisitPrefill.values(from: record, fields: fields, draft: draft)

        #expect(offered == ["est.products": "Serum\nSPF 50", "est.skin": "Dry"])
    }
}
