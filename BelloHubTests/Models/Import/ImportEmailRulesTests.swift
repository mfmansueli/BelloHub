//
//  ImportEmailRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("ImportEmailRules")
struct ImportEmailRulesTests {
    @Test("Addresses are accepted and lower-cased", arguments: [
        ("ana@example.com", "ana@example.com"), ("Ana.Costa@Example.COM", "ana.costa@example.com"),
        ("  ana+tag@mail.example.co.uk  ", "ana+tag@mail.example.co.uk"), ("mailto:ana@example.com", "ana@example.com"),
        ("ana@example.com; bia@example.com", "ana@example.com"), ("josé@example.com", "josé@example.com")
    ])
    func valid(raw: String, expected: String) {
        #expect(ImportEmailRules.check(raw) == .valid(expected))
    }

    @Test("Things that are not addresses are invalid",
          arguments: ["ana", "ana@", "@example.com", "ana@example", "ana@.com", "ana@example.", "ana@@example.com",
                      "ana@exa..mple.com", "ana example@x.com@y"])
    func invalid(raw: String) {
        #expect(ImportEmailRules.check(raw) == .invalid)
    }

    @Test("Nothing, and the words spreadsheets use for nothing, is no e-mail",
          arguments: [nil, "", "   ", "-", "--", "—", "n/a", "NA", "none", "null", "Sem e-mail", "sin correo", "yok"])
    func none(raw: String?) {
        #expect(ImportEmailRules.check(raw) == .none)
    }
}
