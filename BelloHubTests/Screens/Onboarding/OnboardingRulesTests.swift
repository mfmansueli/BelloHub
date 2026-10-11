//
//  OnboardingRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("OnboardingRules")
struct OnboardingRulesTests {
    @Test("Whitespace is collapsed and trimmed", arguments: [
        ("  Glow   Facial ", "Glow Facial"), ("Ana\tCosta\n", "Ana Costa"), ("", ""), ("   ", "")
    ])
    func cleaned(raw: String, expected: String) {
        #expect(OnboardingRules.cleaned(raw) == expected)
    }

    @Test("A person's name needs at least two characters once cleaned", arguments: [
        ("Ma", true), ("M", false), (" M ", false), ("Maria Silva", true), ("", false),
        (String(repeating: "a", count: 61), false), (String(repeating: "a", count: 60), true), ("张伟", true)
    ])
    func personName(text: String, valid: Bool) {
        #expect(OnboardingRules.isValidPersonName(text) == valid)
    }

    @Test("Continue is enabled by the step's own rule")
    func canContinue() {
        var draft = makeDraft(professions: [], name: "")
        #expect(!OnboardingRules.canContinue(from: .about, draft: draft))
        draft.displayName = "Maria"
        #expect(OnboardingRules.canContinue(from: .about, draft: draft))
        #expect(!OnboardingRules.canContinue(from: .profession, draft: draft))
        draft.professions = [.hair]
        #expect(OnboardingRules.canContinue(from: .profession, draft: draft))
        for step in [OnboardingStep.services, .ready] {
            #expect(OnboardingRules.canContinue(from: step, draft: makeDraft(professions: [], name: "")))
        }
    }

    @Test("A name is accepted once, ignoring case and accents")
    func acceptedName() {
        #expect(OnboardingRules.acceptedName("  Protocolo   360 ", existing: []) == "Protocolo 360")
        #expect(OnboardingRules.acceptedName("protocolo 360", existing: ["Protocolo 360"]) == nil)
        #expect(OnboardingRules.acceptedName("Hidratação", existing: ["hidratacao"]) == nil)
        #expect(OnboardingRules.acceptedName("   ", existing: []) == nil)
        #expect(OnboardingRules.acceptedName(String(repeating: "x", count: 61), existing: []) == nil)
    }

    @Test("A custom service needs a name and cannot have a negative price")
    func serviceIssues() {
        #expect(OnboardingRules.issues(in: DraftService(name: "Brazilian Glow")).isEmpty)
        #expect(OnboardingRules.issues(in: DraftService(name: "  ")) == [.nameMissing])
        #expect(OnboardingRules.issues(in: DraftService(name: "X", priceAmount: -1)) == [.priceNegative])
        #expect(OnboardingRules.issues(in: DraftService(name: "", priceAmount: -1)) == [.nameMissing, .priceNegative])
        #expect(OnboardingRules.issues(in: DraftService(name: "Free", priceAmount: 0)).isEmpty)
    }

    @Test("The service sheet offers the durations and follow-ups the prototype shows")
    func options() {
        #expect(OnboardingRules.durationOptions.contains(60) && OnboardingRules.durationOptions.contains(90))
        #expect(OnboardingRules.durationOptions == OnboardingRules.durationOptions.sorted())
        #expect(OnboardingRules.followUpWeekOptions == [2, 3, 4, 6, 8])
    }
}

@Suite("PriceInput")
struct PriceInputTests {
    @Test("A price is read the way the language writes numbers", arguments: [
        ("120", "en_US", Decimal(120)), ("120.50", "en_US", Decimal(120.5)),
        ("120,50", "pt_BR", Decimal(120.5)), ("٢٥٠", "ar", Decimal(250)), ("0", "en_US", Decimal(0))
    ])
    func values(text: String, locale: String, expected: Decimal) {
        #expect(PriceInput(text, locale: Locale(identifier: locale)).amount == expected)
    }

    @Test("Empty is optional, and nonsense or a negative is invalid")
    func emptyAndInvalid() {
        let locale = Locale(identifier: "en_US")
        #expect(PriceInput("", locale: locale) == .empty)
        #expect(PriceInput("  ", locale: locale) == .empty)
        #expect(PriceInput("abc", locale: locale).isInvalid)
        #expect(PriceInput("-5", locale: locale).isInvalid)
        #expect(PriceInput("abc", locale: locale).amount == nil)
    }
}

@Suite("OnboardingStep")
struct OnboardingStepTests {
    @Test("Three steps show the progress bar, in order, and Ready does not")
    func progress() {
        #expect(OnboardingStep.counted == [.about, .profession, .services])
        #expect(OnboardingStep.about.progressPosition == 1)
        #expect(OnboardingStep.services.progressPosition == 3)
        #expect(OnboardingStep.ready.progressPosition == nil)
    }

    @Test("Steps link forward and back, and stop at the ends")
    func neighbors() {
        #expect(OnboardingStep.about.previous == nil)
        #expect(OnboardingStep.about.next == .profession)
        #expect(OnboardingStep.ready.next == nil)
        #expect(OnboardingStep.ready.previous == .services)
    }

    @Test("Names are unique, for accessibility identifiers")
    func names() {
        #expect(Set(OnboardingStep.allCases.map(\.name)).count == OnboardingStep.allCases.count)
        for step in OnboardingStep.allCases { #expect(OnboardingStep(name: step.name) == step) }
        #expect(OnboardingStep(name: "permissions") == nil)
    }
}
