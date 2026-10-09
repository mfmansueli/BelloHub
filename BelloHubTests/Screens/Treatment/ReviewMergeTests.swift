//
//  ReviewMergeTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ReviewMerge")
struct ReviewMergeTests {
    private let fields = [
        TreatmentFormField(key: "notes", name: "Observations", input: .text, role: .notes),
        TreatmentFormField(key: "x.technique", name: "Technique", input: .text, role: .technique),
        TreatmentFormField(key: "x.skin", name: "Skin", input: .choice(["Dry", "Oily"]), role: .generic),
        TreatmentFormField(key: "x.depth", name: "Depth", input: .number(unit: "mm"), role: .generic)
    ]

    private func proposals(_ values: [String: String]) -> ReviewMerge.Proposals {
        ReviewMerge.proposals(
            from: StructuredRecordDraft(values: values, summary: nil), fields: fields,
            locale: Locale(identifier: "en_US")
        )
    }

    @Test("One card per filled field, in the form's order; unknown keys and blanks make none")
    func cards() {
        let found = proposals(["x.technique": "Light", "notes": "Sensitive", "nope": "ignored", "x.skin": "  "])
        #expect(found.items.map(\.field.key) == ["notes", "x.technique"])
        #expect(found.rejectedCount == 0)
    }

    @Test("A choice she did not list or a number that is not one is turned away and counted")
    func invalidValuesAreRejected() {
        let found = proposals(["x.skin": "Combination", "x.depth": "deep", "notes": "ok"])
        #expect(found.items.map(\.field.key) == ["notes"])
        #expect(found.rejectedCount == 2)
    }

    @Test("Nothing reaches the draft while a card is pending, dropped or empty; an edit wins over the proposal")
    func applyOnlyWhatShesDecided() {
        var items = proposals(["notes": "Sensitive", "x.technique": "Light"]).items
        #expect(!ReviewMerge.isComplete(items))
        #expect(ReviewMerge.apply(items, to: TreatmentDraft()).isEmpty)
        items[0].decision = .edited("Very sensitive")
        items[1].decision = .dropped
        let draft = ReviewMerge.apply(items, to: TreatmentDraft())
        #expect(draft.value(for: "notes") == "Very sensitive")
        #expect(draft.value(for: "x.technique").isEmpty)
    }

    @Test("aiAssisted is true only after a finished review that kept something")
    func aiAssistedGate() {
        var items = proposals(["notes": "Sensitive", "x.technique": "Light"]).items
        #expect(!ReviewMerge.isAIAssisted(items), "pending")
        items[0].decision = .accepted
        #expect(!ReviewMerge.isAIAssisted(items), "one still pending")
        items[1].decision = .dropped
        #expect(ReviewMerge.isAIAssisted(items))
        items[0].decision = .dropped
        #expect(!ReviewMerge.isAIAssisted(items), "everything dropped: she wrote nothing with the AI")
    }

    @Test("The fields the AI left empty are listed as not mentioned")
    func notMentioned() {
        let items = proposals(["notes": "Sensitive"]).items
        #expect(ReviewMerge.notMentioned(items, fields: fields).map(\.key) == ["x.technique", "x.skin", "x.depth"])
    }
}
