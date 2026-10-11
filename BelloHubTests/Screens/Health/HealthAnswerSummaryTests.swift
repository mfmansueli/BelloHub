//
//  HealthAnswerSummaryTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("HealthAnswerSummary")
struct HealthAnswerSummaryTests {
    private let catalog = makeHealthCatalog()
    private let labels = HealthAnswerSummary.Labels(yes: "Yes", no: "No", none: "None", notAnswered: "Not answered")
    private let list: ([String]) -> String = { $0.joined(separator: " and ") }

    private func rows(_ form: HealthForm, template: HealthFormTemplate?) -> [HealthAnswerSummary.Row] {
        HealthAnswerSummary.rows(form: form, template: template, catalog: catalog, labels: labels, list: list)
    }

    @Test("The rows follow the questions of the version the form was signed on, with the names of the catalog")
    func followsTheTemplate() {
        let form = makeHealthForm(answers: [
            "allergies": .choices(["latex", "fragrance"]), "medication": .no, "pregnancy": .yes
        ])
        let result = rows(form, template: makeHealthTemplate(keys: ["allergies", "medication", "pregnancy", "notes"]))

        #expect(result.map(\.name) == ["Allergies", "Medication", "Pregnant or breastfeeding"])
        #expect(result.map(\.value) == ["Fragrance and Latex", "No", "Yes"])
        #expect(result.allSatisfy { $0.isAnswered })
    }

    @Test("A question the form asked and nobody answered says so; an optional note nobody wrote is left out")
    func unanswered() {
        let form = makeHealthForm(answers: ["allergies": .choices(["none"])])
        let result = rows(form, template: makeHealthTemplate(keys: ["allergies", "medication", "notes"]))

        #expect(result.map(\.key) == ["allergies", "medication"])
        #expect(result[0].value == "None" && result[0].isAnswered)
        #expect(result[1].value == "Not answered" && !result[1].isAnswered)
    }

    @Test("A note that was written shows, trimmed")
    func note() {
        let form = makeHealthForm(answers: ["notes": .text("  Sensitive around the eyes ")])
        let result = rows(form, template: makeHealthTemplate(keys: ["notes"]))
        #expect(result.map(\.value) == ["Sensitive around the eyes"])
    }

    @Test("An answer outside the template still shows, so nothing the client said is hidden")
    func extraAnswers() {
        let form = makeHealthForm(answers: [
            "medication": .yes, "scalp": .no, "fromTheFuture": .text("later"), "allergies": .choices(["x"])
        ])
        let result = rows(form, template: makeHealthTemplate(keys: ["medication"]))

        // Template first, then known questions in catalog order, then unknown keys.
        #expect(result.map(\.key) == ["medication", "allergies", "scalp", "fromTheFuture"])
        #expect(result.last?.name == "fromTheFuture" && result.last?.value == "later")
        #expect(result[1].value == "x", "a choice this version does not know shows its key")
    }

    @Test("Without the template of that version the answered questions show in catalog order")
    func noTemplate() {
        let form = makeHealthForm(answers: ["notes": .text("a"), "medication": .no, "allergies": .choices(["latex"])])
        #expect(rows(form, template: nil).map(\.key) == ["allergies", "medication", "notes"])
    }

    @Test("An empty list of choices counts as not answered")
    func emptyChoices() {
        let form = makeHealthForm(answers: ["allergies": .choices([])])
        let result = rows(form, template: makeHealthTemplate(keys: ["allergies"]))
        #expect(result.first?.value == "Not answered" && result.first?.isAnswered == false)
    }
}
