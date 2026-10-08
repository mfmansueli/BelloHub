//
//  ImportNameComposerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("ImportNameComposer")
struct ImportNameComposerTests {
    @Test("A name is the given and the family name")
    func givenAndFamily() {
        #expect(ImportNameComposer.name(given: "Ana", family: "Costa") == "Ana Costa")
    }

    @Test("Only one part is still a name")
    func oneMissing() {
        #expect(ImportNameComposer.name(given: "Ana", family: "") == "Ana")
        #expect(ImportNameComposer.name(given: "", family: "Costa") == "Costa")
    }

    @Test("Without a person's name the nickname comes first, then the organization")
    func fallbacks() {
        let nickname = ImportNameComposer.name(given: "", family: "", nickname: "Aninha", organization: "Studio Bela")
        let organization = ImportNameComposer.name(given: " ", family: "", nickname: "", organization: "Studio Bela")
        let person = ImportNameComposer.name(
            given: "Ana", family: "Costa", nickname: "Aninha", organization: "Studio Bela"
        )

        #expect(nickname == "Aninha")
        #expect(organization == "Studio Bela")
        #expect(person == "Ana Costa")
    }

    @Test("A contact with nothing has an empty name, which the mapper reports as missing")
    func nothing() {
        #expect(ImportNameComposer.name(given: "", family: "") == "")
    }

    @Test("Runs of spaces and line breaks collapse")
    func whitespace() {
        #expect(ImportNameComposer.name(given: "  Ana\n", family: "  de   Souza ") == "Ana de Souza")
    }
}
