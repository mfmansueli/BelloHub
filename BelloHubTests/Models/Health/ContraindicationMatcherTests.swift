//
//  ContraindicationMatcherTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ContraindicationMatcher")
struct ContraindicationMatcherTests {
    private let catalog = makeHealthCatalog()

    private func check(
        _ tokens: [String], answers: [String: HealthAnswer], minor: Bool = false
    ) -> ContraindicationReport {
        ContraindicationMatcher.check(
            contraindications: tokens, form: makeHealthForm(answers: answers, isForMinor: minor), catalog: catalog
        )
    }

    @Test("A yes to a yes-or-no question triggers its token; a no does not")
    func yesNo() {
        #expect(check(["pregnancy"], answers: ["pregnancy": .yes]).matches.map(\.token) == ["pregnancy"])
        #expect(check(["pregnancy"], answers: ["pregnancy": .no]).matches.isEmpty)
        #expect(check(["pregnancy"], answers: [:]).matches.isEmpty)
    }

    @Test("A choice token needs that exact choice ticked")
    func choice() {
        let answers: [String: HealthAnswer] = ["allergies": .choices(["fragrance", "latex"])]
        let report = check(["allergies.latex", "allergies.retinol"], answers: answers)
        #expect(report.matches.map(\.token) == ["allergies.latex"])
        #expect(report.matches.first?.questionKey == "allergies" && report.matches.first?.optionKey == "latex")
    }

    @Test("The question alone matches any choice except None")
    func anyChoice() {
        #expect(check(["allergies"], answers: ["allergies": .choices(["retinol"])]).hasWarnings)
        #expect(!check(["allergies"], answers: ["allergies": .choices(["none"])]).hasWarnings)
        #expect(!check(["allergies"], answers: ["allergies": .choices([])]).hasWarnings)
    }

    @Test("A text answer triggers the question token only when it says something")
    func text() {
        #expect(check(["notes"], answers: ["notes": .text("keloid scars")]).hasWarnings)
        #expect(!check(["notes"], answers: ["notes": .text("   ")]).hasWarnings)
    }

    @Test("A form filled in for a minor triggers the minor token (D17)")
    func minor() {
        let token = ContraindicationMatcher.minorToken
        let match = check([token], answers: [:], minor: true).matches.first
        #expect(match?.token == "minor" && match?.questionKey == nil)
        #expect(!check([token], answers: [:], minor: false).hasWarnings)
    }

    @Test("Text she wrote herself, or a key from a newer version, is returned as unchecked, never dropped")
    func unchecked() {
        let report = check(
            ["Keloid scars", "futureQuestion", "allergies.unknownChoice", "pregnancy.nope"],
            answers: ["pregnancy": .yes]
        )
        #expect(report.matches.isEmpty)
        #expect(report.unchecked == ["Keloid scars", "futureQuestion", "allergies.unknownChoice", "pregnancy.nope"])
    }

    @Test("With no form there is nothing to match, and the report says so instead of saying all is well")
    func noForm() {
        let report = ContraindicationMatcher.check(
            contraindications: ["pregnancy", "Keloid scars"], form: nil, catalog: catalog
        )
        #expect(!report.hasHealthForm)
        #expect(report.matches.isEmpty)
        #expect(report.unchecked == ["Keloid scars"])
    }

    @Test("Matches come in the order the service lists them, once each, with blanks ignored")
    func orderAndDuplicates() {
        let report = check(
            [" pregnancy ", "", "allergies.latex", "pregnancy"],
            answers: ["pregnancy": .yes, "allergies": .choices(["latex"])]
        )
        #expect(report.matches.map(\.token) == ["pregnancy", "allergies.latex"])
        #expect(report.hasHealthForm)
    }

    @Test("A warning never blocks: the report carries information only")
    func warnsOnly() {
        // The matcher returns a value and has no way to stop a booking (D16). Pin the shape S6 relies on.
        let report = check(["pregnancy"], answers: ["pregnancy": .yes])
        #expect(report.hasWarnings)
        #expect(ContraindicationReport.none.matches.isEmpty && ContraindicationReport.none.hasHealthForm)
    }

    @Test("The service editor can offer every token the catalog can decide")
    func choices() {
        let tokens = ContraindicationMatcher.choices(in: catalog).map(\.token)
        #expect(tokens == ["allergies.fragrance", "allergies.latex", "allergies.retinol", "medication", "pregnancy",
                           "sunExposure", "scalp"])
        // A token the editor offers is one the matcher can decide, so it is never reported as unchecked.
        let report = ContraindicationMatcher.check(contraindications: tokens, form: nil, catalog: catalog)
        #expect(report.unchecked.isEmpty)
    }
}
