//
//  RecordCurrentValuesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecordCurrentValues")
struct RecordCurrentValuesTests {
    private func correction(_ record: TreatmentRecord, key: String, new: String?, minutes: Double = 0)
        -> RecordCorrection {
        RecordCorrection(id: UUID(), recordID: record.id, createdAt: TestClock.now.addingTimeInterval(minutes * 60),
                         fieldKey: key, oldValue: nil, newValue: new, reason: "why")
    }

    @Test("Products, template answers and the visit day read with their latest correction")
    func appliesCorrections() {
        var record = makeRecord(products: ["Serum"])
        record.fieldEntries = [RecordFieldEntry(key: "curl", name: "Curl", kind: .text, value: "C")]
        let visitDay = TestClock.date("2026-09-20 10:00")
        let values = RecordCurrentValues(record: record, corrections: [
            correction(record, key: "productsUsed", new: "Serum\nMask"),
            correction(record, key: "field.curl", new: "D"),
            correction(record, key: "performedAt", new: RecordCurrentValues.text(from: visitDay))
        ])

        #expect(values.products == ["Serum", "Mask"])
        #expect(values.entries().map(\.value) == ["D"])
        #expect(values.performedAt == visitDay)
        #expect(values.applied.productsUsed == ["Serum", "Mask"])
        #expect(values.applied.performedAt == visitDay)
        #expect(record.productsUsed == ["Serum"], "the original is never changed")
    }

    @Test("An answer added after the lock is named from the template; an emptied one disappears")
    func addedAndEmptied() {
        var record = makeRecord()
        record.fieldEntries = [RecordFieldEntry(key: "area", name: "Area", kind: .text, value: "Cheeks")]
        let template = [RecordFieldEntry(key: "depth", name: "Depth", kind: .number, value: "", unit: "mm")]
        let values = RecordCurrentValues(record: record, corrections: [
            correction(record, key: "field.area", new: nil),
            correction(record, key: "field.depth", new: "0.5")
        ])

        let entries = values.entries(templateFields: template)
        #expect(entries.map(\.name) == ["Depth"])
        #expect(entries.first?.unit == "mm")
    }

    @Test("Corrections of another record do not count")
    func otherRecord() {
        let record = makeRecord(technique: "Mine")
        let other = makeRecord()
        let values = RecordCurrentValues(record: record, corrections: [correction(other, key: "technique", new: "X")])

        #expect(values.value(.technique) == "Mine")
    }
}
