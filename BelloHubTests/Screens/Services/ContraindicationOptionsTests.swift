//
//  ContraindicationOptionsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ContraindicationOptions")
struct ContraindicationOptionsTests {
    private func groups(in catalog: HealthFormCatalog = makeHealthCatalog()) -> [ContraindicationGroup] {
        ContraindicationOptions.groups(in: catalog, minorGroupTitle: "About the client", minorTitle: "Under 18")
    }

    @Test("The first group is about the client, with the under-18 option the matcher understands")
    func minorGroup() throws {
        let first = try #require(groups().first)
        #expect(first.id == ContraindicationOptions.aboutTheClientGroupID && first.title == "About the client")
        #expect(first.options.map(\.token) == [ContraindicationMatcher.minorToken])
    }

    @Test("Each answerable question is a group, in the order the form asks, with the free-text question left out")
    func groupsFollowTheCatalog() {
        let found = groups()
        #expect(found.map(\.id) == ["client", "allergies", "medication", "pregnancy", "sunExposure", "scalp"])
        #expect(!found.map(\.id).contains("notes"), "a text question cannot be decided from an answer")
    }

    @Test("A choice question lists one option per choice, with the wording of the question and the choice")
    func choicesOfAQuestion() throws {
        let allergies = try #require(groups().first { $0.id == "allergies" })
        #expect(allergies.title == "Allergies")
        #expect(allergies.options.map(\.token) == ["allergies.fragrance", "allergies.latex", "allergies.retinol"])
        #expect(allergies.options.map(\.title) == ["Fragrance", "Latex", "Retinol"])
        #expect(allergies.options.first?.summary == "Allergies · Fragrance")
    }

    @Test("A yes-or-no question is one option named after the question")
    func yesNoQuestion() throws {
        let pregnancy = try #require(groups().first { $0.id == "pregnancy" })
        #expect(pregnancy.options.map(\.token) == ["pregnancy"])
        #expect(pregnancy.options.first?.title == "Pregnant or breastfeeding")
        #expect(pregnancy.options.first?.summary == "Pregnant or breastfeeding")
    }

    @Test("Every token the picker offers is one the matcher can decide, so a warning can really happen")
    func everyTokenIsDecidable() {
        let catalog = makeHealthCatalog()
        let tokens = groups(in: catalog).flatMap(\.options).map(\.token)
        let report = ContraindicationMatcher.check(contraindications: tokens, form: nil, catalog: catalog)
        #expect(report.unchecked.isEmpty, "unchecked: \(report.unchecked)")
    }

    @Test("It also holds for the shipped catalog in every language")
    func shippedCatalogs() throws {
        for localization in AppLocalization.allCases {
            let catalog = try BundleHealthFormCatalogProvider().catalog(for: localization)
            let tokens = ContraindicationOptions.groups(in: catalog, minorGroupTitle: "-", minorTitle: "-")
                .flatMap(\.options).map(\.token)
            #expect(tokens.count > 10, "\(localization) offers \(tokens.count) options")
            let report = ContraindicationMatcher.check(contraindications: tokens, form: nil, catalog: catalog)
            #expect(report.unchecked.isEmpty, "\(localization): \(report.unchecked)")
        }
    }

    @Test("A chosen token reads as its summary, and one the catalog does not know reads as itself")
    func summaries() {
        let found = groups()
        #expect(ContraindicationOptions.summary(for: "allergies.latex", in: found) == "Allergies · Latex")
        #expect(ContraindicationOptions.summary(for: "minor", in: found) == "Under 18")
        #expect(ContraindicationOptions.summary(for: "futureQuestion.thing", in: found) == "futureQuestion.thing")
    }

    @Test("Chosen tokens come in picker order, with unknown ones after, and none is dropped")
    func ordering() {
        let found = groups()
        let chosen = ["pregnancy", "futureQuestion.thing", "minor", "allergies.latex"]
        #expect(ContraindicationOptions.ordered(chosen, in: found)
            == ["minor", "allergies.latex", "pregnancy", "futureQuestion.thing"])
    }

    @Test("Toggling adds a token at the end and removes it when it is there")
    func toggling() {
        #expect(ContraindicationOptions.toggling("minor", in: ["pregnancy"]) == ["pregnancy", "minor"])
        #expect(ContraindicationOptions.toggling("minor", in: ["pregnancy", "minor"]) == ["pregnancy"])
        #expect(ContraindicationOptions.toggling("minor", in: []) == ["minor"])
    }
}
