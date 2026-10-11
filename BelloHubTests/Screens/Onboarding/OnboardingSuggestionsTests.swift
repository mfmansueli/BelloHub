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

    @Test("The first service is the first preselected service of her first profession")
    func firstService() {
        #expect(OnboardingSuggestions.firstService(for: [.esthetician], in: catalog)?.key == "est.glow")
        #expect(OnboardingSuggestions.firstService(for: [.hair, .esthetician], in: catalog)?.key == "hair.cut")
        #expect(OnboardingSuggestions.firstService(for: [], in: catalog) == nil)
    }

    @Test("With nothing chosen yet, choosing a profession picks only its first service")
    func firstProfession() {
        let result = OnboardingSuggestions.reconciledServices(
            selected: [], firstKey: nil, current: [.esthetician], in: catalog
        )
        #expect(result.selected == ["est.glow"] && result.firstKey == "est.glow")
    }

    @Test("Adding a profession keeps her picks and her first service and switches nothing else on")
    func addProfession() {
        let result = OnboardingSuggestions.reconciledServices(
            selected: ["est.glow", "est.peel"], firstKey: "est.glow", current: [.esthetician, .hair], in: catalog
        )
        #expect(result.selected == ["est.glow", "est.peel"] && result.firstKey == "est.glow")
    }

    @Test("Removing her first profession moves the first service on and takes its picks with it")
    func removeProfession() {
        let result = OnboardingSuggestions.reconciledServices(
            selected: ["est.glow", "hair.cut", "shared.consult"], firstKey: "est.glow", current: [.hair], in: catalog
        )
        #expect(result.selected == ["hair.cut", "shared.consult"] && result.firstKey == "hair.cut")
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
