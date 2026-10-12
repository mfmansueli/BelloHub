//
//  TreatmentDraftTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("TreatmentDraft")
struct TreatmentDraftTests {
    @Test("Values the flow wrote by itself are not her answers until she changes them")
    func startingValuesAreNotAnswers() {
        var draft = TreatmentDraft(values: ["aftercare": "Rest for a day."])
        let starting = ["aftercare": "Rest for a day."]
        #expect(!draft.hasAnswers(besides: starting))

        draft.set("Rest for two days.", for: "aftercare")
        #expect(draft.hasAnswers(besides: starting))
    }

    @Test("A result or a new field is an answer, even next to untouched starting values")
    func resultAndOtherFields() {
        let starting = ["aftercare": "Rest."]
        #expect(TreatmentDraft(result: .good, values: starting).hasAnswers(besides: starting))
        #expect(TreatmentDraft(values: ["aftercare": "Rest.", "notes": "Calm"]).hasAnswers(besides: starting))
        #expect(!TreatmentDraft().hasAnswers(besides: [:]))
    }
}
