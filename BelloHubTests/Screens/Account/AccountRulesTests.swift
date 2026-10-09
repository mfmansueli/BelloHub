//
//  AccountRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("AccountRules")
struct AccountRulesTests {
    private func makeProfile(name: String = "Maria Silva", business: String = "") -> ProfessionalProfile {
        ProfessionalProfile(
            displayName: name, businessName: business, regionCode: "BR", timeZoneID: "America/Sao_Paulo",
            currencyCode: "BRL", appLocaleID: "pt-BR", createdAt: TestClock.now
        )
    }

    @Test("The name is trimmed, must not be empty and has a limit; the business name is optional")
    func names() {
        #expect(AccountRules.cleaned("  Maria  ") == "Maria")
        #expect(AccountRules.nameIssue("   ") == .empty)
        #expect(AccountRules.nameIssue(String(repeating: "a", count: 61)) == .tooLong)
        #expect(AccountRules.nameIssue(String(repeating: "a", count: 60)) == nil)
        #expect(AccountRules.businessNameIssue("") == nil)
        #expect(AccountRules.businessNameIssue(String(repeating: "b", count: 61)) == .tooLong)
    }

    @Test("Changes are measured against the stored profile after cleaning")
    func changes() {
        let profile = makeProfile(name: "Maria Silva", business: "Glow")
        #expect(!AccountRules.hasChanges(displayName: " Maria Silva ", businessName: "Glow", profile: profile))
        #expect(AccountRules.hasChanges(displayName: "Maria S.", businessName: "Glow", profile: profile))
        #expect(AccountRules.hasChanges(displayName: "Maria Silva", businessName: "", profile: profile))
        #expect(!AccountRules.hasChanges(displayName: "Maria", businessName: "", profile: nil), "nothing to compare")
    }
}
