//
//  OnboardingSuggestionsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("OnboardingSuggestions")
struct OnboardingSuggestionsTests {
    private let catalog = makeCatalog()

    @Test("Services of two professions are listed in her order, a shared key once")
    func union() {
        let keys = OnboardingSuggestions.services(for: [.esthetician, .hair], in: catalog).map(\.key)
        #expect(keys == ["est.glow", "est.peel", "shared.consult", "hair.cut"])
        let reversed = OnboardingSuggestions.services(for: [.hair, .esthetician], in: catalog).map(\.key)
        #expect(reversed == ["hair.cut", "shared.consult", "est.glow", "est.peel"])
    }

    @Test("No profession means no suggestions")
    func none() {
        #expect(OnboardingSuggestions.services(for: [], in: catalog).isEmpty)
        #expect(OnboardingSuggestions.tags(for: [], in: catalog).isEmpty)
    }

    @Test("Adding a profession brings its preselected services and keeps her picks")
    func addProfession() {
        let result = OnboardingSuggestions.reconciledServiceKeys(
            selected: ["est.peel"], previous: [.esthetician], current: [.esthetician, .hair], in: catalog
        )
        #expect(result == ["est.peel", "hair.cut", "shared.consult"])
    }

    @Test("Removing a profession takes its picks with it, but not a service another one still offers")
    func removeProfession() {
        let result = OnboardingSuggestions.reconciledServiceKeys(
            selected: ["est.glow", "hair.cut", "shared.consult"], previous: [.esthetician, .hair], current: [.hair],
            in: catalog
        )
        #expect(result == ["hair.cut", "shared.consult"])
    }

    @Test("A service she switched off stays off when another profession is added")
    func respectsDeselection() {
        let result = OnboardingSuggestions.reconciledServiceKeys(
            selected: [], previous: [.esthetician], current: [.esthetician, .other], in: catalog
        )
        #expect(result == ["other.session"])
    }

    @Test("Tags follow the same rule")
    func tags() {
        let added = OnboardingSuggestions.reconciledTagKeys(
            selected: ["est.vip"], previous: [.esthetician], current: [.esthetician, .hair], in: catalog
        )
        #expect(added == ["est.vip", "hair.blonde"])
        let removed = OnboardingSuggestions.reconciledTagKeys(
            selected: ["est.vip", "est.sensitive"], previous: [.esthetician], current: [], in: catalog
        )
        #expect(removed.isEmpty)
    }

    @Test("Plural names read as a list in the reader's language")
    func pluralNames() {
        let english = Formatters(locale: Locale(identifier: "en_US"), timeZone: .gmt, currencyCode: "USD")
        let portuguese = Formatters(locale: Locale(identifier: "pt_BR"), timeZone: .gmt, currencyCode: "BRL")
        #expect(OnboardingSuggestions.pluralNames(for: [.esthetician], in: catalog, formatter: english)
                == "estheticians")
        #expect(OnboardingSuggestions.pluralNames(for: [.esthetician, .hair], in: catalog, formatter: english)
                == "estheticians and hair stylists")
        #expect(OnboardingSuggestions.pluralNames(for: [.esthetician, .hair], in: catalog, formatter: portuguese)
                == "estheticians e hair stylists")
    }
}
