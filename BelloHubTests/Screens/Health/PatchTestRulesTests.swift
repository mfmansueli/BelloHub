//
//  PatchTestRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PatchTestRules")
struct PatchTestRulesTests {
    private func draft(product: String = "Calming serum", hours: Int = 24) -> PatchTestDraft {
        var draft = PatchTestDraft(testedAt: TestClock.now)
        draft.product = product
        draft.observedHours = hours
        return draft
    }

    @Test("A patch test needs a product and a standard observation period")
    func canSave() {
        #expect(PatchTestRules.canSave(draft()))
        #expect(!PatchTestRules.canSave(draft(product: "")))
        #expect(!PatchTestRules.canSave(draft(product: "  x ")))
        #expect(!PatchTestRules.canSave(draft(hours: 36)))
        #expect(PatchTest.observationOptions == [24, 48, 72])
    }

    @Test("The entry is trimmed and empty optional text is stored as nothing")
    func build() {
        var input = draft(product: "  Glycolic acid 10% ", hours: 48)
        input.area = "   "
        input.notes = ""
        input.result = .mildReaction
        let id = UUID()
        let clientID = UUID()

        let entry = PatchTestRules.patchTest(from: input, clientID: clientID, id: id)

        #expect(entry.id == id && entry.clientID == clientID)
        #expect(entry.product == "Glycolic acid 10%" && entry.area == nil && entry.notes == nil)
        #expect(entry.observedHours == 48 && entry.result == .mildReaction && entry.testedAt == TestClock.now)
    }

    @Test("A result a newer version wrote reads as a reaction, and only no reaction needs no attention")
    func results() throws {
        let decoded = try JSONDecoder().decode(PatchTestResult.self, from: Data(#""inconclusive""#.utf8))
        #expect(decoded == .reaction)
        #expect(PatchTestResult.fallback == .reaction)
        #expect(PatchTestResult.allCases.filter(\.needsAttention) == [.mildReaction, .reaction])
    }
}
