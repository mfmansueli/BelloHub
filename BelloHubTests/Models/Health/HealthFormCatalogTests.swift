//
//  HealthFormCatalogTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("HealthFormCatalog")
struct HealthFormCatalogTests {
    @Test("A catalog decodes with its questions in file order and their choices")
    func decodes() throws {
        let catalog = makeHealthCatalog()
        #expect(catalog.localization == "en" && catalog.status == "needs_review")
        #expect(catalog.questions.map(\.key)
                == ["allergies", "medication", "pregnancy", "sunExposure", "scalp", "notes"])
        let allergies = try #require(catalog.question(for: "allergies"))
        #expect(allergies.kind == .choices && allergies.allowsNone)
        #expect(allergies.options.map(\.key) == ["fragrance", "latex", "retinol"])
        #expect(allergies.optionName(for: "latex") == "Latex" && allergies.optionName(for: "x") == nil)
        #expect(catalog.question(for: "sunExposure")?.isOnByDefault == false)
        #expect(catalog.question(for: "pregnancy")?.professions == [.esthetician, .lash])
    }

    @Test("A question of a kind this version does not know is dropped, and an unknown profession ignored")
    func unknownKindAndProfession() throws {
        let json = """
        {"localization": "en", "questions": [
          {"key": "a", "kind": "hologram", "name": "A", "prompt": "A?"},
          {"key": "b", "kind": "yesNo", "name": "B", "prompt": "B?", "professions": ["astronaut", "hair"]}]}
        """
        let catalog = try HealthFormCatalog.decode(Data(json.utf8))
        #expect(catalog.questions.map(\.key) == ["b"])
        #expect(catalog.questions.first?.professions == [.hair])
        #expect(catalog.status == "needs_review" && catalog.questions.first?.isOnByDefault == true)
    }

    @Test("Malformed and empty files are rejected with their own error")
    func rejects() {
        #expect(throws: HealthFormCatalog.LoadError.malformed) { try HealthFormCatalog.decode(Data("nope".utf8)) }
        #expect(throws: HealthFormCatalog.LoadError.empty) {
            try HealthFormCatalog.decode(Data(#"{"localization": "en", "questions": []}"#.utf8))
        }
    }

    // MARK: - The shipped files

    private func shipped(_ localization: AppLocalization) throws -> HealthFormCatalog {
        try BundleHealthFormCatalogProvider().catalog(for: localization)
    }

    @Test("Every localization has a catalog that loads from the app bundle", arguments: AppLocalization.allCases)
    func bundled(localization: AppLocalization) throws {
        let catalog = try shipped(localization)
        #expect(catalog.localization == localization.rawValue)
        #expect(catalog.status == "needs_review")
        for question in catalog.questions {
            #expect(!question.name.isEmpty && !question.prompt.isEmpty, "\(question.key) has no text")
            if question.kind == .choices {
                #expect(!question.options.isEmpty && question.options.allSatisfy { !$0.name.isEmpty })
                #expect(!question.options.contains { $0.key == HealthOption.noneKey }, "none is implied by allowsNone")
            }
        }
    }

    @Test("A translation never changes behavior: keys, kinds, professions, defaults and choices match English",
          arguments: AppLocalization.allCases)
    func sameStructureAsEnglish(localization: AppLocalization) throws {
        let english = try shipped(.en)
        let other = try shipped(localization)
        #expect(english.questions.count == other.questions.count)
        for (left, right) in zip(english.questions, other.questions) {
            #expect(left.key == right.key && left.kind == right.kind)
            #expect(left.professions == right.professions && left.isOnByDefault == right.isOnByDefault)
            #expect(left.allowsNone == right.allowsNone)
            #expect(left.options.map(\.key) == right.options.map(\.key))
        }
    }

    @Test("Every question is offered to at least one profession, and every profession gets the safety basics")
    func coverage() throws {
        let catalog = try shipped(.en)
        for question in catalog.questions {
            #expect(ProfessionID.allCases.contains { HealthFormTemplateRules.applies(question, to: [$0]) },
                    "\(question.key) is offered to nobody")
        }
        for profession in ProfessionID.allCases {
            let keys = HealthFormTemplateRules.defaultKeys(in: catalog, for: [profession])
            #expect(keys.contains("allergies") && keys.contains("medication"), "\(profession) lacks the basics")
        }
    }

    @Test("The questions docs/05 names are there: pregnancy, skin, and isotretinoin or a peel in the last 6 months")
    func requiredQuestions() throws {
        let catalog = try shipped(.en)
        for key in ["allergies", "medication", "pregnancy", "skinConditions", "recentProcedures"] {
            #expect(catalog.question(for: key) != nil, "\(key) is missing")
        }
        let procedures = try #require(catalog.question(for: "recentProcedures"))
        #expect(procedures.optionName(for: "isotretinoin") != nil && procedures.optionName(for: "peel") != nil)
        #expect(HealthFormTemplateRules.defaultKeys(in: catalog, for: [.esthetician]).contains("recentProcedures"))
    }

    @Test("A contraindication token the editor offers is decided by the shipped catalog in every language",
          arguments: AppLocalization.allCases)
    func contraindicationTokens(localization: AppLocalization) throws {
        let catalog = try shipped(localization)
        let tokens = ContraindicationMatcher.choices(in: catalog).map(\.token)
        #expect(tokens.contains("pregnancy") && tokens.contains("recentProcedures.isotretinoin"))
        let report = ContraindicationMatcher.check(contraindications: tokens, form: nil, catalog: catalog)
        #expect(report.unchecked.isEmpty)
    }
}
