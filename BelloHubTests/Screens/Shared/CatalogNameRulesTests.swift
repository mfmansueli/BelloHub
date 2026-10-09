//
//  CatalogNameRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("CatalogNameRules")
struct CatalogNameRulesTests {
    @Test("A name is cleaned of stray spaces and accepted")
    func accepted() {
        #expect(CatalogNameRules.check("  Glow   Facial ", among: []) == .accepted("Glow Facial"))
    }

    @Test("Nothing but spaces is empty")
    func empty() {
        #expect(CatalogNameRules.check("", among: []) == .empty)
        #expect(CatalogNameRules.check("  \n ", among: []) == .empty)
    }

    @Test("Sixty characters fit and sixty-one are too long")
    func length() {
        #expect(CatalogNameRules.check(String(repeating: "a", count: 60), among: []).acceptedName != nil)
        #expect(CatalogNameRules.check(String(repeating: "a", count: 61), among: []) == .tooLong)
    }

    @Test("A name is taken ignoring case and accents", arguments: ["protocolo 360", "PROTOCOLO 360", "Protocólo 360"])
    func duplicate(candidate: String) {
        #expect(CatalogNameRules.check(candidate, among: ["Protocolo 360", "Glow"]) == .duplicate)
    }

    @Test("A different name is fine and the check names no winner")
    func different() {
        #expect(CatalogNameRules.check("Glow Facial", among: ["Glow"]) == .accepted("Glow Facial"))
    }

    @Test("A smaller limit can be asked for")
    func customLimit() {
        #expect(CatalogNameRules.check("abcdef", among: [], maximumLength: 5) == .tooLong)
    }
}
