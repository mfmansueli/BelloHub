//
//  OptionNameRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("OptionNameRules")
struct OptionNameRulesTests {
    @Test("Spaces and letter case make no new option; accents do")
    func sameOption() {
        #expect(OptionNameRules.normalized("  Gel   polish \n") == "Gel polish")
        #expect(OptionNameRules.match("gel  POLISH", in: ["Gel polish"]) == "Gel polish")
        #expect(OptionNameRules.match("Peche", in: ["Pêche"]) == nil, "accents can change the meaning")
        #expect(OptionNameRules.match("   ", in: ["Gel polish"]) == nil)
    }

    @Test("Suggestions ignore accents and case, and the ones that start with the text come first")
    func suggestions() {
        let names = ["Microneedling", "Peeling químico", "Limpeza", "Peeling enzimático"]

        #expect(OptionNameRules.suggestions(for: "peel", in: names) == ["Peeling químico", "Peeling enzimático"])
        #expect(OptionNameRules.suggestions(for: "QUIMICO", in: names) == ["Peeling químico"])
        #expect(OptionNameRules.suggestions(for: "ling", in: names) == ["Microneedling", "Peeling químico",
                                                                       "Peeling enzimático"])
        #expect(OptionNameRules.suggestions(for: "", in: names, limit: 2) == ["Microneedling", "Peeling químico"])
    }

    @Test("An empty or too long name is refused")
    func validity() {
        #expect(!OptionNameRules.isValid("  "))
        #expect(OptionNameRules.isValid("Curl C"))
        #expect(!OptionNameRules.isValid(String(repeating: "a", count: OptionNameRules.maxLength + 1)))
    }
}
