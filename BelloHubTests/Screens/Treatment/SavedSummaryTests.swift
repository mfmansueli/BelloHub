//
//  SavedSummaryTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("SavedSummary")
struct SavedSummaryTests {
    private let names = SavedSummary.Names(
        notes: "Observations", technique: "Technique", products: "Products", result: "Result",
        aftercare: "Aftercare", yes: "Yes", no: "No"
    )

    @Test("Rows come in the record's order and an empty field makes no row")
    func skipsEmptyFields() {
        let record = TreatmentRecord(
            clientID: UUID(), serviceName: "Glow", createdAt: TestClock.now, notes: "Sensitive cheeks",
            technique: "  ", productsUsed: ["Calming serum", "SPF"], aftercare: "No sun"
        )
        let rows = SavedSummary.rows(for: record, names: names)
        #expect(rows.map(\.name) == ["Observations", "Products", "Aftercare"])
        #expect(rows[1].value == "Calming serum, SPF")
    }

    @Test("Her template's own answers follow, with yes or no, options and units in words")
    func entriesAreReadable() {
        var record = TreatmentRecord(clientID: UUID(), serviceName: "Glow", createdAt: TestClock.now)
        record.fieldEntries = [
            RecordFieldEntry(key: "a", name: "Sunscreen", kind: .yesNo, value: RecordFieldEntry.yes),
            RecordFieldEntry(key: "b", name: "Areas", kind: .multiChoice, value: "Cheeks\nChin"),
            RecordFieldEntry(key: "c", name: "Intensity", kind: .number, value: "2.5", unit: "mA")
        ]
        let values = SavedSummary.rows(for: record, names: names).map(\.value)
        #expect(values == ["Yes", "Cheeks, Chin", "2.5 mA"])
    }

    @Test("A record with nothing written has no rows")
    func emptyRecord() {
        let record = TreatmentRecord(clientID: UUID(), serviceName: "Glow", createdAt: TestClock.now)
        #expect(SavedSummary.rows(for: record, names: names).isEmpty)
    }
}
