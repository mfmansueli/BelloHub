//
//  TreatmentRecordBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("TreatmentRecordBuilder")
struct TreatmentRecordBuilderTests {
    private let locale = Locale(identifier: "en_US")
    private let fields = [
        TreatmentFormField(key: "notes", name: "Observations", input: .text, role: .notes),
        TreatmentFormField(key: "x.products", name: "Products", input: .products, role: .products),
        TreatmentFormField(key: "x.technique", name: "Technique", input: .text, role: .technique),
        TreatmentFormField(key: "x.depth", name: "Depth", input: .number(unit: "mm"), role: .generic)
    ]

    private func context(source: RecordSource = .manual, aiAssisted: Bool = false) -> TreatmentRecordBuilder.Context {
        TreatmentRecordBuilder.Context(
            clientID: UUID(), serviceName: "Glow", id: UUID(), createdAt: TestClock.now, source: source,
            aiAssisted: aiAssisted
        )
    }

    @Test("Answers go where their role says; the others become entries with the name and unit they had")
    func placesAnswers() {
        var draft = TreatmentDraft(result: .good)
        draft.set("Sensitive cheeks", for: "notes")
        draft.set("Calming serum\nSPF", for: "x.products")
        draft.set("Light", for: "x.technique")
        draft.set("2.5", for: "x.depth")
        let record = TreatmentRecordBuilder.build(draft: draft, fields: fields, context: context(), locale: locale)
        #expect(record.notes == "Sensitive cheeks" && record.technique == "Light")
        #expect(record.productsUsed == ["Calming serum", "SPF"])
        #expect(record.result == .good)
        #expect(record.fieldEntries?.map(\.key) == ["x.depth"])
        #expect(record.fieldEntries?.first?.unit == "mm")
    }

    @Test("The record locks 24 hours after it was created and keeps the id the flow fixed")
    func locksAfterADay() {
        let context = context()
        let record = TreatmentRecordBuilder.build(
            draft: TreatmentDraft(), fields: fields, context: context, locale: locale
        )
        #expect(record.id == context.id)
        #expect(record.lockedAt == TestClock.now.addingTimeInterval(24 * 3600))
    }

    @Test("Source and the AI flag come from the context")
    func provenance() {
        let record = TreatmentRecordBuilder.build(
            draft: TreatmentDraft(), fields: fields, context: context(source: .voice, aiAssisted: true), locale: locale
        )
        #expect(record.source == .voice && record.aiAssisted)
    }

    @Test("Nothing filled in is the only problem of an empty draft; a bad number is named by its field")
    func issues() {
        #expect(TreatmentRecordBuilder.issues(of: TreatmentDraft(), fields: fields, locale: locale) == [.nothingToSave])
        var draft = TreatmentDraft()
        draft.set("deep", for: "x.depth")
        #expect(
            TreatmentRecordBuilder.issues(of: draft, fields: fields, locale: locale) == [.invalidNumber(key: "x.depth")]
        )
    }
}
