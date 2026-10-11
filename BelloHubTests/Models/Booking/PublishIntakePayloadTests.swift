//
//  PublishIntakePayloadTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The health form the page asks (`publishProfile.profile.intake`, API.md 6.2): without it `getFormContext` answers
/// NOT_FOUND and no client of hers could ever send the form from her link.
@Suite("PublishPayloads: the health form")
struct PublishIntakePayloadTests {
    private let now = TestClock.now

    private func catalog(_ localization: AppLocalization) throws -> HealthFormCatalog {
        try BundleHealthFormCatalogProvider().catalog(for: localization)
    }

    private func publication(keys: [String]? = nil, version: Int = 2) throws -> HealthFormPublication {
        let portuguese = try catalog(.ptBR)
        let defaults = HealthFormTemplateRules.defaultKeys(in: portuguese, for: [.esthetician])
        return HealthFormPublication(
            template: HealthFormTemplate(
                version: version, questionKeys: keys ?? defaults, reviewEveryMonths: 12, createdAt: now
            ),
            catalogs: [.ptBR: portuguese, .en: try catalog(.en)],
            noneLabels: [.ptBR: "Nenhuma", .en: "None"]
        )
    }

    private func intake(_ form: HealthFormPublication?) -> PublishProfileRequest.Intake? {
        var inputs = makePublishInputs()
        inputs.healthForm = form
        return PublishPayloads.profile(inputs, now: now).profile.intake
    }

    @Test("No form read from the vault publishes the page without one")
    func noForm() {
        #expect(intake(nil) == nil)
    }

    @Test("Every question she asks goes out in her order, in each booking language, as the page's kinds")
    func questions() throws {
        let form = try publication()
        let sent = try #require(intake(form))
        #expect(sent.formVersion == 2)
        #expect(sent.template.questions.map(\.key) == form.template.questionKeys)
        let english = try catalog(.en)
        for question in sent.template.questions {
            #expect(["yesNo", "multiChoice", "text"].contains(question.kind), "\(question.key)")
            #expect(Set(question.label.keys) == ["pt-BR", "en"], "\(question.key)")
            #expect(question.label["en"] == english.question(for: question.key)?.prompt)
        }
    }

    @Test("A choices question is a multiple choice with the app's option keys and None last")
    func choices() throws {
        let sent = try #require(intake(publication(keys: ["allergies", "medication"])))
        let allergies = try #require(sent.template.questions.first)
        #expect(allergies.kind == "multiChoice")
        let catalogKeys = try catalog(.en).question(for: "allergies")?.options.map(\.key) ?? []
        #expect(allergies.options?.map(\.value) == catalogKeys + [HealthOption.noneKey])
        #expect(allergies.options?.last?.label == ["pt-BR": "Nenhuma", "en": "None"])
        let medication = try #require(sent.template.questions.last)
        #expect(medication.kind == "yesNo" && medication.options == nil)
    }

    @Test("A key no catalog knows is left out, and a form with nothing known is not published")
    func unknownKeys() throws {
        let sent = try #require(intake(publication(keys: ["fromANewerBuild", "medication"])))
        #expect(sent.template.questions.map(\.key) == ["medication"])
        #expect(intake(try publication(keys: ["fromANewerBuild"])) == nil)
        #expect(intake(try publication(keys: [])) == nil)
    }

    @Test("A booking language with no catalog read is simply not among the labels")
    func missingLanguage() throws {
        var form = try publication(keys: ["medication"])
        form.catalogs[.en] = nil
        let question = try #require(intake(form)?.template.questions.first)
        #expect(Set(question.label.keys) == ["pt-BR"])
    }

    @Test("The page with its form satisfies the server's schema and carries no consent text (D55)")
    func contract() throws {
        var inputs = makePublishInputs()
        inputs.healthForm = try publication()
        let body = try CallableJSON.encoder.encode(PublishPayloads.profile(inputs, now: now))
        for problem in try ServerContract.violations(of: body, for: "publishProfile") {
            Issue.record(Comment(rawValue: problem))
        }
        let text = String(bytes: body, encoding: .utf8) ?? ""
        #expect(text.contains("\"intake\""))
        #expect(!text.lowercased().contains("consent"))
        #expect(body.count < 200 * 1024)
    }

    @Test("The intake the page builds from this template reads back into the app's answers")
    func roundTripKeys() throws {
        let sent = try #require(intake(publication(keys: ["allergies", "medication"])))
        // What the page sends for these questions (web/src/routes/form/payload.ts): string[] and boolean.
        let plaintext = Data("""
        {"schema":2,"bookingId":"bk","localeId":"en","formVersion":"\(sent.formVersion)",\
        "answers":{"allergies":["\(sent.template.questions[0].options?.first?.value ?? "")"],"medication":true},\
        "isForMinor":false,"submittedAt":"2026-10-08T14:03:21.000Z","_pad":"000"}
        """.utf8)
        let payload = try IntakePayload.decode(plaintext)
        #expect(payload.formVersion == sent.formVersion)
        #expect(payload.answers["medication"] == .yes)
        #expect(payload.answers["allergies"] == .choices([sent.template.questions[0].options?.first?.value ?? ""]))
    }
}
